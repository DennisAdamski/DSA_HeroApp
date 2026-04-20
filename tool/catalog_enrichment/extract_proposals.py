"""Extraktions-Tool fuer Sonderfertigkeits-Kandidaten.

Liest die MCP-SQLite-Index-DB, findet Chunks mit SF-Struktur (Voraussetzungen +
Verbreitung + Kosten) und schreibt Vorschlaege pro Sektion nach
``.codex/catalog_enrichment``. Das Tool ersetzt keinen Rulebook-Leser: es emittiert
Rohkandidaten, die manuell gesichtet und in die Katalog-JSONs uebernommen werden.
"""

from __future__ import annotations

import json
import os
import re
import sqlite3
import sys
import unicodedata
from collections import OrderedDict
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
PROPOSALS_DIR = REPO_ROOT / ".codex" / "catalog_enrichment"
CATALOG_DIR = REPO_ROOT / "assets" / "catalogs" / "house_rules_v1"


def db_path() -> Path:
    local = os.environ.get("LOCALAPPDATA")
    if not local:
        raise SystemExit("LOCALAPPDATA nicht gesetzt - Windows erwartet.")
    return Path(local) / "dsa-rules-mcp" / "index.sqlite"


def normalize_name(name: str) -> str:
    name = unicodedata.normalize("NFKD", name)
    name = "".join(ch for ch in name if not unicodedata.combining(ch))
    name = name.lower()
    name = re.sub(r"[^a-z0-9]+", "_", name).strip("_")
    return name


def load_existing_names(filename: str) -> set[str]:
    path = CATALOG_DIR / filename
    if not path.is_file():
        return set()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return set()
    names: set[str] = set()
    for entry in data:
        if not isinstance(entry, dict):
            continue
        for key in ("name", "id"):
            value = entry.get(key)
            if isinstance(value, str) and value.strip():
                names.add(normalize_name(value))
    return names


EXISTING_SECTIONS = {
    "kampf_sf": "kampf_sonderfertigkeiten.json",
    "manoever": "manoever.json",
    "allgemeine_sf": "allgemeine_sonderfertigkeiten.json",
    "magische_sf": "magische_sonderfertigkeiten.json",
    "karmale_sf": "karmale_sonderfertigkeiten.json",
}


SECTION_BY_BOOK = {
    "Wege des Schwerts": "kampf_sf",
    "Wege der Helden": "allgemeine_sf",
    "Wege der Zauberei": "magische_sf",
    "Wege der Götter": "karmale_sf",
    "Wege der Goetter": "karmale_sf",
    "Wege der G?tter": "karmale_sf",
    "Staebe Ringe Dschinnenlampen (2011, TruePDF)": "magische_sf",
    "Wege der Alchimie (2. Auflage 2012, TruePDF)": "magische_sf",
}


RE_VORAUS = re.compile(r"Voraussetzungen?\s*:\s*(.+?)(?=\s*(?:Verbreitung|Lernkosten|Kosten)\s*:)", re.DOTALL)
RE_VERBREITUNG = re.compile(r"Verbreitung\s*:\s*(.+?)(?=\s*(?:Lernkosten|Kosten|Voraussetzung|$))", re.DOTALL)
RE_KOSTEN = re.compile(r"(?:Lernkosten|Kosten)\s*:\s*(.+?)(?=\s*(?:Voraussetzung|Verbreitung|Wirkung|Anmerkung|$))", re.DOTALL)

# Erkennt einen Namen unmittelbar vor "Voraussetzungen:".
# Typisch: kurze Zeile, Grossbuchstabe vorne, evtl. Markierung wie "(Z)" oder "I"/"II".
NAME_MAX_LEN = 80


STOP_START_PREV_KOSTEN = re.compile(
    r"(?:Kosten|Lernkosten)\s*:\s*[^\n]{0,400}?(?:\bAP\b|\)\s*|\.\s+)",
    re.IGNORECASE,
)
BODY_STARTER = re.compile(
    r"\b(?:Diese[rs]?|Der|Die|Das|Ein[e]?[mnrs]?|Mit|Erlaubt|Erm[o\u00f6]glicht|"
    r"Erh[o\u00f6]ht|Gibt|Sie|Erf[a\u00e4]hrt|Wer|Solange|F[u\u00fc]r|Ein[s]?tzbar|"
    r"Bei|Nach|Beim|Kann|Reduziert|Verschafft|Gew[a\u00e4]hrt|Erlaubt|Verringert|"
    r"Verbessert|Senkt|Steigert|Erweitert|Zwei|Drei|Vier|Dieser|Als|Wenn|W[a\u00e4]hrend|"
    r"Im|In|Am|An|Auf|Mit|Vor|Unter|\u00dcber|Hinter)\b"
)


