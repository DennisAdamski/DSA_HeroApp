"""Veroeffentlichungsfassung der Regel-Index-Datenbank fuer die App.

Die App nutzt nur die FTS5-Volltextsuche. Die Vektoren der semantischen Suche
(`chunks_vec`) machen knapp die Haelfte der Datei aus und bleiben deshalb
draussen; ebenso die lokalen Dateipfade der Quellen. Das Ergebnis wird
gepackt (gzip) und unter einem Namen mit Kurzpruefsumme abgelegt, dazu eine
kleine `latest.json`, die die App und die Cloud Function lesen.
"""

from __future__ import annotations

import gzip
import hashlib
import json
import shutil
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

#: Schema-Version der veroeffentlichten Datei; die App prueft nur `chunks_fts`.
PUBLISH_SCHEMA_VERSION = "1"

_SCHEMA = """
CREATE TABLE meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
CREATE TABLE sources (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    category     TEXT NOT NULL,
    path         TEXT NOT NULL UNIQUE,
    title        TEXT NOT NULL,
    mtime        REAL NOT NULL,
    sha256       TEXT NOT NULL,
    page_count   INTEGER NOT NULL,
    indexed_at   TEXT NOT NULL
);
CREATE INDEX idx_sources_category ON sources (category);
CREATE TABLE chunks (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    source_id    INTEGER NOT NULL REFERENCES sources (id) ON DELETE CASCADE,
    chunk_index  INTEGER NOT NULL,
    page_start   INTEGER NOT NULL,
    page_end     INTEGER NOT NULL,
    text         TEXT NOT NULL
);
CREATE INDEX idx_chunks_source ON chunks (source_id);
CREATE VIRTUAL TABLE chunks_fts USING fts5 (
    text,
    content = 'chunks',
    content_rowid = 'id',
    tokenize = 'unicode61 remove_diacritics 2'
);
"""


class PublishError(RuntimeError):
    """Die Quelldatenbank taugt nicht fuer eine Veroeffentlichung."""


