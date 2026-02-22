import argparse
import json
import re
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

NS = {
    'm': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main',
    'p': 'http://schemas.openxmlformats.org/package/2006/relationships',
    'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
}


def _normalize_text(value):
    if value is None:
        return ''
    text = str(value)
    text = text.replace('\r\n', '\n').replace('\r', '\n')
    text = text.strip()
    return text


def _normalize_header(value):
    text = _normalize_text(value).lower()
    repl = {
        chr(228): 'ae',
        chr(246): 'oe',
        chr(252): 'ue',
        chr(223): 'ss',
        ':': '',
        '.': '',
        '/': '_',
        '-': '_',
    }
    for src, dst in repl.items():
        text = text.replace(src, dst)
    text = re.sub(r'[^a-z0-9]+', '_', text)
    text = re.sub(r'_+', '_', text).strip('_')
    return text


def _slugify(value):
    text = _normalize_header(value)
    return text or 'entry'


def _split_csv(value):
    text = _normalize_text(value)
    if not text:
        return []
    raw = re.split(r',|\n', text)
    items = []
    for item in raw:
        clean = item.strip()
        if clean:
            items.append(clean)
    return items


def _col_to_index(col):
    result = 0
    for ch in col:
        result = result * 26 + (ord(ch) - 64)
    return result


def _parse_ref(ref):
    match = re.match(r'([A-Z]+)(\d+)', ref)
    if not match:
        raise ValueError(f'Invalid cell reference: {ref}')
    return _col_to_index(match.group(1)), int(match.group(2))


def _parse_range(ref):
    start, end = ref.split(':', 1)
    c1, r1 = _parse_ref(start)
    c2, r2 = _parse_ref(end)
    return c1, r1, c2, r2


