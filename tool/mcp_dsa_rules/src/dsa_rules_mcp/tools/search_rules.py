"""MCP-Tool: Hybrid-Suche ueber ausgewaehlte Quellen."""

from __future__ import annotations

import sqlite3
from typing import Sequence

from dsa_rules_mcp.config import DEFAULT_SEARCH_SOURCES, DEFAULT_SOURCE_DIRS
from dsa_rules_mcp.indexer.embedder import Embedder
from dsa_rules_mcp.store.search import SearchHit, hybrid_search


def _normalize_sources(sources: Sequence[str] | None) -> tuple[str, ...]:
    if not sources:
        return DEFAULT_SEARCH_SOURCES
    valid = tuple(DEFAULT_SOURCE_DIRS.keys())
    filtered = tuple(source for source in sources if source in valid)
    return filtered or DEFAULT_SEARCH_SOURCES


def run_search_rules(
    connection: sqlite3.Connection,
    *,
    embedder: Embedder | None,
    query: str,
    sources: Sequence[str] | None = None,
    limit: int = 10,
) -> dict[str, object]:
    normalized_sources = _normalize_sources(sources)
    limit = max(1, min(int(limit), 50))

    query_embedding = embedder.encode_one(query) if embedder is not None else None
    hits = hybrid_search(
        connection,
        query=query,
        query_embedding=query_embedding,
        categories=normalized_sources,
        limit=limit,
    )
    return {
        "query": query,
        "sources": list(normalized_sources),
        "limit": limit,
        "hits": [_hit_to_dict(hit) for hit in hits],
    }


def _hit_to_dict(hit: SearchHit) -> dict[str, object]:
    return {
        "chunk_id": hit.chunk_id,
        "source_id": hit.source_id,
        "category": hit.category,
        "source_title": hit.source_title,
        "source_path": hit.source_path,
        "page_start": hit.page_start,
        "page_end": hit.page_end,
        "chunk_index": hit.chunk_index,
        "score": round(hit.score, 6),
        "snippet": hit.snippet,
    }
