import argparse
import json
import re
from dataclasses import dataclass
from difflib import SequenceMatcher
from pathlib import Path

from pypdf import PdfReader

_FOOTER = 'Adrian Drechsel (order #7936765)'
_TOC_PAGES = (302, 303, 304, 305)
_ATTRIBUTE_CODES = {
    'mut': 'mu',
    'klugheit': 'kl',
    'intuition': 'in',
    'charisma': 'ch',
    'fingerfertigkeit': 'ff',
    'gewandheit': 'ge',
    'konstitution': 'ko',
    'koerperkraft': 'kk',
    'körperkraft': 'kk',
}
_FIELD_LABELS = {
    'Kosten:': 'aspCost',
    'Zielobjekt:': 'targetObject',
    'Reichweite:': 'range',
    'Wirkungsdauer:': 'duration',
    'Zauberdauer:': 'castingTime',
    'Wirkung:': 'wirkung',
    'Modifikationen:': 'modifications',
    'Modifikationen und Varianten:': 'modifications',
}
_SECTION_END_LABELS = (
    'Reversalis:',
    'Antimagie:',
    'Merkmale:',
    'Komplexität:',
    'Komplexitaet:',
    'Repräsentationen und Verbreitung:',
    'Repräsentationen:',
    'Repräsentation und Verbreitung:',
)
_OCR_PHRASE_REPLACEMENTS = (
    ('Modifik ationen und Varianten:', 'Modifikationen und Varianten:'),
    ('R eversalis:', 'Reversalis:'),
    ('A ntimagie:', 'Antimagie:'),
    ('M erkmale:', 'Merkmale:'),
    ('K omplexität:', 'Komplexität:'),
    ('K omplexitaet:', 'Komplexitaet:'),
    ('W irkung:', 'Wirkung:'),
    ('K osten:', 'Kosten:'),
    ('Z auberdauer:', 'Zauberdauer:'),
    ('Z ielobjekt:', 'Zielobjekt:'),
    ('R eichweite:', 'Reichweite:'),
    ('W irkungsdauer:', 'Wirkungsdauer:'),
    ('M odifikationen:', 'Modifikationen:'),
    ('V arianten:', 'Varianten:'),
    ('T ier', 'Tier'),
    ('T iere', 'Tiere'),
    ('T ieres', 'Tieres'),
    ('V erstandeskraft', 'Verstandeskraft'),
    ('Verstandesfunk tionen', 'Verstandesfunktionen'),
    ('W ahrnehmung', 'Wahrnehmung'),
    ('wer den', 'werden'),
    ('wir d', 'wird'),
    ('ver nichtet', 'vernichtet'),
    ('verlor en', 'verloren'),
    ('be sonders', 'besonders'),
    ('be finden', 'befinden'),
    ('beob achtet', 'beobachtet'),
    ('e indringen', 'eindringen'),
    ('fr emden', 'fremden'),
    ('Spielr unde', 'Spielrunde'),
    ('Spielr unden', 'Spielrunden'),
    ('K ampfrunde', 'Kampfrunde'),
    ('K ampfrunden', 'Kampfrunden'),
    ('währ end', 'während'),
    ('Ak tion', 'Aktion'),
    ('Währ end', 'Während'),
    ('Waehr end', 'Waehrend'),
    ('erfor dert', 'erfordert'),
    ('hör en', 'hören'),
    ('mehr ere', 'mehrere'),
    ('Astralener gie', 'Astralenergie'),
    ('Beschwör ungs', 'Beschwörungs'),
    ('entspr echenden', 'entsprechenden'),
    ('Zauber nde', 'Zaubernde'),
    ('Zauber nden', 'Zaubernden'),
    ('beziehunsweise', 'beziehungsweise'),
    ('Augen blick', 'Augenblick'),
    ('wur de', 'wurde'),
    ('Sonnen aufgang', 'Sonnenaufgang'),
    ('Waffenund', 'Waffen- und'),
    ('Druidenoder', 'Druiden- oder'),
    ('Attackeoder', 'Attacke- oder'),
    ('Heiloder', 'Heil- oder'),
    ('Hitzeund', 'Hitze- und'),
    ('Kugeloder', 'Kugel- oder'),
    ('K osten', 'Kosten'),
    ('R eversalis', 'Reversalis'),
    ('W irkung', 'Wirkung'),
    ('M odifikationen', 'Modifikationen'),
    ('V ariante', 'Variante'),
    ('V arianten', 'Varianten'),
    ('A usgang', 'Ausgang'),
    ('A uslöser', 'Auslöser'),
    ('A usloeser', 'Ausloeser'),
    ('A ttacken', 'Attacken'),
    ('Pr obe', 'Probe'),
    ('Kr eis', 'Kreis'),
    ('Zauber wirker', 'Zauberwirker'),
    ('Zauber wir kung', 'Zauberwirkung'),
    ('Zauber er', 'Zauber'),
    ('ander en', 'anderen'),
    ('ande r e', 'andere'),
    ('da raufhin', 'daraufhin'),
    ('per manent', 'permanent'),
    ('ge schuppte', 'geschuppte'),
    ('dir ekte', 'direkte'),
    ('ein dringen', 'eindringen'),
    ('be spricht', 'bespricht'),
    ('insbesonder e', 'insbesondere'),
    ('insbesonder ealle', 'insbesondere alle'),
    ('insbesonderealle', 'insbesondere alle'),
    ('ueberg angslos', 'uebergangslos'),
    ('über gangslos', 'übergangslos'),
    ('eventu elle', 'eventuelle'),
    ('Schadenswirk ung', 'Schadenswirkung'),
    ('Herbeir ufung', 'Herbeirufung'),
    ('Eisund', 'Eis- und'),
    ('Hautund', 'Haut- und'),
    ('gefor mte', 'geformte'),
    ('Nebel feld', 'Nebelfeld'),
    ('pr o', 'pro'),
    ('Höhen unterschied', 'Höhenunterschied'),
    ('hoehen unterschied', 'hoehenunterschied'),
    ('wür de', 'würde'),
    ('har monisieren', 'harmonisieren'),
    ('Har monie', 'Harmonie'),
    ('Mor dauftrag', 'Mordauftrag'),
    ('Kaska dier ung', 'Kaskadierung'),
    ('Zauberzeugt', 'Zauber erzeugt'),
    ('Reitund', 'Reit- und'),
    ('hier für', 'hierfür'),
    ('hier fÃ¼r', 'hierfÃ¼r'),
    ('hinaufbzw.', 'hinauf bzw.'),
    ('kletter n', 'klettern'),
    ('veranker n', 'verankern'),
    ('Opfer ’', 'Opfer’'),
    ('Opfer â€™', 'Opferâ€™'),
    ('AsP .', 'AsP.'),
    (
        'Akti160 LEIB DES ERZES E Form Elementar (Erz) on',
        'Aktion',
    ),
)


