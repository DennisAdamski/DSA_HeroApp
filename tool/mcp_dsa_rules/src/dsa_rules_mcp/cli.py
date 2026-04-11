"""Manuelle CLI fuer Refresh, Suche und Quellen-Liste ohne MCP-Session."""

from __future__ import annotations

import argparse
import json
import sys
from typing import Sequence

from dsa_rules_mcp.config import ensure_data_dirs, load_config
from dsa_rules_mcp.indexer.embedder import Embedder
from dsa_rules_mcp.store.db import open_database
from dsa_rules_mcp.tools.find_topic import run_find_topic
from dsa_rules_mcp.tools.list_sources import run_list_sources
from dsa_rules_mcp.tools.refresh_index import run_refresh_index
from dsa_rules_mcp.tools.search_rules import run_search_rules


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="dsa-rules-cli",
        description="Manuelle CLI fuer den DSA-Regel-MCP-Index.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    refresh = sub.add_parser("refresh", help="Index aufbauen oder aktualisieren")
    refresh.add_argument("--source", default=None, help="Nur eine Kategorie refreshen")
    refresh.add_argument("--force", action="store_true", help="Komplettes Rebuild")

    search = sub.add_parser("search", help="Hybrid-Suche ausfuehren")
    search.add_argument("query", help="Suchbegriff oder Frage")
    search.add_argument(
        "--sources",
        nargs="*",
        default=None,
        help="Kategorien (Default: regelbuecher hausregeln)",
    )
    search.add_argument("--limit", type=int, default=10)
    search.add_argument("--no-vector", action="store_true", help="Nur FTS, keine Embeddings")

    topic = sub.add_parser("topic", help="Thematisch gebuendelte Treffer")
    topic.add_argument("topic", help="Thema oder Fragestellung")
    topic.add_argument("--sources", nargs="*", default=None)
    topic.add_argument("--limit", type=int, default=15)

    sub.add_parser("list", help="Indexierte PDFs anzeigen")
    return parser


def _progress(message: str) -> None:
    print(message, file=sys.stderr)


def main(argv: Sequence[str] | None = None) -> int:
    parser = _parser()
    args = parser.parse_args(argv)

    config = load_config()
    ensure_data_dirs(config)
    connection = open_database(config.db_path)

    try:
        if args.command == "refresh":
            embedder = Embedder(
                model_name=config.embedding_model_name,
                cache_dir=config.model_cache_dir,
            )
            from dsa_rules_mcp.indexer.pipeline import refresh_index

            stats = refresh_index(
                connection,
                config,
                embedder=embedder,
                source_filter=args.source,
                force=bool(args.force),
                progress=_progress,
            )
            print(json.dumps(stats.to_dict(), indent=2, ensure_ascii=False))
            return 0

        if args.command == "search":
            embedder: Embedder | None = None
            if not args.no_vector:
                embedder = Embedder(
                    model_name=config.embedding_model_name,
                    cache_dir=config.model_cache_dir,
                )
            result = run_search_rules(
                connection,
                embedder=embedder,
                query=args.query,
                sources=args.sources,
                limit=args.limit,
            )
            print(json.dumps(result, indent=2, ensure_ascii=False))
            return 0

        if args.command == "topic":
            embedder = Embedder(
                model_name=config.embedding_model_name,
                cache_dir=config.model_cache_dir,
            )
            result = run_find_topic(
                connection,
                embedder=embedder,
                topic=args.topic,
                sources=args.sources,
                limit=args.limit,
            )
            print(json.dumps(result, indent=2, ensure_ascii=False))
            return 0

        if args.command == "list":
            result = run_list_sources(connection, config)
            print(json.dumps(result, indent=2, ensure_ascii=False))
            return 0

        parser.print_help()
        return 1
    finally:
        connection.close()


if __name__ == "__main__":
    raise SystemExit(main())