def split_entries(text: str) -> list[tuple[str, str]]:
    """Zerlegt einen Chunk in (name, body)-Paare mit Kontext-Walkback.

    Fuer jedes ``Voraussetzungen:``-Token wird der Text zwischen dem
    vorherigen ``Kosten:``-Abschnitt (oder Chunk-Start) und dem aktuellen
    ``Voraussetzungen:`` als Eintragsvorspann genommen. Der Name ist der
    erste kapitalisierte Phrasen-Block vor einem typischen Body-Wort.
    """

    positions = [m.start() for m in re.finditer(r"Voraussetzungen?\s*:", text)]
    if not positions:
        return []

    entries: list[tuple[str, str]] = []
    prev_end = 0
    for pos in positions:
        span_start = prev_end
        # finde letzte Kosten-Grenze vor `pos`
        prev_kosten = None
        for match in STOP_START_PREV_KOSTEN.finditer(text, prev_end, pos):
            prev_kosten = match
        if prev_kosten is not None:
            span_start = prev_kosten.end()

        prefix = text[span_start:pos]
        candidate = extract_name_from_prefix(prefix)
        body_end = positions[positions.index(pos) + 1] if pos != positions[-1] else len(text)
        body = text[pos:body_end]
        prev_end = pos + len("Voraussetzungen:")
        if not candidate:
            continue
        entries.append((candidate, body.strip()))
    return entries


def extract_name_from_prefix(prefix: str) -> str | None:
    prefix = prefix.strip(" \n\r\t-\u2013\u2014.,;:")
    if not prefix:
        return None
    body_match = BODY_STARTER.search(prefix)
    if body_match:
        name_part = prefix[: body_match.start()].strip(" \n\r\t-.,;:")
    else:
        name_part = prefix.strip()
    if not name_part:
        return None
    # Erste 1-5 Woerter, Bindestriche erlaubt
    tokens = re.findall(
        r"[A-Z\u00c4\u00d6\u00dc][A-Za-z\u00c4\u00d6\u00dc\u00e4\u00f6\u00fc\u00df\-]*"
        r"(?:\s+(?:[A-Z\u00c4\u00d6\u00dc][A-Za-z\u00c4\u00d6\u00dc\u00e4\u00f6\u00fc\u00df\-]*|"
        r"von|der|des|in|im|am|und|&|I{1,3}|IV|\(Z\)|\(Zaub\)|\(ZH\)|\(G\)))*",
        name_part,
    )
    if not tokens:
        return None
    # Nimm den letzten passenden Match (der naechste an body_starter)
    last = tokens[-1].strip()
    # Entferne Ein-Wort-Stopwoerter
    blacklist = {"Voraussetzungen", "Verbreitung", "Kosten", "Lernkosten"}
    if last in blacklist:
        return None
    if len(last) < 3 or len(last) > NAME_MAX_LEN:
        return None
    return last


def extract_field(pattern: re.Pattern[str], body: str) -> str:
    match = pattern.search(body)
    if not match:
        return ""
    value = match.group(1)
    value = re.sub(r"\s+", " ", value).strip()
    # Entferne dangling leading markers
    return value[:400]


def main() -> int:
    PROPOSALS_DIR.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(db_path())
    cur = con.execute(
        """
        SELECT c.id, s.title, s.category, c.page_start, c.text
        FROM chunks c JOIN sources s ON s.id=c.source_id
        WHERE c.text LIKE '%Voraussetzung%'
          AND c.text LIKE '%Verbreitung%'
          AND (c.text LIKE '%Kosten:%' OR c.text LIKE '%Lernkosten:%')
        ORDER BY s.title, c.page_start
        """
    )

    existing_by_section: dict[str, set[str]] = {
        section: load_existing_names(filename)
        for section, filename in EXISTING_SECTIONS.items()
    }

    proposals: dict[str, "OrderedDict[str, dict]"] = {
        section: OrderedDict() for section in EXISTING_SECTIONS
    }

    processed_chunks = 0
    total_candidates = 0
    for chunk_id, book, category, page_start, text in cur:
        processed_chunks += 1
        section = SECTION_BY_BOOK.get(book)
        if category == "hausregeln":
            # Fuer Hausregeln haben wir keine sichere Sektion - Freitext-Dump
            section = "hausregeln"
        if section is None:
            continue

        for name, body in split_entries(text):
            total_candidates += 1
            norm = normalize_name(name)
            if section != "hausregeln" and norm in existing_by_section.get(section, set()):
                continue
            if section not in proposals:
                proposals[section] = OrderedDict()
            if norm in proposals[section]:
                continue
            proposals[section][norm] = {
                "name": name,
                "voraussetzungen": extract_field(RE_VORAUS, body),
                "verbreitung": extract_field(RE_VERBREITUNG, body),
                "kosten": extract_field(RE_KOSTEN, body),
                "body": re.sub(r"\s+", " ", body)[:1200],
                "source_book": book,
                "source_category": category,
                "page": page_start,
                "chunk_id": chunk_id,
            }

    for section, candidates in proposals.items():
        out_dir = PROPOSALS_DIR / section
        out_dir.mkdir(parents=True, exist_ok=True)
        out = out_dir / "proposals.json"
        out.write_text(
            json.dumps(list(candidates.values()), ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        print(f"{section}: {len(candidates)} candidates -> {out.relative_to(REPO_ROOT)}")

    print(
        f"Gesamt: {processed_chunks} Chunks verarbeitet, {total_candidates} Roh-Kandidaten gefunden."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
