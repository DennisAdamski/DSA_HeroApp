"""SQLite-Zugriff fuer den MCP-Index."""

from __future__ import annotations

import sqlite3
from dataclasses import dataclass
from importlib import resources
from pathlib import Path
from typing import Iterable, Iterator, Sequence


SCHEMA_VERSION_KEY = "schema_version"
SCHEMA_VERSION_VALUE = "1"
EMBEDDING_MODEL_KEY = "embedding_model"


@dataclass(frozen=True)
class SourceRow:
    id: int
    category: str
    path: str
    title: str
    mtime: float
    sha256: str
    page_count: int
    indexed_at: str


@dataclass(frozen=True)
class ChunkRow:
    id: int
    source_id: int
    chunk_index: int
    page_start: int
    page_end: int
    text: str


def _load_schema_sql() -> str:
    return resources.files("dsa_rules_mcp.store").joinpath("schema.sql").read_text(encoding="utf-8")


def open_database(db_path: Path) -> sqlite3.Connection:
    """Oeffne die SQLite-Datenbank und wende bei Bedarf das Schema an."""

    db_path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(str(db_path))
    connection.row_factory = sqlite3.Row
    connection.executescript(_load_schema_sql())
    _set_meta(connection, SCHEMA_VERSION_KEY, SCHEMA_VERSION_VALUE)
    return connection


def _set_meta(connection: sqlite3.Connection, key: str, value: str) -> None:
    connection.execute(
        "INSERT INTO meta (key, value) VALUES (?, ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        (key, value),
    )
    connection.commit()


def get_meta(connection: sqlite3.Connection, key: str) -> str | None:
    row = connection.execute("SELECT value FROM meta WHERE key = ?", (key,)).fetchone()
    return row["value"] if row else None


def set_embedding_model(connection: sqlite3.Connection, model_name: str) -> None:
    _set_meta(connection, EMBEDDING_MODEL_KEY, model_name)


def get_source_by_path(connection: sqlite3.Connection, path: str) -> SourceRow | None:
    row = connection.execute(
        "SELECT id, category, path, title, mtime, sha256, page_count, indexed_at "
        "FROM sources WHERE path = ?",
        (path,),
    ).fetchone()
    if row is None:
        return None
    return SourceRow(**dict(row))


def list_sources(
    connection: sqlite3.Connection,
    categories: Sequence[str] | None = None,
) -> list[SourceRow]:
    if categories:
        placeholders = ",".join("?" * len(categories))
        query = (
            "SELECT id, category, path, title, mtime, sha256, page_count, indexed_at "
            f"FROM sources WHERE category IN ({placeholders}) ORDER BY category, title"
        )
        rows = connection.execute(query, tuple(categories)).fetchall()
    else:
        rows = connection.execute(
            "SELECT id, category, path, title, mtime, sha256, page_count, indexed_at "
            "FROM sources ORDER BY category, title"
        ).fetchall()
    return [SourceRow(**dict(row)) for row in rows]


def insert_source(
    connection: sqlite3.Connection,
    *,
    category: str,
    path: str,
    title: str,
    mtime: float,
    sha256: str,
    page_count: int,
    indexed_at: str,
) -> int:
    cursor = connection.execute(
        "INSERT INTO sources (category, path, title, mtime, sha256, page_count, indexed_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?)",
        (category, path, title, mtime, sha256, page_count, indexed_at),
    )
    return int(cursor.lastrowid)


def delete_source(connection: sqlite3.Connection, source_id: int) -> None:
    connection.execute("DELETE FROM sources WHERE id = ?", (source_id,))


def delete_source_by_path(connection: sqlite3.Connection, path: str) -> None:
    connection.execute("DELETE FROM sources WHERE path = ?", (path,))


def insert_chunk(
    connection: sqlite3.Connection,
    *,
    source_id: int,
    chunk_index: int,
    page_start: int,
    page_end: int,
    text: str,
) -> int:
    cursor = connection.execute(
        "INSERT INTO chunks (source_id, chunk_index, page_start, page_end, text) "
        "VALUES (?, ?, ?, ?, ?)",
        (source_id, chunk_index, page_start, page_end, text),
    )
    return int(cursor.lastrowid)


