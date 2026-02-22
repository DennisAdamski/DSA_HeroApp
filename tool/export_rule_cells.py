import json
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

WORKBOOK = Path('Charaktersheet_DSA_mit_Hausregeln Hexe.xlsx')
OUT = Path('tool/rule_cells_snapshot.json')

NS = {
    'm': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main',
    'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
    'p': 'http://schemas.openxmlformats.org/package/2006/relationships',
}

TARGETS = {
    'Eigenschaften': ['O20', 'P20', 'O21', 'P21', 'P22', 'P23', 'P24', 'P25', 'P26', 'P27'],
    'Rechner': ['C11', 'C14', 'C15'],
}


def load_snapshot() -> dict:
    with zipfile.ZipFile(WORKBOOK) as zf:
        wb = ET.fromstring(zf.read('xl/workbook.xml'))
        rels = ET.fromstring(zf.read('xl/_rels/workbook.xml.rels'))
        rel_map = {
            rel.attrib['Id']: rel.attrib['Target']
            for rel in rels.findall('p:Relationship', NS)
        }

        result = {}
        for sheet in wb.find('m:sheets', NS).findall('m:sheet', NS):
            name = sheet.attrib['name']
            if name not in TARGETS:
                continue

            rid = sheet.attrib['{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id']
            target = rel_map[rid]
            if not target.startswith('xl/'):
                target = f'xl/{target}'

            ws = ET.fromstring(zf.read(target))
            cell_map = {}
            for cell in ws.findall('.//m:c', NS):
                ref = cell.attrib.get('r')
                if ref not in TARGETS[name]:
                    continue
                formula = cell.find('m:f', NS)
                value = cell.find('m:v', NS)
                cell_map[ref] = {
                    'formula': formula.text if formula is not None else None,
                    'value': value.text if value is not None else None,
                }

            result[name] = cell_map

        return result


def main() -> None:
    snapshot = load_snapshot()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(snapshot, indent=2, ensure_ascii=True), encoding='utf-8')
    print(f'Wrote {OUT}')


if __name__ == '__main__':
    main()
