"""MCP-Tool: Vergleicht neue Hausregel-Fassungen mit den alten und nennt Fundstellen.

Ablauf: Der Spielleiter liefert neue Dokumente, die nach `<hausregeln>/Neu/`
kommen. Das Tool sucht zu jedem die alte Fassung in `<hausregeln>/`, bildet
einen satzweisen Diff (robust gegen Umbrueche und neue Seitenaufteilung) und
haengt an jeden geaenderten Abschnitt die Katalogeintraege und Dart-Dateien,
deren Namen bzw. IDs darin vorkommen. Die fachliche Bewertung macht der Aufrufer.
"""

from __future__ import annotations

import difflib
import json
import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence

from dsa_rules_mcp.config import INBOX_DIRNAME, McpConfig
from dsa_rules_mcp.indexer.chunker import split_sentences
from dsa_rules_mcp.indexer.pdf_extract import (
    ExtractedPage,
    extract_pages,
    supported_document_suffixes,
)

_MAX_MATCHES_PER_HUNK = 15
_MAX_DART_FILES_PER_ID = 8
_MIN_NAME_LENGTH = 4


@dataclass(frozen=True)
class Sentence:
    page: int
    text: str


@dataclass(frozen=True)
class CatalogEntry:
    id: str
    name: str
    file: str
    pack: str | None


def normalize_stem(path: Path) -> str:
    """`Epische Stufen (1).pdf` und `Epische Stufen.pdf` ergeben denselben Schluessel."""

    stem = re.sub(r"\s*\(\d+\)$", "", path.stem)
    return " ".join(stem.split()).casefold()


def document_sentences(pages: Sequence[ExtractedPage]) -> list[Sentence]:
    sentences: list[Sentence] = []
    for page in pages:
        # Silbentrennung am Zeilenende zusammenziehen, dann Whitespace kollabieren.
        text = re.sub(r"(\w)-\n(\w)", r"\1\2", page.text)
        text = " ".join(text.split())
        for sentence in split_sentences(text):
            sentences.append(Sentence(page=page.page_number, text=sentence))
    return sentences


def _key(text: str) -> str:
    return re.sub(r"\W+", "", text.casefold())


def _pages(sentences: Sequence[Sentence]) -> list[int]:
    return sorted({sentence.page for sentence in sentences})


def diff_sentences(old: Sequence[Sentence], new: Sequence[Sentence]) -> list[dict[str, object]]:
    """Satzweiser Diff; Vergleich ohne Satzzeichen/Gross-Klein, Ausgabe im Original."""

    old_keys = [_key(s.text) for s in old]
    new_keys = [_key(s.text) for s in new]
    old_key_set, new_key_set = set(old_keys), set(new_keys)
    matcher = difflib.SequenceMatcher(a=old_keys, b=new_keys, autojunk=False)
    hunks: list[dict[str, object]] = []
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            continue
        # Saetze, die nur an eine andere Stelle verschoben wurden, sind keine Aenderung.
        old_part = [s for s, k in zip(old[i1:i2], old_keys[i1:i2]) if k not in new_key_set]
        new_part = [s for s, k in zip(new[j1:j2], new_keys[j1:j2]) if k not in old_key_set]
        moved = (i2 - i1 - len(old_part)) + (j2 - j1 - len(new_part))
        # Nur anders in Saetze zerlegt (z. B. "z.B." am Zeilenende): kein Inhaltsunterschied.
        if _key("".join(s.text for s in old_part)) == _key("".join(s.text for s in new_part)):
            continue
        op = "changed" if old_part and new_part else ("added" if new_part else "removed")
        hunks.append(
            {
                "op": op,
                "moved_sentences": moved,
                "old_pages": _pages(old_part),
                "new_pages": _pages(new_part),
                "old_text": " ".join(s.text for s in old_part),
                "new_text": " ".join(s.text for s in new_part),
            }
        )
    return hunks


def _walk_entries(node: object, file: str, pack: str | None) -> Iterable[CatalogEntry]:
    if isinstance(node, dict):
        entry_id, name = node.get("id"), node.get("name")
        if isinstance(entry_id, str) and isinstance(name, str) and not name.startswith("enc:"):
            yield CatalogEntry(id=entry_id, name=name, file=file, pack=pack)
        for value in node.values():
            yield from _walk_entries(value, file, pack)
    elif isinstance(node, list):
        for value in node:
            yield from _walk_entries(value, file, pack)