def store_embedding(
    connection: sqlite3.Connection,
    *,
    chunk_id: int,
    dim: int,
    embedding_bytes: bytes,
) -> None:
    connection.execute(
        "INSERT INTO chunks_vec (chunk_id, dim, embedding) VALUES (?, ?, ?) "
        "ON CONFLICT(chunk_id) DO UPDATE SET dim = excluded.dim, embedding = excluded.embedding",
        (chunk_id, dim, embedding_bytes),
    )


def fetch_chunk(connection: sqlite3.Connection, chunk_id: int) -> ChunkRow | None:
    row = connection.execute(
        "SELECT id, source_id, chunk_index, page_start, page_end, text "
        "FROM chunks WHERE id = ?",
        (chunk_id,),
    ).fetchone()
    if row is None:
        return None
    return ChunkRow(**dict(row))


def fetch_chunks_by_ids(
    connection: sqlite3.Connection,
    chunk_ids: Sequence[int],
) -> list[ChunkRow]:
    if not chunk_ids:
        return []
    placeholders = ",".join("?" * len(chunk_ids))
    rows = connection.execute(
        f"SELECT id, source_id, chunk_index, page_start, page_end, text "
        f"FROM chunks WHERE id IN ({placeholders})",
        tuple(chunk_ids),
    ).fetchall()
    return [ChunkRow(**dict(row)) for row in rows]


def fetch_neighbor_chunks(
    connection: sqlite3.Connection,
    *,
    source_id: int,
    chunk_index: int,
    window: int,
) -> list[ChunkRow]:
    rows = connection.execute(
        "SELECT id, source_id, chunk_index, page_start, page_end, text "
        "FROM chunks WHERE source_id = ? AND chunk_index BETWEEN ? AND ? "
        "ORDER BY chunk_index",
        (source_id, chunk_index - window, chunk_index + window),
    ).fetchall()
    return [ChunkRow(**dict(row)) for row in rows]


def iter_embeddings(
    connection: sqlite3.Connection,
    source_ids: Sequence[int] | None = None,
) -> Iterator[tuple[int, int, int, bytes]]:
    """Liefert (chunk_id, source_id, dim, embedding_bytes) fuer eine Quellen-Auswahl."""

    if source_ids is None:
        query = (
            "SELECT c.id, c.source_id, v.dim, v.embedding "
            "FROM chunks c JOIN chunks_vec v ON v.chunk_id = c.id"
        )
        cursor = connection.execute(query)
    else:
        if not source_ids:
            return
        placeholders = ",".join("?" * len(source_ids))
        query = (
            "SELECT c.id, c.source_id, v.dim, v.embedding "
            "FROM chunks c JOIN chunks_vec v ON v.chunk_id = c.id "
            f"WHERE c.source_id IN ({placeholders})"
        )
        cursor = connection.execute(query, tuple(source_ids))
    for row in cursor:
        yield int(row[0]), int(row[1]), int(row[2]), bytes(row[3])


def source_ids_for_categories(
    connection: sqlite3.Connection,
    categories: Sequence[str],
) -> list[int]:
    if not categories:
        return []
    placeholders = ",".join("?" * len(categories))
    rows = connection.execute(
        f"SELECT id FROM sources WHERE category IN ({placeholders})",
        tuple(categories),
    ).fetchall()
    return [int(row["id"]) for row in rows]


def all_source_paths_by_category(
    connection: sqlite3.Connection,
    category: str,
) -> list[str]:
    rows = connection.execute(
        "SELECT path FROM sources WHERE category = ?",
        (category,),
    ).fetchall()
    return [row["path"] for row in rows]


def chunk_count(connection: sqlite3.Connection) -> int:
    row = connection.execute("SELECT COUNT(*) AS n FROM chunks").fetchone()
    return int(row["n"])


def source_count(connection: sqlite3.Connection) -> int:
    row = connection.execute("SELECT COUNT(*) AS n FROM sources").fetchone()
    return int(row["n"])
