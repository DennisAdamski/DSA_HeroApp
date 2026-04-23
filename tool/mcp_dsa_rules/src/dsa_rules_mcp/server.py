"""MCP-Server-Entry: FastMCP-Registrierung der Tools und stdio-Loop."""

from __future__ import annotations

import logging
import sqlite3
import sys
import time
from typing import Any

from dsa_rules_mcp.config import DEFAULT_SEARCH_SOURCES, McpConfig, ensure_data_dirs, load_config
from dsa_rules_mcp.indexer.embedder import Embedder
from dsa_rules_mcp.store.db import open_database
from dsa_rules_mcp.tools.find_topic import run_find_topic
from dsa_rules_mcp.tools.get_context import run_get_context
from dsa_rules_mcp.tools.list_sources import run_list_sources
from dsa_rules_mcp.tools.refresh_index import run_refresh_index
from dsa_rules_mcp.tools.search_rules import run_search_rules


logger = logging.getLogger("dsa_rules_mcp")


class ServerContext:
    """Lazy-Initialisierung von DB und Embedder fuer die Laufzeit des Servers."""

    def __init__(self) -> None:
        self._config: McpConfig | None = None
        self._connection: sqlite3.Connection | None = None
        self._embedder: Embedder | None = None

    @property
    def config(self) -> McpConfig:
        if self._config is None:
            self._config = load_config()
            ensure_data_dirs(self._config)
        return self._config

    @property
    def connection(self) -> sqlite3.Connection:
        if self._connection is None:
            self._connection = open_database(self.config.db_path)
        return self._connection

    @property
    def embedder(self) -> Embedder:
        if self._embedder is None:
            self._embedder = Embedder(
                model_name=self.config.embedding_model_name,
                cache_dir=self.config.model_cache_dir,
            )
        return self._embedder


_context = ServerContext()


def _build_mcp() -> Any:
    from mcp.server.fastmcp import FastMCP  # type: ignore[import-not-found]

    mcp = FastMCP("dsa-rules")

    @mcp.tool()
    def search_rules(
        query: str,
        sources: list[str] | None = None,
        limit: int = 10,
    ) -> dict[str, object]:
        """Hybride Suche (FTS5 + Vektor) ueber DSA-Regelwerke und Hausregeln.

        Parameter:
            query: Suchbegriff oder Frage.
            sources: Quellen-Kategorien, z. B. ["regelbuecher", "hausregeln"].
                Default: regelbuecher + hausregeln.
            limit: Maximale Treffer (1..50).
        """

        t0 = time.perf_counter()
        try:
            return run_search_rules(
                _context.connection,
                embedder=_context.embedder,
                query=query,
                sources=sources,
                limit=limit,
            )
        finally:
            logger.info("search_rules done in %.2fs (query=%r, limit=%d)", time.perf_counter() - t0, query, limit)

    @mcp.tool()
    def get_context(chunk_id: int, window: int = 1) -> dict[str, object]:
        """Liefert den vollen Text eines Treffers plus Nachbarchunks.

        Parameter:
            chunk_id: Chunk-ID aus `search_rules`.
            window: Anzahl benachbarter Chunks vor und nach dem Treffer (0..5).
        """

        t0 = time.perf_counter()
        try:
            return run_get_context(
                _context.connection,
                chunk_id=chunk_id,
                window=window,
            )
        finally:
            logger.info("get_context done in %.2fs (chunk_id=%d, window=%d)", time.perf_counter() - t0, chunk_id, window)

    @mcp.tool()
    def list_sources(category: str | None = None) -> dict[str, object]:
        """Listet indexierte PDFs je Kategorie oder fuer eine bestimmte Kategorie."""

        t0 = time.perf_counter()
        try:
            return run_list_sources(
                _context.connection,
                _context.config,
                category=category,
            )
        finally:
            logger.info("list_sources done in %.2fs (category=%r)", time.perf_counter() - t0, category)

    @mcp.tool()
    def refresh_index(
        source: str | None = None,
        force: bool = False,
    ) -> dict[str, object]:
        """Aktualisiert den Index inkrementell oder vollstaendig.

        Parameter:
            source: Optionale Kategorie (`regelbuecher`, `hausregeln`, ...).
            force: True erzwingt komplettes Neu-Indexieren.
        """

        t0 = time.perf_counter()
        try:
            return run_refresh_index(
                _context.connection,
                _context.config,
                embedder=_context.embedder,
                source=source,
                force=force,
            )
        finally:
            logger.info("refresh_index done in %.2fs (source=%r, force=%s)", time.perf_counter() - t0, source, force)

    @mcp.tool()
    def find_topic(
        topic: str,
        sources: list[str] | None = None,
        limit: int = 15,
    ) -> dict[str, object]:
        """Thematisch gebuendelte Treffer fuer Anforderungs-Brainstorming.

        Parameter:
            topic: Thema oder Fragestellung.
            sources: Quellen-Kategorien (Default: regelbuecher + hausregeln).
            limit: Maximale Treffer gesamt (1..50).
        """

        t0 = time.perf_counter()
        try:
            return run_find_topic(
                _context.connection,
                embedder=_context.embedder,
                topic=topic,
                sources=sources,
                limit=limit,
            )
        finally:
            logger.info("find_topic done in %.2fs (topic=%r, limit=%d)", time.perf_counter() - t0, topic, limit)

    return mcp


def main() -> None:
    """Startet den stdio-basierten MCP-Server."""

    logging.basicConfig(
        level=logging.INFO,
        stream=sys.stderr,
        format="[dsa-rules] %(asctime)s %(levelname)s %(message)s",
    )

    mcp = _build_mcp()

    try:
        t0 = time.perf_counter()
        dim = _context.embedder.dim
        logger.info("embedder ready in %.2fs (dim=%d)", time.perf_counter() - t0, dim)
    except Exception as exc:
        logger.error("embedder warm-up failed: %s (continuing without vector search)", exc, exc_info=True)

    mcp.run()


if __name__ == "__main__":
    main()