def load_catalog_entries(catalog_dir: Path, repo_dir: Path) -> list[CatalogEntry]:
    entries: list[CatalogEntry] = []
    for path in sorted(catalog_dir.rglob("*.json")):
        try:
            payload = json.loads(path.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError):
            continue
        pack = payload.get("id") if path.name == "manifest.json" and isinstance(payload, dict) else None
        rel = path.relative_to(repo_dir).as_posix()
        # Das Manifest selbst traegt id+title, nicht name; nur Eintraege darunter.
        entries.extend(e for e in _walk_entries(payload, rel, pack) if e.id != pack)
    return entries


def match_entries(text: str, entries: Sequence[CatalogEntry]) -> list[CatalogEntry]:
    lowered = text.casefold()
    hits: list[CatalogEntry] = []
    seen: set[tuple[str, str]] = set()
    for entry in entries:
        name = entry.name.casefold()
        if len(name) < _MIN_NAME_LENGTH or (entry.id, entry.file) in seen:
            continue
        if re.search(rf"(?<!\w){re.escape(name)}(?!\w)", lowered):
            seen.add((entry.id, entry.file))
            hits.append(entry)
    # Laengere Namen zuerst: "Zweihändiger Kampf II" vor "Kampf".
    hits.sort(key=lambda entry: -len(entry.name))
    return hits[:_MAX_MATCHES_PER_HUNK]


def _default_repo_dir() -> Path:
    override = os.environ.get("DSA_MCP_REPO_DIR")
    if override:
        return Path(override)
    # tool/mcp_dsa_rules/src/dsa_rules_mcp/tools/compare_hausregeln.py -> Repo-Wurzel
    return Path(__file__).resolve().parents[5]


def _documents(directory: Path) -> list[Path]:
    suffixes = supported_document_suffixes()
    return sorted(p for p in directory.iterdir() if p.is_file() and p.suffix.lower() in suffixes)


def run_compare_hausregeln(
    config: McpConfig,
    *,
    document: str | None = None,
    repo_dir: Path | None = None,
) -> dict[str, object]:
    source = config.source_by_id("hausregeln")
    if source is None or not source.exists:
        return {"error": "Hausregel-Ordner fehlt."}
    inbox = source.path / INBOX_DIRNAME
    if not inbox.is_dir():
        return {"error": f"Eingangsordner fehlt: {inbox}"}

    repo = repo_dir or _default_repo_dir()
    entries = load_catalog_entries(repo / "assets" / "catalogs" / "house_rules_v1", repo)
    dart_files = {
        path.relative_to(repo).as_posix(): path.read_text(encoding="utf-8", errors="ignore")
        for path in (repo / "lib").rglob("*.dart")
    }
    old_by_stem = {normalize_stem(path): path for path in _documents(source.path)}

    results: list[dict[str, object]] = []
    for new_path in _documents(inbox):
        if document and document.casefold() not in new_path.name.casefold():
            continue
        old_path = old_by_stem.get(normalize_stem(new_path))
        new_sentences = document_sentences(extract_pages(new_path))
        old_sentences = document_sentences(extract_pages(old_path)) if old_path else []
        hunks = diff_sentences(old_sentences, new_sentences)
        for hunk in hunks:
            matches = match_entries(f"{hunk['old_text']} {hunk['new_text']}", entries)
            hunk["catalog_matches"] = [
                {
                    "id": entry.id,
                    "name": entry.name,
                    "file": entry.file,
                    "pack": entry.pack,
                    "dart_files": [f for f, text in dart_files.items() if entry.id in text][
                        :_MAX_DART_FILES_PER_ID
                    ],
                }
                for entry in matches
            ]
        results.append(
            {
                "new_path": str(new_path),
                "old_path": str(old_path) if old_path else None,
                "status": "geaendert" if old_path else "neu",
                "sentences": {"old": len(old_sentences), "new": len(new_sentences)},
                "hunk_count": len(hunks),
                "hunks": hunks,
            }
        )
    return {"inbox": str(inbox), "documents": results}