@dataclass(frozen=True)
class TocEntry:
    printed_page: int
    raw_name: str
    probe: str
    complexity: str


@dataclass(frozen=True)
class SpellBlock:
    toc: TocEntry
    pdf_start_page: int
    pdf_end_page: int
    title: str
    probe: str
    text: str


def _normalize_name(value: str) -> str:
    text = value.lower()
    replacements = {
        'ä': 'ae',
        'ö': 'oe',
        'ü': 'ue',
        'ß': 'ss',
        '’': "'",
        '‘': "'",
    }
    for source, target in replacements.items():
        text = text.replace(source, target)
    text = text.replace('eigensch.', 'eigenschaft')
    previous = None
    while previous != text:
        previous = text
        text = re.sub(r'\b([a-z])\s+([a-z]+)\b', r'\1\2', text)
        text = re.sub(r'\b([a-z]+)\s+([a-z])\b', r'\1\2', text)
    text = re.sub(r'^(?:[a-z]\s+)+(?=[a-z]{2,})', '', text)
    text = re.sub(r'\b[a-z]\b\s+(?=[a-z])', '', text)
    text = re.sub(r'[^a-z0-9]+', ' ', text)
    return re.sub(r'\s+', ' ', text).strip()


def _normalize_probe(value: str) -> str:
    text = value.lower()
    replacements = {
        'ä': 'ae',
        'ö': 'oe',
        'ü': 'ue',
        'ß': 'ss',
    }
    for source, target in replacements.items():
        text = text.replace(source, target)
    text = re.sub(r'\s+', '', text)
    return text.replace('iin', 'in')