class WorkbookData:
    def __init__(self, path):
        self.path = Path(path)
        self.shared_strings = []
        self.sheets = {}
        self._load()

    def _load(self):
        with zipfile.ZipFile(self.path) as zf:
            if 'xl/sharedStrings.xml' in zf.namelist():
                sroot = ET.fromstring(zf.read('xl/sharedStrings.xml'))
                for item in sroot.findall('m:si', NS):
                    parts = [node.text or '' for node in item.findall('.//m:t', NS)]
                    self.shared_strings.append(''.join(parts))

            wb = ET.fromstring(zf.read('xl/workbook.xml'))
            rels = ET.fromstring(zf.read('xl/_rels/workbook.xml.rels'))
            rel_map = {entry.attrib['Id']: entry.attrib['Target'] for entry in rels.findall('p:Relationship', NS)}

            for sheet in wb.find('m:sheets', NS).findall('m:sheet', NS):
                name = sheet.attrib['name']
                rid = sheet.attrib['{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id']
                target = rel_map[rid]
                if not target.startswith('xl/'):
                    target = f'xl/{target}'
                self.sheets[name] = self._load_sheet(zf, target)

    def _load_sheet(self, zf, sheet_path):
        root = ET.fromstring(zf.read(sheet_path))
        cells = {}
        max_row = 0
        max_col = 0

        for cell in root.findall('.//m:c', NS):
            ref = cell.attrib.get('r')
            if not ref:
                continue
            col, row = _parse_ref(ref)
            max_row = max(max_row, row)
            max_col = max(max_col, col)

            value = ''
            tpe = cell.attrib.get('t')
            v_node = cell.find('m:v', NS)
            if v_node is not None:
                if tpe == 's':
                    idx = int(v_node.text)
                    value = self.shared_strings[idx] if idx < len(self.shared_strings) else ''
                else:
                    value = v_node.text or ''
            else:
                is_node = cell.find('m:is', NS)
                if is_node is not None:
                    parts = [node.text or '' for node in is_node.findall('.//m:t', NS)]
                    value = ''.join(parts)

            value = _normalize_text(value)
            if value:
                cells[(row, col)] = value

        table_paths = []
        table_parts = root.find('m:tableParts', NS)
        if table_parts is not None and int(table_parts.attrib.get('count', '0')) > 0:
            rel_path = sheet_path.replace('xl/worksheets/', 'xl/worksheets/_rels/') + '.rels'
            rel_map = {}
            if rel_path in zf.namelist():
                rel_root = ET.fromstring(zf.read(rel_path))
                rel_map = {
                    entry.attrib['Id']: entry.attrib['Target']
                    for entry in rel_root.findall('p:Relationship', NS)
                }
            for tp in table_parts.findall('m:tablePart', NS):
                rid = tp.attrib.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id')
                target = rel_map.get(rid)
                if target:
                    if target.startswith('../'):
                        target = 'xl/' + target.replace('../', '', 1)
                    elif not target.startswith('xl/'):
                        target = 'xl/' + target
                    table_paths.append(target)

        return {
            'cells': cells,
            'max_row': max_row,
            'max_col': max_col,
            'tables': table_paths,
        }

    def sheet_rows(self, sheet_name, header_row=1):
        sheet = self.sheets[sheet_name]
        cells = sheet['cells']
        max_row = sheet['max_row']
        max_col = sheet['max_col']

        headers = {}
        for col in range(1, max_col + 1):
            raw = cells.get((header_row, col), '')
            header = _normalize_header(raw)
            if header:
                headers[col] = header

        rows = []
        for row in range(header_row + 1, max_row + 1):
            current = {}
            has_value = False
            for col, header in headers.items():
                value = cells.get((row, col), '')
                if value:
                    has_value = True
                current[header] = value
            if has_value:
                rows.append(current)
        return rows

    def sheet_table_rows(self, sheet_name):
        sheet = self.sheets[sheet_name]
        cells = sheet['cells']
        rows_by_table = []

        with zipfile.ZipFile(self.path) as zf:
            for table_path in sheet['tables']:
                if table_path not in zf.namelist():
                    continue
                troot = ET.fromstring(zf.read(table_path))
                ref = troot.attrib.get('ref')
                tname = troot.attrib.get('displayName') or troot.attrib.get('name') or 'table'
                if not ref:
                    continue
                c1, r1, c2, r2 = _parse_range(ref)
                headers = [
                    _normalize_header(entry.attrib.get('name', ''))
                    for entry in troot.find('m:tableColumns', NS).findall('m:tableColumn', NS)
                ]

                entries = []
                for row in range(r1 + 1, r2 + 1):
                    current = {}
                    has_value = False
                    for idx, col in enumerate(range(c1, c2 + 1)):
                        header = headers[idx] if idx < len(headers) else f'col_{idx + 1}'
                        value = cells.get((row, col), '')
                        if value:
                            has_value = True
                        current[header] = value
                    if has_value:
                        entries.append(current)

                rows_by_table.append((tname, entries))

        return rows_by_table


def _unique_id(prefix, name, used):
    base = f'{prefix}_{_slugify(name)}'
    candidate = base
    index = 2
    while candidate in used:
        candidate = f'{base}_{index}'
        index += 1
    used.add(candidate)
    return candidate


