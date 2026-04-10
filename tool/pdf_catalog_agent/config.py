"""Konfigurationshelfer fuer den PDF-Katalog-Agenten."""

from __future__ import annotations

import json
from pathlib import Path

from pdf_catalog_agent.models import KNOWN_SOURCE_TYPES, KNOWN_TOPICS, SourceConfig


DEFAULT_CONFIG_PATH = Path(__file__).resolve().parent / 'config' / 'sources.json'


def repo_root() -> Path:
    """Liefert das Repository-Root relativ zu diesem Paket."""

    return Path(__file__).resolve().parents[2]


def default_artifact_root() -> Path:
    """Liefert den lokalen Zielordner fuer Datenbank, Reports und Exporte."""

    return repo_root() / '.codex' / 'pdf_catalog'


def load_source_configs(config_path: Path | None = None) -> list[SourceConfig]:
    """Laedt und validiert die statischen Quellordner des Agenten."""

    path = config_path or DEFAULT_CONFIG_PATH
    payload = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(payload, list):
        raise ValueError(f'Expected a JSON array in {path}')

    results: list[SourceConfig] = []
    seen_ids: set[str] = set()
    for entry in payload:
        if not isinstance(entry, dict):
            raise ValueError(f'Invalid source entry in {path}: {entry!r}')

        source_id = str(entry.get('id', '')).strip()
        if not source_id:
            raise ValueError(f'Missing source id in {path}')
        if source_id in seen_ids:
            raise ValueError(f'Duplicate source id "{source_id}" in {path}')
        seen_ids.add(source_id)

        source_type = str(entry.get('sourceType', '')).strip()
        if source_type not in KNOWN_SOURCE_TYPES:
            raise ValueError(f'Unknown sourceType "{source_type}" in {path}')

        raw_topics = entry.get('defaultTopics', [])
        if not isinstance(raw_topics, list):
            raise ValueError(f'Expected list defaultTopics for "{source_id}"')

        default_topics: list[str] = []
        for topic in raw_topics:
            value = str(topic).strip()
            if value not in KNOWN_TOPICS:
                raise ValueError(
                    f'Unknown topic "{value}" in defaultTopics for "{source_id}"',
                )
            default_topics.append(value)

        results.append(
            SourceConfig(
                id=source_id,
                title=str(entry.get('title', source_id)).strip() or source_id,
                path=Path(str(entry.get('path', '')).strip()),
                source_type=source_type,
                priority=int(entry.get('priority', 0)),
                normative_weight=int(entry.get('normativeWeight', 0)),
                enabled=bool(entry.get('enabled', True)),
                default_topics=tuple(default_topics),
            ),
        )

    return sorted(results, key=lambda item: (item.priority, item.title))
