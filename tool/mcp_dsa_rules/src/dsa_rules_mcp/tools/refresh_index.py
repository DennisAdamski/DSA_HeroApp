"""MCP-Tool: Indexaktualisierung ueber alle oder eine Quelle."""

from __future__ import annotations

import sqlite3

from dsa_rules_mcp.config import DEFAULT_SOURCE_DIRS, McpConfig
from dsa_rules_mcp.indexer.embedder import Embedder
from dsa_rules_mcp.indexer.pipeline import refresh_index


def run_refresh_index(
    connection: sqlite3.Connection,
    config: McpConfig,
    *,
    embedder: Embedder,
    source: str | None = None,
    force: bool = False,
) -> dict[str, object]:
    if source is not None and source not in DEFAULT_SOURCE_DIRS:
        return {"error": f"Unbekannte Kategorie: {source}"}

    stats = refresh_index(
        connection,
        config,
        embedder=embedder,
        source_filter=source,
        force=bool(force),
    )
    return {
        "source": source or "alle",
        "force": bool(force),
        "stats": stats.to_dict(),
    }
