from __future__ import annotations

import gzip
import hashlib
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

import pytest

from dsa_rules_mcp.publish import (
    PublishError,
    build_release,
    upload_commands,
)
from dsa_rules_mcp.store.db import open_database

STAMP = datetime(2026, 10, 23, 12, 0, tzinfo=timezone.utc)


def _source_db(path: Path) -> Path:
    connection = open_database(path)
    try:
        connection.execute(
            "INSERT INTO meta VALUES ('embedding_model', 'irgendein-modell')"
        )
        connection.execute(
            "INSERT INTO sources (id, category, path, title, mtime, sha256, page_count, "
            "indexed_at) VALUES (1, 'regelbuecher', "
            "'C:\\\\Users\\\\jemand\\\\Regelbuecher\\\\WdS.pdf', 'Wege des Schwertes', "
            "1.0, 'abc', 300, '2026-01-01')"
        )
        for index, text in enumerate(
            [
                "Das Ausweichen verlangt eine Probe auf die Parade.",
                "Wunden verringern die Initiative des Kaempfers deutlich.",
            ]
        ):
            connection.execute(
                "INSERT INTO chunks (source_id, chunk_index, page_start, page_end, text) "
                "VALUES (1, ?, ?, ?, ?)",
                (index, 10 + index, 10 + index, text),
            )
        connection.execute(
            "INSERT INTO chunks_vec (chunk_id, dim, embedding) VALUES (1, 4, ?)",
            (b"\x00" * 16,),
        )
        connection.commit()
    finally:
        connection.close()
    return path


def _tables(path: Path) -> set[str]:
    connection = sqlite3.connect(path)
    try:
        return {
            row[0]
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            )
        }
    finally:
        connection.close()


def _unpack(out_dir: Path, release: dict, target: Path) -> Path:
    target.write_bytes(gzip.decompress((out_dir / release["file"]).read_bytes()))
    return target


def test_veroeffentlichung_ohne_vektoren_und_ohne_lokale_pfade(tmp_path: Path) -> None:
    quelle = _source_db(tmp_path / "index.sqlite")
    out_dir = tmp_path / "publish"

    release = build_release(quelle, out_dir, published_at=STAMP)
    entpackt = _unpack(out_dir, release, tmp_path / "entpackt.sqlite")

    assert "chunks_vec" not in _tables(entpackt)
    connection = sqlite3.connect(entpackt)
    try:
        pfade = [row[0] for row in connection.execute("SELECT path FROM sources")]
        meta = dict(connection.execute("SELECT key, value FROM meta"))
        titel = connection.execute("SELECT title FROM sources").fetchone()[0]
    finally:
        connection.close()
    assert pfade == ["quelle-1"]
    assert "jemand" not in "".join(pfade)
    assert "embedding_model" not in meta
    assert meta["published_schema"] == "1"
    assert titel == "Wege des Schwertes"


def test_die_app_sql_findet_treffer(tmp_path: Path) -> None:
    quelle = _source_db(tmp_path / "index.sqlite")
    out_dir = tmp_path / "publish"
    release = build_release(quelle, out_dir, published_at=STAMP)
    entpackt = _unpack(out_dir, release, tmp_path / "entpackt.sqlite")

    connection = sqlite3.connect(entpackt)
    try:
        # dieselbe Abfrage wie `rules_index_search_io.dart`
        treffer = connection.execute(
            "SELECT s.title, c.page_start, "
            "snippet(chunks_fts, 0, '»', '«', ' … ', 18) "
            "FROM chunks_fts JOIN chunks c ON c.id = chunks_fts.rowid "
            "JOIN sources s ON s.id = c.source_id "
            "WHERE chunks_fts MATCH ? AND s.category IN ('regelbuecher') "
            "ORDER BY bm25(chunks_fts)",
            ('"Ausweichen" *',),
        ).fetchall()
        ohne_umlaut = connection.execute(
            "SELECT count(*) FROM chunks_fts WHERE chunks_fts MATCH 'kaempfers'"
        ).fetchone()[0]
    finally:
        connection.close()
    assert len(treffer) == 1
    assert treffer[0][0] == "Wege des Schwertes"
    assert treffer[0][1] == 10
    assert "»Ausweichen«" in treffer[0][2]
    assert ohne_umlaut == 1


def test_latest_json_beschreibt_die_entpackte_datei(tmp_path: Path) -> None:
    quelle = _source_db(tmp_path / "index.sqlite")
    out_dir = tmp_path / "publish"
    release = build_release(quelle, out_dir, published_at=STAMP)
    entpackt = _unpack(out_dir, release, tmp_path / "entpackt.sqlite")

    gelesen = json.loads((out_dir / "latest.json").read_text(encoding="utf-8"))
    assert gelesen == release
    assert release["sha256"] == hashlib.sha256(entpackt.read_bytes()).hexdigest()
    assert release["sizeBytes"] == entpackt.stat().st_size
    assert release["gzipBytes"] == (out_dir / release["file"]).stat().st_size
    assert release["file"] == f"index-{release['sha256'][:12]}.sqlite.gz"
    assert release["version"] == "2026-10-23T12:00:00Z"
    assert release["schemaVersion"] == "1"
    # Die Cloud Function akzeptiert nur diese Namensform.
    assert len(release["sha256"]) == 64
    # Die ungepackte Zwischendatei bleibt nicht liegen.
    assert not (out_dir / "index.sqlite").exists()


def test_die_quelle_bleibt_unveraendert(tmp_path: Path) -> None:
    quelle = _source_db(tmp_path / "index.sqlite")
    vorher = quelle.read_bytes()
    build_release(quelle, tmp_path / "publish", published_at=STAMP)
    assert quelle.read_bytes() == vorher
    assert "chunks_vec" in _tables(quelle)


def test_fehlende_oder_leere_datenbank_wird_abgelehnt(tmp_path: Path) -> None:
    with pytest.raises(PublishError, match="nicht gefunden"):
        build_release(tmp_path / "gibtsnicht.sqlite", tmp_path / "publish")

    leer = tmp_path / "leer.sqlite"
    open_database(leer).close()
    with pytest.raises(PublishError, match="keine Textabschnitte"):
        build_release(leer, tmp_path / "publish")


def test_upload_befehle_laden_die_datei_vor_dem_verweis(tmp_path: Path) -> None:
    release = {"file": "index-0123456789ab.sqlite.gz"}
    befehle = upload_commands(release, tmp_path, "mein-bucket")

    assert len(befehle) == 2
    datei, verweis = befehle
    assert befehle[0][-1] == "gs://mein-bucket/rules/index-0123456789ab.sqlite.gz"
    assert "--content-encoding=gzip" in datei
    assert verweis[-1] == "gs://mein-bucket/rules/latest.json"
    assert "--cache-control=no-store" in verweis
    # Auch mit gs://-Praefix und Schraegstrich am Ende derselbe Zielpfad.
    assert upload_commands(release, tmp_path, "gs://mein-bucket/")[1][-1] == (
        "gs://mein-bucket/rules/latest.json"
    )
