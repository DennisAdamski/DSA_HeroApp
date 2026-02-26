import argparse
import json
from pathlib import Path


def _read_json_object(path: Path) -> dict:
    raw = path.read_text(encoding='utf-8')
    data = json.loads(raw)
    if not isinstance(data, dict):
        raise SystemExit(f'Input catalog must be a JSON object: {path}')
    return data


def _write_json(path: Path, payload) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=True), encoding='utf-8')


def _validate_split(talente: list, waffentalente: list) -> None:
    for index, entry in enumerate(talente):
        group = str(entry.get('group', '')).strip()
        if group == 'Kampftalent':
            raise SystemExit(
                f'Invalid split: talente[{index}] uses group "Kampftalent".'
            )

    for index, entry in enumerate(waffentalente):
        group = str(entry.get('group', '')).strip()
        if group != 'Kampftalent':
            raise SystemExit(
                f'Invalid split: waffentalente[{index}] does not use group "Kampftalent".'
            )


def _validate_unique_ids(entries: list, domain: str) -> None:
    seen = set()
    for index, entry in enumerate(entries):
        entry_id = str(entry.get('id', '')).strip()
        if not entry_id:
            raise SystemExit(f'Invalid {domain}[{index}]: missing non-empty "id".')
        if entry_id in seen:
            raise SystemExit(f'Duplicate {domain} id: {entry_id}')
        seen.add(entry_id)


def split_catalog(input_path: Path, output_dir: Path, version: str | None) -> None:
    catalog = _read_json_object(input_path)

    talents = catalog.get('talents', [])
    spells = catalog.get('spells', [])
    weapons = catalog.get('weapons', [])
    if not isinstance(talents, list) or not isinstance(spells, list) or not isinstance(weapons, list):
        raise SystemExit('Input catalog must contain list sections: talents, spells, weapons.')

    talente = [entry for entry in talents if str(entry.get('group', '')).strip() != 'Kampftalent']
    waffentalente = [entry for entry in talents if str(entry.get('group', '')).strip() == 'Kampftalent']
    magie = list(spells)
    waffen = list(weapons)

    _validate_split(talente, waffentalente)
    _validate_unique_ids(talente + waffentalente, 'talents')
    _validate_unique_ids(magie, 'spells')
    _validate_unique_ids(waffen, 'weapons')

    target_version = version or str(catalog.get('version', 'unknown'))
    manifest = {
        'version': target_version,
        'source': str(catalog.get('source', 'unknown')),
        'metadata': catalog.get('metadata', {}),
        'files': {
            'talente': 'talente.json',
            'waffentalente': 'waffentalente.json',
            'waffen': 'waffen.json',
            'magie': 'magie.json',
        },
    }

    _write_json(output_dir / 'manifest.json', manifest)
    _write_json(output_dir / 'talente.json', talente)
    _write_json(output_dir / 'waffentalente.json', waffentalente)
    _write_json(output_dir / 'waffen.json', waffen)
    _write_json(output_dir / 'magie.json', magie)

    print(f'Wrote split catalog to {output_dir}')
    print(f'talente={len(talente)}')
    print(f'waffentalente={len(waffentalente)}')
    print(f'waffen={len(waffen)}')
    print(f'magie={len(magie)}')


def main() -> None:
    parser = argparse.ArgumentParser(description='Split monolithic house_rules catalog into section files.')
    parser.add_argument('--input', required=True, help='Path to monolithic catalog JSON file.')
    parser.add_argument('--output-dir', required=True, help='Output directory for split catalog files.')
    parser.add_argument('--version', default=None, help='Override version value in manifest.')
    args = parser.parse_args()

    split_catalog(
        input_path=Path(args.input),
        output_dir=Path(args.output_dir),
        version=args.version,
    )


if __name__ == '__main__':
    main()
