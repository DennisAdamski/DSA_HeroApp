"""MCP-Tool: vollen Kontext eines Treffers plus Nachbarchunks zurueckgeben."""

from __future__ import annotations

import sqlite3

from dsa_rules_mcp.store.db import fetch_chunk, fetch_neighbor_chunks


def run_get_context(
    connection: sqlite3.Connection,
    *,
    chunk_id: int,
    window: int = 1,
) -> dict[str, object]:
    window = max(0, min(int(window), 5))
    chunk = fetch_chunk(connection, int(chunk_id))
    if chunk is None:
        return {"error": f"chunk_id {chunk_id} nicht gefunden"}

    neighbors = fetch_neighbor_chunks(
        connection,
        source_id=chunk.source_id,
        chunk_index=chunk.chunk_index,
        window=window,
    )

    source_row = connection.execute(
        "SELECT id, category, path, title FROM sources WHERE id = ?",
        (chunk.source_id,),
    ).fetchone()
    if source_row is None:
        return {"error": f"source {chunk.source_id} nicht gefunden"}

    return {
        "chunk_id": chunk.id,
        "source": {
            "id": int(source_row["id"]),
            "category": source_row["category"],
            "title": source_row["title"],
            "path": source_row["path"],
        },
        "page_start": chunk.page_start,
        "page_end": chunk.page_end,
        "chunk_index": chunk.chunk_index,
        "window": window,
        "context": [
            {
                "chunk_id": neighbor.id,
                "chunk_index": neighbor.chunk_index,
                "page_start": neighbor.page_start,
                "page_end": neighbor.page_end,
                "text": neighbor.text,
                "is_primary": neighbor.id == chunk.id,
            }
            for neighbor in neighbors
        ],
    }