def build_catalog(talents_file, weapons_file, spells_file, version):
    talents_book = WorkbookData(talents_file)
    weapons_book = WorkbookData(weapons_file)
    spells_book = WorkbookData(spells_file)

    used_ids = set()
    talents = []
    spells = []
    weapons = []

    for row in talents_book.sheet_rows('Tabelle1', header_row=1):
        name = row.get('name', '')
        if not name:
            continue
        attributes = [
            row.get('eigenschaft_1', ''),
            row.get('eigenschaft_2', ''),
            row.get('eigenschaft_3', ''),
        ]
        attributes = [entry for entry in attributes if entry]

        talents.append(
            {
                'id': _unique_id('tal', name, used_ids),
                'name': name,
                'group': row.get('typ', ''),
                'steigerung': row.get('komplexitaet', ''),
                'attributes': attributes,
                'type': row.get('typ', ''),
                'be': row.get('be', ''),
                'weaponCategory': '',
                'alternatives': '',
                'source': 'ListeTalente.xlsx:Tabelle1',
                'description': '',
                'active': True,
            }
        )

    combat_talent_meta = {}
    weapon_rows = []
    for tname, entries in weapons_book.sheet_table_rows('Waffen'):
        for row in entries:
            if 'waffe' in row and 'talent' in row:
                weapon_rows.append(row)

    for tname, entries in weapons_book.sheet_table_rows('Kampftalente'):
        for row in entries:
            name = row.get('nahkampf', '')
            if not name:
                continue
            combat_talent_meta[name] = row
            talents.append(
                {
                    'id': _unique_id('tal', name, used_ids),
                    'name': name,
                    'group': 'Kampftalent',
                    'steigerung': row.get('komp', ''),
                    'attributes': [],
                    'type': row.get('typ', ''),
                    'be': row.get('be', ''),
                    'weaponCategory': row.get('waffengattung', ''),
                    'alternatives': row.get('ersatzweise', ''),
                    'source': 'ListeWaffenUndTalente.xlsx:Kampftalente',
                    'description': '',
                    'active': True,
                }
            )

    for row in weapon_rows:
        name = row.get('waffe', '')
        if not name:
            continue
        talent_name = row.get('talent', '')
        meta = combat_talent_meta.get(talent_name, {})
        weapons.append(
            {
                'id': _unique_id('wpn', name, used_ids),
                'name': name,
                'type': row.get('typ', ''),
                'combatSkill': talent_name,
                'tp': '',
                'complexity': row.get('komplexitaet', ''),
                'weaponCategory': meta.get('waffengattung', ''),
                'possibleManeuvers': _split_csv(row.get('moegliche_manoever', '')),
                'activeManeuvers': _split_csv(row.get('aktivierte_manoever', '')),
                'tpkk': '',
                'iniMod': 0,
                'atMod': 0,
                'paMod': 0,
                'reach': '',
                'source': 'ListeWaffenUndTalente.xlsx:Waffen',
                'active': True,
            }
        )

    for row in spells_book.sheet_rows('Tabelle1', header_row=1):
        name = row.get('zaubername', '')
        if not name:
            continue

        attributes = [
            row.get('eigenschaft_1', ''),
            row.get('eigenschaft_2', ''),
            row.get('eigenschaft_3', ''),
        ]
        attributes = [entry for entry in attributes if entry]

        spells.append(
            {
                'id': _unique_id('spell', name, used_ids),
                'name': name,
                'tradition': '',
                'steigerung': row.get('lernkomplexitaet', ''),
                'attributes': attributes,
                'availability': row.get('verfuegbarkeit', ''),
                'traits': row.get('merkmale', ''),
                'modifier': row.get('mod', ''),
                'castingTime': row.get('zd', ''),
                'aspCost': row.get('kosten', ''),
                'range': row.get('reichweite', ''),
                'duration': row.get('wd', ''),
                'modifications': row.get('modifikationen', ''),
                'category': row.get('merkmale', ''),
                'source': 'ListeZaubersprueche.xlsx:Tabelle1',
                'active': True,
            }
        )

    return {
        'version': version,
        'source': f'{Path(talents_file).name};{Path(weapons_file).name};{Path(spells_file).name}',
        'metadata': {
            'generatedBy': 'tool/convert_excel_to_catalog.py',
            'note': 'Generated from structured list files.',
        },
        'talents': talents,
        'spells': spells,
        'weapons': weapons,
    }


def main():
    parser = argparse.ArgumentParser(description='Convert structured DSA list files to catalog JSON.')
    parser.add_argument('--talents', default='ListeTalente.xlsx')
    parser.add_argument('--weapons', default='ListeWaffenUndTalente.xlsx')
    parser.add_argument('--spells', default='ListeZaubersprueche.xlsx')
    parser.add_argument('--output', default='assets/catalogs/house_rules_v1.json')
    parser.add_argument('--version', default='house_rules_v1')
    args = parser.parse_args()

    for path in [args.talents, args.weapons, args.spells]:
        if not Path(path).exists():
            raise SystemExit(f'Input file not found: {path}')

    catalog = build_catalog(args.talents, args.weapons, args.spells, args.version)
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(catalog, indent=2, ensure_ascii=True), encoding='utf-8')
    print(f'Wrote {out}')


if __name__ == '__main__':
    main()


