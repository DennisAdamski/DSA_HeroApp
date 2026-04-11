"""MCP-Tool: Listet alle indexierten PDFs je Kategorie."""

from __future__ import annotations

import sqlite3

from dsa_rules_mcp.config import DEFAULT_SOURCE_DIRS, McpConfig
from dsa_rules_mcp.store.db import chunk_count, list_sources


def run_list_sources(
    connection: sqlite3.Connection,
    config: McpConfig,
    *,
    category: str | None = None,
) -> dict[str, object]:
    if category is not None and category not in DEFAULT_SOURCE_DIRS:
        return {"error": f"Unbekannte Kategorie: {category}"}

    categories = [category] if category else None
    source_rows = list_sources(connection, categories)

    grouped: dict[str, list[dict[str, object]]] = {
        source.id: [] for source in config.sources if category is None or source.id == category
    }
    for source in source_rows:
        grouped.setdefault(source.category, []).append(
            {
                "id": source.id,
                "title": source.title,
                "path": source.path,
                "page_count": source.page_count,
                "indexed_at": source.indexed_at,
                "sha256": source.sha256,
            }
        )

    return {
        "categories": [
            {
                "id": source.id,
                "title": source.title,
                "path": str(source.path),
                "priority": source.priority,
                "exists": source.exists,
                "entries": grouped.get(source.id, []),
            }
            for source in config.sources
            if category is None or source.id == category
        ],
        "totals": {
            "sources": len(source_rows),
            "chunks": chunk_count(connection),
        },
    }