def _catalog_probe_key(attributes: list[str]) -> str:
    codes = []
    for entry in attributes:
        normalized = _normalize_name(entry)
        codes.append(_ATTRIBUTE_CODES.get(normalized, normalized))
    return '/'.join(codes)


def _strip_subtitle(name: str) -> str:
    tokens = _normalize_name(name).split()
    return tokens[0] if tokens else ''


def _candidate_name_options(value: str) -> list[str]:
    primary = _normalize_name(value)
    options = []
    for candidate in (primary, primary.replace(' ', '')):
        normalized = candidate.strip()
        if not normalized:
            continue
        options.append(normalized)
        if len(normalized) >= 3 and normalized[0] == normalized[1]:
            options.append(normalized[1:])
    seen = set()
    ordered = []
    for option in options:
        if option in seen:
            continue
        seen.add(option)
        ordered.append(option)
    return ordered


def _is_upper_title_line(line: str) -> bool:
    letters = [char for char in line if char.isalpha()]
    return bool(letters) and all(not char.islower() for char in letters)


def _apply_phrase_replacements(text: str) -> str:
    updated = text
    for source, target in _OCR_PHRASE_REPLACEMENTS:
        updated = updated.replace(source, target)
    return updated


def _cleanup_ocr_text(text: str, *, preserve_newlines: bool) -> str:
    updated = text
    previous = None
    while previous != updated:
        previous = updated
        updated = re.sub(r'(?<=\w)\s*-\s+(?=\w)', '', updated)
        updated = re.sub(
            r'\b([A-Za-zÄÖÜäöüß])\s+(?=[a-zäöüß]{2,}\b)',
            r'\1',
            updated,
        )
        updated = _apply_phrase_replacements(updated)
    if not preserve_newlines:
        updated = re.sub(r'[ \t]+', ' ', updated)
    return updated


def _extract_page_title(page_text: str) -> str:
    lines = [
        line.strip()
        for line in page_text.splitlines()
        if line.strip() and _FOOTER not in line
    ]
    complexity_index = None
    for index in range(len(lines) - 1, -1, -1):
        if re.fullmatch(r'[A-F]', lines[index]):
            complexity_index = index
            break
    if complexity_index is None:
        return ''

    cursor = complexity_index - 1
    if cursor >= 0 and re.fullmatch(r'\d{1,3}', lines[cursor]):
        cursor -= 1

    title_parts = []
    while cursor >= 0 and _is_upper_title_line(lines[cursor]):
        title_parts.append(lines[cursor])
        cursor -= 1
    title_parts.reverse()
    return ' '.join(title_parts).strip()


def _clean_block_text(text: str) -> str:
    cleaned = text.replace(_FOOTER, '')
    cleaned = re.sub(r'(\w)-\s*\n\s*(\w)', r'\1\2', cleaned)
    cleaned = re.sub(r'\n+', '\n', cleaned)
    cleaned = _cleanup_ocr_text(cleaned, preserve_newlines=True)
    return cleaned.strip()


def _extract_field(text: str, label: str) -> str:
    escaped = re.escape(label)
    following = [re.escape(entry) for entry in _FIELD_LABELS if entry != label]
    following.extend(re.escape(entry) for entry in _SECTION_END_LABELS)
    pattern = re.compile(
        escaped + r'\s*(.*?)\s*(?=' + '|'.join(following) + r'|\Z)',
        re.DOTALL,
    )
    match = pattern.search(text)
    if match is None:
        return ''
    return _compact_text(match.group(1))


def _compact_text(value: str) -> str:
    text = value.replace('\r', '\n')
    text = re.sub(r'(\w)-\s*\n\s*(\w)', r'\1\2', text)
    text = re.sub(r'\s*\n\s*', ' ', text)
    text = _cleanup_ocr_text(text, preserve_newlines=False)
    text = re.sub(r'[ \t]+', ' ', text)
    return text.strip()


def _split_modifications_and_variants(value: str) -> tuple[str, list[str]]:
    if not value:
        return '', []

    pieces = re.split(r'\s*◆\s*|\s*â—†\s*', value)
    modifications = _compact_text(pieces[0])
    variants = [_compact_text(piece) for piece in pieces[1:] if _compact_text(piece)]
    return modifications, variants


