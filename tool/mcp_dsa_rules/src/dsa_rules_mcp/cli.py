"""Manuelle CLI fuer Refresh, Suche und Quellen-Liste ohne MCP-Session."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Sequence

from dsa_rules_mcp.config import ensure_data_dirs, load_config
from dsa_rules_mcp.indexer.embedder import Embedder
from dsa_rules_mcp.publish import PublishError, build_release, upload_commands
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

    publish = sub.add_parser(
        "publish",
        help="Veroeffentlichungsfassung fuer die App bauen (ohne Vektoren, gzip)",
    )
    publish.add_argument(
        "--out",
        default=None,
        help="Zielordner (Default: <Datenordner>/publish)",
    )
    publish.add_argument(
        "--upload",
        metavar="BUCKET",
        default=None,
        help="Danach per gcloud nach gs://BUCKET/rules/ hochladen (ohne: nur bauen "
        "und die Befehle anzeigen)",
    )
    return parser


def _progress(message: str) -> None:
    print(message, file=sys.stderr)


def _publish(db_path: Path, out: str | None, bucket: str | None, data_dir: Path) -> int:
    """Baut die Veroeffentlichungsfassung; mit `--upload` laedt sie hoch.

    Ohne `--upload` bleibt es beim Bauen und Anzeigen der Befehle: ein Upload
    ist ein Betriebsschritt mit eigener Anmeldung und soll nie nebenbei laufen.
    """
    out_dir = Path(out) if out else data_dir / "publish"
    try:
        release = build_release(db_path, out_dir)
    except PublishError as error:
        print(f"Fehler: {error}", file=sys.stderr)
        return 1
    print(json.dumps(release, indent=2, ensure_ascii=False))
    print(
        f"\nGebaut in {out_dir}: {release['gzipBytes'] / 1048576:.1f} MB gepackt "
        f"({release['sizeBytes'] / 1048576:.1f} MB entpackt).",
        file=sys.stderr,
    )
    commands = upload_commands(release, out_dir, bucket or "<BUCKET>")
    if bucket is None:
        print("\nHochladen (Datei zuerst, dann der Verweis):", file=sys.stderr)
        for command in commands:
            print("  " + " ".join(f'"{part}"' if " " in part else part for part in command),
                  file=sys.stderr)
        print("\nOder gleich: dsa-rules-cli publish --upload <BUCKET>", file=sys.stderr)
        return 0
    if shutil.which("gcloud") is None:
        print("Fehler: gcloud nicht gefunden. Befehle oben von Hand ausfuehren.",
              file=sys.stderr)
        return 1
    for command in commands:
        print("> " + " ".join(command), file=sys.stderr)
        result = subprocess.run(command, check=False)
        if result.returncode != 0:
            print("Upload abgebrochen; `latest.json` zeigt weiter auf die alte Datei.",
                  file=sys.stderr)
            return result.returncode
    print("Fertig. Die App sieht die neue Fassung beim naechsten Laden.", file=sys.stderr)
    return 0


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

        if args.command == "publish":
            return _publish(config.db_path, args.out, args.upload, config.data_dir)

        parser.print_help()
        return 1
    finally:
        connection.close()


if __name__ == "__main__":
    raise SystemExit(main())