def build_release(
    db_path: Path,
    out_dir: Path,
    *,
    published_at: datetime | None = None,
) -> dict[str, Any]:
    """Baut die Veroeffentlichungsfassung und liefert die `latest.json`-Daten.

    Schreibt `index-<sha12>.sqlite.gz` und `latest.json` nach [out_dir]. Die
    Quelldatenbank wird nur lesend geoeffnet.
    """
    if not db_path.is_file():
        raise PublishError(f"Index-Datenbank nicht gefunden: {db_path}")
    out_dir.mkdir(parents=True, exist_ok=True)
    stripped = out_dir / "index.sqlite"
    if stripped.exists():
        stripped.unlink()

    stamp = (published_at or datetime.now(timezone.utc)).astimezone(timezone.utc)
    _write_stripped(db_path, stripped, stamp)
    _verify(stripped)

    digest = hashlib.sha256(stripped.read_bytes()).hexdigest()
    packed = out_dir / f"index-{digest[:12]}.sqlite.gz"
    with stripped.open("rb") as source, packed.open("wb") as target:
        # mtime=0 und fester Dateiname: gleiche Daten ergeben gleiche Bytes.
        with gzip.GzipFile(
            filename="", mode="wb", fileobj=target, compresslevel=9, mtime=0
        ) as zipped:
            shutil.copyfileobj(source, zipped)

    release = {
        "file": packed.name,
        "sha256": digest,
        "sizeBytes": stripped.stat().st_size,
        "gzipBytes": packed.stat().st_size,
        "schemaVersion": PUBLISH_SCHEMA_VERSION,
        "version": stamp.strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    (out_dir / "latest.json").write_text(
        json.dumps(release, indent=2) + "\n", encoding="utf-8"
    )
    stripped.unlink()
    return release


def upload_commands(release: dict[str, Any], out_dir: Path, bucket: str) -> list[list[str]]:
    """Liefert die `gcloud`-Aufrufe fuer den Upload, Datei zuerst, dann Verweis.

    Die Reihenfolge ist Absicht: erst wenn die neue Datei da ist, zeigt
    `latest.json` auf sie. Die Datei traegt `Content-Encoding: gzip`, damit
    Browser und Dart sie beim Laden selbst entpacken.
    """
    target = bucket.rstrip("/")
    if not target.startswith("gs://"):
        target = f"gs://{target}"
    return [
        [
            "gcloud", "storage", "cp",
            "--content-encoding=gzip",
            "--cache-control=private, max-age=31536000",
            "--content-type=application/vnd.sqlite3",
            str(out_dir / release["file"]),
            f"{target}/rules/{release['file']}",
        ],
        [
            "gcloud", "storage", "cp",
            "--cache-control=no-store",
            "--content-type=application/json",
            str(out_dir / "latest.json"),
            f"{target}/rules/latest.json",
        ],
    ]


def _write_stripped(source_path: Path, target_path: Path, published_at: datetime) -> None:
    source = sqlite3.connect(f"file:{source_path.as_posix()}?mode=ro", uri=True)
    try:
        for table in ("meta", "sources", "chunks"):
            exists = source.execute(
                "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (table,)
            ).fetchone()
            if exists is None:
                raise PublishError(f"Tabelle `{table}` fehlt in der Index-Datenbank.")
        target = sqlite3.connect(target_path)
        try:
            target.executescript(_SCHEMA)
            for key, value in source.execute("SELECT key, value FROM meta"):
                # Das Embedding-Modell gehoert zu den Vektoren, die fehlen.
                if key != "embedding_model":
                    target.execute("INSERT INTO meta VALUES (?, ?)", (key, value))
            target.executemany(
                "INSERT INTO meta VALUES (?, ?)",
                [
                    ("published_schema", PUBLISH_SCHEMA_VERSION),
                    ("published_at", published_at.astimezone(timezone.utc).isoformat()),
                ],
            )
            # Lokale Pfade (Benutzername, Ordnerstruktur) verlassen den Rechner
            # nicht: die App liest nur Titel und Kategorie.
            for row in source.execute(
                "SELECT id, category, title, mtime, sha256, page_count, indexed_at "
                "FROM sources ORDER BY id"
            ):
                target.execute(
                    "INSERT INTO sources (id, category, path, title, mtime, sha256, "
                    "page_count, indexed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                    (row[0], row[1], f"quelle-{row[0]}", row[2], row[3], row[4], row[5], row[6]),
                )
            target.executemany(
                "INSERT INTO chunks (id, source_id, chunk_index, page_start, page_end, text) "
                "VALUES (?, ?, ?, ?, ?, ?)",
                source.execute(
                    "SELECT id, source_id, chunk_index, page_start, page_end, text "
                    "FROM chunks ORDER BY id"
                ),
            )
            target.execute("INSERT INTO chunks_fts(chunks_fts) VALUES ('rebuild')")
            target.commit()
            target.execute("VACUUM")
        finally:
            target.close()
    finally:
        source.close()


def _verify(path: Path) -> None:
    """Prueft, was die App braucht: Treffer ueber `chunks_fts` samt Quelle."""
    connection = sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True)
    try:
        chunks = connection.execute("SELECT count(*) FROM chunks").fetchone()[0]
        if chunks == 0:
            raise PublishError("Die Index-Datenbank enthaelt keine Textabschnitte.")
        row = connection.execute("SELECT text FROM chunks LIMIT 1").fetchone()
        word = next((w for w in row[0].split() if len(w) > 4 and w.isalpha()), None)
        if word is not None:
            found = connection.execute(
                "SELECT count(*) FROM chunks_fts JOIN chunks c ON c.id = chunks_fts.rowid "
                "JOIN sources s ON s.id = c.source_id WHERE chunks_fts MATCH ?",
                (f'"{word}"',),
            ).fetchone()[0]
            if found == 0:
                raise PublishError("Die Volltextsuche der Veroeffentlichung findet nichts.")
        leaked = connection.execute(
            "SELECT count(*) FROM sources WHERE path NOT LIKE 'quelle-%'"
        ).fetchone()[0]
        if leaked:
            raise PublishError("Lokale Quellpfade sind in der Veroeffentlichung geblieben.")
    finally:
        connection.close()