def _repair_inline_modifications(parsed: dict[str, object]) -> None:
    duration = str(parsed['duration'])
    if str(parsed['modifications']).strip():
        return
    for label in ('Modifikationen und Varianten:', 'Modifikationen:'):
        if label not in duration:
            continue
        duration_text, raw_modifications = duration.split(label, 1)
        parsed['duration'] = duration_text.strip()
        parsed['modifications'] = raw_modifications.strip()
        return


def _parse_spell_fields(text: str) -> dict[str, object]:
    normalized_text = _cleanup_ocr_text(text, preserve_newlines=True)
    parsed = {target: '' for target in _FIELD_LABELS.values()}
    for label, target in _FIELD_LABELS.items():
        if parsed[target]:
            continue
        parsed[target] = _extract_field(normalized_text, label)
    _repair_inline_modifications(parsed)
    modifications, variants = _split_modifications_and_variants(
        str(parsed['modifications']),
    )
    parsed['modifications'] = modifications
    parsed['variants'] = variants
    return parsed


def _build_source_reference(block: SpellBlock) -> str:
    return f'Liber Cantiones S. {block.toc.printed_page}'


def _parse_toc_entries(reader: PdfReader) -> list[TocEntry]:
    toc_text = ' '.join(
        (reader.pages[page - 1].extract_text() or '')
        for page in _TOC_PAGES
    )
    toc_text = toc_text.replace(_FOOTER, ' ')
    toc_text = toc_text.replace('ANHANG 2', ' ')
    toc_text = toc_text.replace('ZAUBERSPRUCH-', ' ')
    toc_text = toc_text.replace('ÜBERSICHT', ' ')
    toc_text = re.sub(r'\b30[1-4]\b', ' ', toc_text)
    toc_text = re.sub(r'(\w)-\s+(\w)', r'\1\2', toc_text)
    toc_text = re.sub(
        r'\b([A-Za-zÄÖÜäöüß])\s+([A-Za-zÄÖÜäöüß])\b',
        r'\1\2',
        toc_text,
    )
    toc_text = _cleanup_ocr_text(toc_text, preserve_newlines=False)
    toc_text = re.sub(r'\s+', ' ', toc_text)

    tokens = toc_text.split(' ')
    chunks: list[tuple[int, str]] = []
    current: list[str] = []
    for token in tokens:
        if re.fullmatch(r'\d{1,3}', token) and 11 <= int(token) <= 298:
            chunks.append((int(token), ' '.join(current).strip()))
            current = []
            continue
        if token:
            current.append(token)

    probe_pattern = re.compile(
        r'(?P<name>.*)\s+'
        r'(?P<probe>[A-Za-zÄÖÜäöüß]+/[A-Za-zÄÖÜäöüß]+/[A-Za-zÄÖÜäöüß]+'
        r'(?:\s*\+\s*[A-Za-zÄÖÜäöüß]+)?)\s+'
        r'(?P<complexity>[A-F])$',
    )

    entries = []
    for printed_page, chunk in chunks:
        match = probe_pattern.search(chunk)
        if match is None:
            continue
        entries.append(
            TocEntry(
                printed_page=printed_page,
                raw_name=match.group('name').strip(),
                probe=_normalize_probe(match.group('probe').split('+')[0]),
                complexity=match.group('complexity'),
            ),
        )
    return entries


def _build_spell_blocks(reader: PdfReader) -> list[SpellBlock]:
    toc_entries = _parse_toc_entries(reader)
    blocks = []
    for index, entry in enumerate(toc_entries):
        pdf_start_page = entry.printed_page + 1
        if index + 1 < len(toc_entries):
            pdf_end_page = toc_entries[index + 1].printed_page
        else:
            pdf_end_page = pdf_start_page

        raw_pages = []
        titles = []
        for page_no in range(pdf_start_page, pdf_end_page + 1):
            page_text = reader.pages[page_no - 1].extract_text() or ''
            raw_pages.append(page_text)
            title = _extract_page_title(page_text)
            if title:
                titles.append(title)

        title = titles[0] if titles else ''
        blocks.append(
            SpellBlock(
                toc=entry,
                pdf_start_page=pdf_start_page,
                pdf_end_page=pdf_end_page,
                title=title,
                probe=entry.probe,
                text=_clean_block_text('\n'.join(raw_pages)),
            ),
        )
    return blocks


