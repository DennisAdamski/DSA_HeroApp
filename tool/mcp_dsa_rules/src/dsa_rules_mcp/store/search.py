"""Hybrid-Suche: FTS5 + Vektor-Ranking + Reciprocal Rank Fusion."""

from __future__ import annotations

import math
import re
import sqlite3
from dataclasses import dataclass
from typing import Sequence

import numpy as np

from dsa_rules_mcp.config import SOURCE_PRIORITIES
from dsa_rules_mcp.store.db import (
    ChunkRow,
    fetch_chunks_by_ids,
    iter_embeddings,
    source_ids_for_categories,
)


FTS_CANDIDATE_LIMIT = 50
VECTOR_CANDIDATE_LIMIT = 50
RRF_K = 60


@dataclass(frozen=True)
class SearchHit:
    chunk_id: int
    source_id: int
    category: str
    source_title: str
    source_path: str
    page_start: int
    page_end: int
    chunk_index: int
    score: float
    snippet: str
    text: str


def _sanitize_fts_query(query: str) -> str:
    """Bereinigt eine Nutzereingabe zu einer sicheren FTS5-Match-Query.

    Entfernt FTS-Sonderzeichen und baut eine AND-Verknuepfung aller Tokens mit
    Praefix-Matching, damit auch Teilworte Treffer liefern.
    """

    tokens = re.findall(r"[\wäöüÄÖÜß]+", query, flags=re.UNICODE)
    if not tokens:
        return ""
    return " AND ".join(f'"{token}"*' for token in tokens if len(token) >= 2)


