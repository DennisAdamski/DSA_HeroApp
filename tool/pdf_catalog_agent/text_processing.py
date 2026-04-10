"""Textaufbereitung, Topic-Tagging und Chunking fuer PDF-Inhalte."""

from __future__ import annotations

import re
from collections import Counter


TOPIC_KEYWORDS: dict[str, tuple[str, ...]] = {
    'heldenbogen': (
        'held',
        'charakter',
        'profession',
        'rasse',
        'kultur',
        'basiswert',
        'heldenbogen',
    ),
    'eigenschaften': (
        'eigenschaft',
        'mut',
        'klugheit',
        'intuition',
        'charisma',
        'fingerfertigkeit',
        'gewandheit',
        'konstitution',
        'koerperkraft',
        'körperkraft',
    ),
    'talente': ('talent', 'probe', 'steigerung', 'fertigkeit'),
    'kampf': (
        'kampf',
        'attacke',
        'parade',
        'waffe',
        'ruestung',
        'rüstung',
        'fernkampf',
        'nahkampf',
        'initiative',
        'trefferpunkt',
        'tp',
        'at',
        'pa',
    ),
    'magie': (
        'zauber',
        'ritual',
        'magie',
        'magisch',
        'asp',
        'antimagie',
        'repräsentation',
        'repraesentation',
        'liturgie',
    ),
    'sonderfertigkeiten': (
        'sonderfertigkeit',
        'manöver',
        'manoever',
        'meisterschaft',
        'kampfstil',
        'stil',
    ),
    'inventar': (
        'inventar',
        'gegenstand',
        'ausruestung',
        'ausrüstung',
        'vorrat',
        'rucksack',
        'gewicht',
    ),
    'reisebericht': (
        'reisebericht',
        'abenteuer',
        'sondererfahrung',
        'kampferfahrung',
        'belohnung',
        'reise',
    ),
    'orte_regionen': (
        'region',
        'provinz',
        'stadt',
        'dorf',
        'reich',
        'gegend',
        'ort',
        'karte',
        'fluss',
        'gebirge',
    ),
    'weltwissen': (
        'geschichte',
        'kultur',
        'kirche',
        'akademie',
        'adel',
        'gesellschaft',
        'hintergrund',
        'chronik',
        'tempel',
    ),
    'hausregel_abweichung': (
        'hausregel',
        'abweichung',
        'stattdessen',
        'anstatt',
        'eigene regel',
        'sonderregel',
    ),
}

SOURCE_TYPE_TOPICS: dict[str, tuple[str, ...]] = {
    'hausregeln': ('hausregel_abweichung',),
    'regionalbuch': ('orte_regionen', 'weltwissen'),
    'zusatzinfo': ('weltwissen',),
}

SECTION_HINT_RE = re.compile(r'^[A-ZÄÖÜ0-9][^.!?]{2,100}$')
WORD_RE = re.compile(r'[\wÄÖÜäöüß]+', re.UNICODE)


def normalize_text(text: str) -> str:
    """Bereitet rohen PDF-Text fuer Suche und Anzeige lesbarer auf."""

    if not text:
        return ''

    flattened = text.replace('\r\n', '\n').replace('\r', '\n')
    flattened = re.sub(r'-\n(?=[a-zäöüß])', '', flattened, flags=re.IGNORECASE)
    raw_lines = [line.strip() for line in flattened.split('\n')]
    lines = [line for line in raw_lines if line]
    if not lines:
        return ''

    paragraphs: list[str] = []
    current = ''
    for line in lines:
        if current:
            if current.endswith('-'):
                current = f'{current[:-1]}{line}'
                continue
            if current.endswith(('.', '!', '?', ':', ';')):
                paragraphs.append(current)
                current = line
                continue
            if line and line[0].islower():
                current = f'{current} {line}'
                continue
            if SECTION_HINT_RE.fullmatch(line):
                paragraphs.append(current)
                current = line
                continue
            current = f'{current} {line}'
            continue
        current = line

    if current:
        paragraphs.append(current)
    return '\n\n'.join(paragraphs)


def normalize_search_text(text: str) -> str:
    """Normalisiert Text fuer keywordbasierte Vergleiche."""

    normalized = text.lower()
    replacements = {
        'ä': 'ae',
        'ö': 'oe',
        'ü': 'ue',
        'ß': 'ss',
    }
    for source, target in replacements.items():
        normalized = normalized.replace(source, target)
    return re.sub(r'\s+', ' ', normalized)


def alpha_ratio(text: str) -> float:
    """Liefert den Buchstabenanteil eines Texts als simple Qualitaetsmetrik."""

    if not text:
        return 0.0
    letters = sum(1 for character in text if character.isalpha())
    return letters / max(len(text), 1)


def guess_section_title(text: str, *, fallback: str) -> str:
    """Leitet einen lesbaren Abschnittstitel aus dem Seiteninhalt ab."""

    for line in text.splitlines():
        candidate = line.strip()
        if not candidate:
            continue
        if candidate.isdigit():
            continue
        if len(candidate) > 100:
            continue
        if SECTION_HINT_RE.fullmatch(candidate):
            return candidate
        return candidate
    return fallback


def split_into_chunks(text: str, *, max_chars: int = 1400) -> list[str]:
    """Teilt vorbereiteten Text in gut durchsuchbare, stabile Chunks auf."""

    normalized = normalize_text(text)
    if not normalized:
        return []

    paragraphs = [entry.strip() for entry in normalized.split('\n\n') if entry.strip()]
    if not paragraphs:
        return []

    chunks: list[str] = []
    current = ''
    for paragraph in paragraphs:
        candidate = paragraph if not current else f'{current}\n\n{paragraph}'
        if len(candidate) <= max_chars:
            current = candidate
            continue
        if current:
            chunks.append(current)
        current = paragraph

    if current:
        chunks.append(current)
    return chunks


def detect_topics(
    text: str,
    *,
    source_type: str,
    default_topics: tuple[str, ...],
) -> tuple[str, ...]:
    """Leitet thematische Tags aus Quelle, Defaults und Keywords ab."""

    scores: Counter[str] = Counter()
    for topic in SOURCE_TYPE_TOPICS.get(source_type, ()):
        scores[topic] += 1

    haystack = normalize_search_text(text)
    keyword_matches = 0
    for topic, keywords in TOPIC_KEYWORDS.items():
        for keyword in keywords:
            if normalize_search_text(keyword) in haystack:
                scores[topic] += 1
                keyword_matches += 1
    if keyword_matches == 0:
        for topic in default_topics:
            scores[topic] += 1
    if not scores:
        return ('weltwissen',)

    ordered = [
        topic
        for topic, score in scores.most_common()
        if score > 0
    ]
    limited = ordered[:5]
    return tuple(sorted(set(limited), key=limited.index))


def build_excerpt(text: str, *, limit: int = 220) -> str:
    """Schneidet Text fuer CLI- und JSON-Ausgaben lesbar an."""

    condensed = re.sub(r'\s+', ' ', text).strip()
    if len(condensed) <= limit:
        return condensed
    return f'{condensed[: limit - 3].rstrip()}...'


def build_fts_query(query: str) -> str:
    """Wandelt Freitext in eine robuste SQLite-FTS5-Anfrage um."""

    terms = [term for term in WORD_RE.findall(query) if len(term) >= 2]
    if not terms:
        raise ValueError('Die Suchanfrage enthaelt keine verwertbaren Suchwoerter.')
    return ' OR '.join(f'"{term}"' for term in terms)