def _build_catalog_indexes(spells: list[dict]) -> dict[str, object]:
    by_name: dict[str, dict] = {}
    by_base_name: dict[str, list[dict]] = {}
    by_prefix_probe: dict[tuple[str, str], list[dict]] = {}
    by_probe: dict[str, list[dict]] = {}

    for spell in spells:
        normalized_name = _normalize_name(spell.get('name', ''))
        if normalized_name:
            by_name[normalized_name] = spell

        normalized_probe = _catalog_probe_key(spell.get('attributes', []))
        by_probe.setdefault(normalized_probe, []).append(spell)

        tokens = normalized_name.split()
        base_name = _strip_subtitle(spell.get('name', ''))
        if base_name:
            by_base_name.setdefault(base_name, []).append(spell)

        for length in range(1, len(tokens) + 1):
            prefix = ' '.join(tokens[:length])
            by_prefix_probe.setdefault((prefix, normalized_probe), []).append(spell)

    return {
        'by_name': by_name,
        'by_base_name': by_base_name,
        'by_prefix_probe': by_prefix_probe,
        'by_probe': by_probe,
    }


def _fuzzy_match(
    candidate_name: str,
    probe: str,
    by_probe: dict[str, list[dict]],
) -> dict | None:
    candidates = by_probe.get(probe, [])
    if not candidates:
        return None

    suffixes = []
    for option in _candidate_name_options(candidate_name):
        if ' ' in option:
            suffixes.extend(
                ' '.join(option.split()[index:])
                for index in range(len(option.split()))
            )
        suffixes.append(option)
    suffixes = [entry for entry in suffixes if entry]

    scored = []
    for spell in candidates:
        normalized_spell = _normalize_name(spell.get('name', ''))
        best_score = 0.0
        for suffix in suffixes:
            score = SequenceMatcher(None, suffix, normalized_spell).ratio()
            if score > best_score:
                best_score = score
        scored.append((best_score, spell))

    scored.sort(key=lambda entry: entry[0], reverse=True)
    if not scored or scored[0][0] < 0.72:
        return None
    if len(scored) > 1 and scored[0][0] - scored[1][0] < 0.08:
        return None
    return scored[0][1]


def _match_spell(
    block: SpellBlock,
    indexes: dict[str, object],
) -> tuple[dict | None, str]:
    by_name = indexes['by_name']
    by_base_name = indexes['by_base_name']
    by_prefix_probe = indexes['by_prefix_probe']
    by_probe = indexes['by_probe']

    candidate_names = [block.title, block.toc.raw_name]
    for candidate in candidate_names:
        for normalized_candidate in _candidate_name_options(candidate):
            exact = by_name.get(normalized_candidate)
            if exact is not None:
                return exact, 'exact_name'

            base_matches = by_base_name.get(normalized_candidate, [])
            if len(base_matches) == 1:
                return base_matches[0], 'stripped_subtitle'

            if ' ' in normalized_candidate:
                tokens = normalized_candidate.split()
                suffixes = [' '.join(tokens[start:]) for start in range(len(tokens))]
            else:
                suffixes = [normalized_candidate]

            for suffix in suffixes:
                prefix_matches = by_prefix_probe.get((suffix, block.probe), [])
                if len(prefix_matches) == 1:
                    return prefix_matches[0], 'prefix_with_probe'

        fuzzy = _fuzzy_match(candidate, block.probe, by_probe)
        if fuzzy is not None:
            return fuzzy, 'fuzzy_with_probe'

    return None, 'unmatched'


def _review_entry(
    *,
    block: SpellBlock | None,
    reason: str,
    catalog_spell: dict | None = None,
    parsed_fields: dict[str, object] | None = None,
) -> dict[str, object]:
    entry = {
        'reason': reason,
    }
    if catalog_spell is not None:
        entry['catalogName'] = catalog_spell.get('name', '')
        entry['catalogId'] = catalog_spell.get('id', '')
        entry['catalogProbe'] = catalog_spell.get('attributes', [])
    if block is not None:
        entry['printedPage'] = block.toc.printed_page
        entry['pdfPageStart'] = block.pdf_start_page
        entry['pdfPageEnd'] = block.pdf_end_page
        entry['rawName'] = block.toc.raw_name
        entry['title'] = block.title
        entry['probe'] = block.probe
        entry['rawText'] = block.text
    if parsed_fields is not None:
        entry['parsedFields'] = parsed_fields
    return entry