def _make_snippet(text: str, query: str, length: int = 220) -> str:
    tokens = [t for t in re.findall(r"[\wäöüÄÖÜß]+", query, flags=re.UNICODE) if len(t) >= 2]
    lowered = text.lower()
    best_index = -1
    for token in tokens:
        idx = lowered.find(token.lower())
        if idx != -1 and (best_index == -1 or idx < best_index):
            best_index = idx
    if best_index == -1:
        snippet = text[:length]
    else:
        start = max(0, best_index - length // 3)
        snippet = text[start : start + length]
    snippet = snippet.strip().replace("\n", " ")
    if len(text) > length:
        snippet += " ..."
    return snippet


def _embedding_array(payload: bytes, dim: int) -> np.ndarray:
    array = np.frombuffer(payload, dtype=np.float32)
    if array.size != dim:
        raise ValueError(f"Embedding mit {array.size} Werten passt nicht zu dim={dim}")
    return array


def fts_candidates(
    connection: sqlite3.Connection,
    *,
    query: str,
    source_ids: Sequence[int],
    limit: int,
) -> list[tuple[int, float]]:
    sanitized = _sanitize_fts_query(query)
    if not sanitized or not source_ids:
        return []
    placeholders = ",".join("?" * len(source_ids))
    sql = (
        "SELECT c.id AS chunk_id, bm25(chunks_fts) AS score "
        "FROM chunks_fts JOIN chunks c ON c.id = chunks_fts.rowid "
        f"WHERE chunks_fts MATCH ? AND c.source_id IN ({placeholders}) "
        "ORDER BY score LIMIT ?"
    )
    params = (sanitized, *source_ids, limit)
    rows = connection.execute(sql, params).fetchall()
    return [(int(row["chunk_id"]), float(row["score"])) for row in rows]


def vector_candidates(
    connection: sqlite3.Connection,
    *,
    query_embedding: np.ndarray,
    source_ids: Sequence[int],
    limit: int,
) -> list[tuple[int, float]]:
    if not source_ids:
        return []
    normalized_query = query_embedding / (np.linalg.norm(query_embedding) + 1e-12)
    scored: list[tuple[int, float]] = []
    for chunk_id, _source_id, dim, payload in iter_embeddings(connection, source_ids):
        vector = _embedding_array(payload, dim)
        norm = np.linalg.norm(vector) + 1e-12
        similarity = float(np.dot(normalized_query, vector / norm))
        scored.append((chunk_id, similarity))
    scored.sort(key=lambda item: item[1], reverse=True)
    return scored[:limit]


def reciprocal_rank_fusion(
    *,
    fts_ranking: Sequence[tuple[int, float]],
    vector_ranking: Sequence[tuple[int, float]],
    category_by_source_id: dict[int, str],
    chunk_source_lookup: dict[int, int],
    k: int = RRF_K,
) -> list[tuple[int, float]]:
    """Vereinigt zwei Ranglisten per RRF und gewichtet mit Quellen-Prioritaet."""

    fused: dict[int, float] = {}
    for rank, (chunk_id, _) in enumerate(fts_ranking, start=1):
        fused[chunk_id] = fused.get(chunk_id, 0.0) + 1.0 / (k + rank)
    for rank, (chunk_id, _) in enumerate(vector_ranking, start=1):
        fused[chunk_id] = fused.get(chunk_id, 0.0) + 1.0 / (k + rank)

    max_priority = max(SOURCE_PRIORITIES.values()) or 1
    weighted: list[tuple[int, float]] = []
    for chunk_id, score in fused.items():
        source_id = chunk_source_lookup.get(chunk_id)
        category = category_by_source_id.get(source_id, "") if source_id is not None else ""
        priority = SOURCE_PRIORITIES.get(category, 50)
        weight = 0.7 + 0.3 * (priority / max_priority)
        weighted.append((chunk_id, score * weight))
    weighted.sort(key=lambda item: item[1], reverse=True)
    return weighted


def hybrid_search(
    connection: sqlite3.Connection,
    *,
    query: str,
    query_embedding: np.ndarray | None,
    categories: Sequence[str],
    limit: int,
) -> list[SearchHit]:
    source_ids = source_ids_for_categories(connection, categories)
    if not source_ids:
        return []

    fts_ranking = fts_candidates(
        connection,
        query=query,
        source_ids=source_ids,
        limit=FTS_CANDIDATE_LIMIT,
    )
    if query_embedding is not None:
        vector_ranking = vector_candidates(
            connection,
            query_embedding=query_embedding,
            source_ids=source_ids,
            limit=VECTOR_CANDIDATE_LIMIT,
        )
    else:
        vector_ranking = []

    candidate_ids = {cid for cid, _ in fts_ranking} | {cid for cid, _ in vector_ranking}
    if not candidate_ids:
        return []

    chunk_rows = fetch_chunks_by_ids(connection, list(candidate_ids))
    chunk_by_id: dict[int, ChunkRow] = {row.id: row for row in chunk_rows}
    chunk_source_lookup = {row.id: row.source_id for row in chunk_rows}

    source_meta_rows = connection.execute(
        f"SELECT id, category, path, title FROM sources WHERE id IN "
        f"({','.join('?' * len({row.source_id for row in chunk_rows}))})",
        tuple({row.source_id for row in chunk_rows}),
    ).fetchall()
    category_by_source_id: dict[int, str] = {
        int(row["id"]): row["category"] for row in source_meta_rows
    }
    source_meta: dict[int, sqlite3.Row] = {int(row["id"]): row for row in source_meta_rows}

    fused = reciprocal_rank_fusion(
        fts_ranking=fts_ranking,
        vector_ranking=vector_ranking,
        category_by_source_id=category_by_source_id,
        chunk_source_lookup=chunk_source_lookup,
    )

    hits: list[SearchHit] = []
    for chunk_id, score in fused[:limit]:
        chunk = chunk_by_id.get(chunk_id)
        if chunk is None:
            continue
        meta_row = source_meta.get(chunk.source_id)
        if meta_row is None:
            continue
        hits.append(
            SearchHit(
                chunk_id=chunk_id,
                source_id=chunk.source_id,
                category=meta_row["category"],
                source_title=meta_row["title"],
                source_path=meta_row["path"],
                page_start=chunk.page_start,
                page_end=chunk.page_end,
                chunk_index=chunk.chunk_index,
                score=score,
                snippet=_make_snippet(chunk.text, query),
                text=chunk.text,
            )
        )
    return hits
