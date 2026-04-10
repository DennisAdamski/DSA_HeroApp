"""CLI-Einstieg fuer den PDF-Katalog-Agenten."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from pdf_catalog_agent.agent import PdfCatalogAgent
from pdf_catalog_agent.config import DEFAULT_CONFIG_PATH, default_artifact_root


def _configure_stdio() -> None:
    """Setzt UTF-8 fuer CLI-Ausgaben, falls die Plattform das unterstuetzt."""

    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    if hasattr(sys.stderr, 'reconfigure'):
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')


def build_parser() -> argparse.ArgumentParser:
    """Erstellt den Subcommand-Parser fuer das Tool."""

    parser = argparse.ArgumentParser(
        description='Lokaler PDF-Agent fuer DSA-Wissensbasis und App-Anforderungen.',
    )
    parser.add_argument(
        '--config',
        default=str(DEFAULT_CONFIG_PATH),
        help='Pfad zur JSON-Quellkonfiguration.',
    )
    parser.add_argument(
        '--artifact-root',
        default=str(default_artifact_root()),
        help='Lokaler Ordner fuer Datenbank, Reports und Exporte.',
    )

    subparsers = parser.add_subparsers(dest='command', required=True)

    ingest_parser = subparsers.add_parser('ingest', help='Indexiert alle aktiven PDF-Quellen.')
    ingest_parser.add_argument('--force', action='store_true', help='Reindiziert alle PDFs unabhaengig vom Hash.')

    search_parser = subparsers.add_parser('search', help='Durchsucht den lokalen Volltextindex.')
    search_parser.add_argument('--query', required=True, help='Freitextanfrage fuer FTS5.')
    search_parser.add_argument('--limit', type=int, default=10, help='Maximale Trefferzahl.')
    search_parser.add_argument('--topic', help='Optionaler Topic-Filter.')
    search_parser.add_argument('--source-type', help='Optionaler Filter nach Quelltyp.')
    search_parser.add_argument('--json', action='store_true', help='Gibt Treffer als JSON aus.')

    propose_parser = subparsers.add_parser('propose', help='Erzeugt App-Vorschlaege fuer ein Thema.')
    propose_parser.add_argument('--topic', required=True, help='Thema oder Bereich fuer Vorschlaege.')
    propose_parser.add_argument('--limit', type=int, default=8, help='Maximale Evidenz-Trefferzahl.')
    propose_parser.add_argument('--json', action='store_true', help='Gibt Vorschlaege als JSON aus.')

    conflict_parser = subparsers.add_parser('conflicts', help='Zeigt Konflikt- und Prioritaetshinweise.')
    conflict_parser.add_argument('--topic', help='Optionaler Topic-Filter.')
    conflict_parser.add_argument('--json', action='store_true', help='Gibt Konflikte als JSON aus.')

    review_parser = subparsers.add_parser('review', help='Erzeugt einen lokalen Review-Bericht.')
    review_parser.add_argument('--json', action='store_true', help='Gibt den Review-Bericht als JSON aus.')

    return parser


def main() -> int:
    """Fuehrt den gewaehlten CLI-Befehl aus."""

    _configure_stdio()
    parser = build_parser()
    args = parser.parse_args()
    agent = PdfCatalogAgent(
        config_path=Path(args.config),
        artifact_root=Path(args.artifact_root),
    )
    try:
        if args.command == 'ingest':
            print(json.dumps(agent.ingest(force=args.force), indent=2, ensure_ascii=False))
            return 0

        if args.command == 'search':
            results = agent.search(
                query=args.query,
                limit=args.limit,
                topic=args.topic,
                source_type=args.source_type,
            )
            if args.json:
                print(json.dumps([entry.to_dict() for entry in results], indent=2, ensure_ascii=False))
                return 0
            for entry in results:
                print(
                    f'- {entry.source_title} [{entry.source_type}] '
                    f'S. {entry.page_start}-{entry.page_end}: {entry.section_title}',
                )
                print(f'  Pfad: {entry.path}')
                print(f'  Topics: {", ".join(entry.topics)}')
                print(f'  Auszug: {entry.excerpt}')
            return 0

        if args.command == 'propose':
            payload = [entry.to_dict() for entry in agent.propose(topic=args.topic, limit=args.limit)]
            if args.json:
                print(json.dumps(payload, indent=2, ensure_ascii=False))
                return 0
            for entry in payload:
                print(f"- {entry['titel']} [{entry['bereich']}]")
                print(f"  Problem: {entry['problem']}")
                print(f"  Vorschlag: {entry['vorschlag']}")
                print(f"  Vertrauen: {entry['vertrauen']}")
                print(f"  Quellen: {len(entry['quellen'])}")
                print(f"  Konflikte: {len(entry['konflikte'])}")
            return 0

        if args.command == 'conflicts':
            payload = [entry.to_dict() for entry in agent.conflicts(topic=args.topic)]
            if args.json:
                print(json.dumps(payload, indent=2, ensure_ascii=False))
                return 0
            for entry in payload:
                print(
                    f"- {entry['topic']} [{entry['relationType']}] "
                    f"{entry['winnerSourceTitle']} -> {entry['loserSourceTitle']}",
                )
                print(f"  {entry['summary']}")
                print(
                    f"  Sieger: {entry['winnerPath']} S. {entry['winnerPage']} | "
                    f"Unterlegen: {entry['loserPath']} S. {entry['loserPage']}",
                )
            return 0

        if args.command == 'review':
            review = agent.review()
            print(json.dumps(review, indent=2, ensure_ascii=False))
            return 0

        parser.error(f'Unbekannter Befehl: {args.command}')
        return 2
    finally:
        agent.close()


if __name__ == '__main__':
    raise SystemExit(main())