def _cleanup_catalog_spell_texts(spell: dict[str, object]) -> None:
    for key in (
        'aspCost',
        'targetObject',
        'range',
        'duration',
        'castingTime',
        'wirkung',
        'modifications',
        'source',
    ):
        raw_value = str(spell.get(key, '') or '')
        spell[key] = _compact_text(raw_value) if raw_value else ''

    raw_variants = spell.get('variants', [])
    if not isinstance(raw_variants, list):
        spell['variants'] = []
        return
    spell['variants'] = [
        _compact_text(str(entry))
        for entry in raw_variants
        if _compact_text(str(entry))
    ]


def import_liber_cantiones(
    *,
    pdf_path: Path,
    catalog_path: Path,
    review_path: Path,
) -> dict[str, int]:
    reader = PdfReader(str(pdf_path))
    catalog = json.loads(catalog_path.read_text(encoding='utf-8-sig'))
    if not isinstance(catalog, list):
        raise SystemExit(f'Expected spell catalog array in {catalog_path}')

    blocks = _build_spell_blocks(reader)
    indexes = _build_catalog_indexes(catalog)

    matched_ids = set()
    review_entries: list[dict[str, object]] = []

    for spell in catalog:
        spell.setdefault('targetObject', '')
        spell.setdefault('wirkung', '')
        spell.setdefault('variants', [])
        spell.setdefault('modifications', '')
        spell.setdefault('source', '')

    for block in blocks:
        parsed_fields = _parse_spell_fields(block.text)
        spell, match_reason = _match_spell(block, indexes)
        if spell is None:
            review_entries.append(
                _review_entry(
                    block=block,
                    reason=match_reason,
                    parsed_fields=parsed_fields,
                ),
            )
            continue

        spell_id = str(spell.get('id', ''))
        if spell_id in matched_ids:
            review_entries.append(
                _review_entry(
                    block=block,
                    reason='duplicate_match',
                    catalog_spell=spell,
                    parsed_fields=parsed_fields,
                ),
            )
            continue

        matched_ids.add(spell_id)
        spell['aspCost'] = str(parsed_fields['aspCost'])
        spell['targetObject'] = str(parsed_fields['targetObject'])
        spell['range'] = str(parsed_fields['range'])
        spell['duration'] = str(parsed_fields['duration'])
        spell['castingTime'] = str(parsed_fields['castingTime'])
        spell['wirkung'] = str(parsed_fields['wirkung'])
        spell['modifications'] = str(parsed_fields['modifications'])
        spell['variants'] = list(parsed_fields['variants'])
        spell['source'] = _build_source_reference(block)

    for spell in catalog:
        if str(spell.get('id', '')) in matched_ids:
            continue
        review_entries.append(
            _review_entry(
                block=None,
                reason='catalog_spell_missing_in_pdf_or_unmatched',
                catalog_spell=spell,
            ),
        )

    for spell in catalog:
        _cleanup_catalog_spell_texts(spell)

    catalog_path.write_text(
        json.dumps(catalog, indent=4, ensure_ascii=False) + '\n',
        encoding='utf-8',
    )
    review_path.parent.mkdir(parents=True, exist_ok=True)
    review_path.write_text(
        json.dumps(review_entries, indent=2, ensure_ascii=False) + '\n',
        encoding='utf-8',
    )

    return {
        'catalog_spells': len(catalog),
        'parsed_blocks': len(blocks),
        'matched_spells': len(matched_ids),
        'review_entries': len(review_entries),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description='Import Liber Cantiones spell details into magie.json.',
    )
    parser.add_argument('--pdf', required=True, help='Path to Liber Cantiones PDF.')
    parser.add_argument(
        '--catalog',
        default='assets/catalogs/house_rules_v1/magie.json',
        help='Path to the target spell catalog JSON.',
    )
    parser.add_argument(
        '--review',
        default='tool/generated/liber_cantiones_missing_spells.json',
        help='Path to the review JSON for unmatched spells.',
    )
    args = parser.parse_args()

    result = import_liber_cantiones(
        pdf_path=Path(args.pdf),
        catalog_path=Path(args.catalog),
        review_path=Path(args.review),
    )
    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    main()
