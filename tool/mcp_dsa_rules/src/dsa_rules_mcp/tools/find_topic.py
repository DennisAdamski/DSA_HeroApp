"""MCP-Tool: Thematisch gebuendelte Treffer fuer Anforderungs-Brainstorming."""

from __future__ import annotations

import sqlite3
from collections import defaultdict
from typing import Sequence

from dsa_rules_mcp.config import DEFAULT_SEARCH_SOURCES
from dsa_rules_mcp.indexer.embedder import Embedder
from dsa_rules_mcp.tools.search_rules import run_search_rules


def run_find_topic(
    connection: sqlite3.Connection,
    *,
    embedder: Embedder | None,
    topic: str,
    sources: Sequence[str] | None = None,
    limit: int = 15,
) -> dict[str, object]:
    limit = max(1, min(int(limit), 50))
    search_result = run_search_rules(
        connection,
        embedder=embedder,
        query=topic,
        sources=sources or DEFAULT_SEARCH_SOURCES,
        limit=limit,
    )
    hits = search_result.get("hits", [])
    grouped: dict[str, list[dict[str, object]]] = defaultdict(list)
    for hit in hits:
        grouped[hit.get("category", "unbekannt")].append(hit)

    return {
        "topic": topic,
        "sources": search_result.get("sources", list(DEFAULT_SEARCH_SOURCES)),
        "limit": limit,
        "grouped_hits": {category: entries for category, entries in grouped.items()},
        "total_hits": len(hits),
    }
