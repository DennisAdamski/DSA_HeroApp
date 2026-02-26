# Catalog Import Workflow

This project now uses a split JSON catalog with a manifest as runtime source.

## Canonical runtime structure

- `assets/catalogs/house_rules_v1/manifest.json`
- `assets/catalogs/house_rules_v1/talente.json`
- `assets/catalogs/house_rules_v1/waffentalente.json`
- `assets/catalogs/house_rules_v1/waffen.json`
- `assets/catalogs/house_rules_v1/magie.json`

## Maintenance workflow (manual JSON)

1. Edit the JSON files directly.
2. Keep IDs stable whenever possible to avoid breaking persisted references.
3. Run checks:

```bash
flutter analyze
flutter test
```

## Split rules

- `talente.json`:
  - Contains non-combat talents only.
  - Must not contain entries with `group = "Kampftalent"`.
- `waffentalente.json`:
  - Contains combat talents only.
  - Every entry must have `group = "Kampftalent"`.
- `waffen.json`:
  - Contains weapon catalog entries.
- `magie.json`:
  - Contains spells only.

## Loader validation behavior

The catalog loader validates the split structure at runtime:

- Each section file must be a JSON array.
- Invalid combat split (`group`) throws `FormatException`.
- Duplicate IDs in each domain (`talents`, `spells`, `weapons`) throw `FormatException`.

## Legacy note (Excel converter)

The old Excel converter script is still present as legacy:

- `tool/convert_excel_to_catalog.py`

It is no longer the primary maintenance path for `house_rules_v1`.

## Optional migration helper

For one-time or repeatable monolith-to-split migrations:

```bash
python tool/split_house_rules_catalog.py \
  --input path/to/house_rules_v1.json \
  --output-dir assets/catalogs/house_rules_v1 \
  --version house_rules_v1
```
