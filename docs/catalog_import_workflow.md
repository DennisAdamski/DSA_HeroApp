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
  - Spell detail fields from `Liber Cantiones.pdf` are maintained via
    `tool/import_liber_cantiones.py`.

## Liber Cantiones import

Use the importer to enrich `magie.json` with:

- `source` (first Liber Cantiones spell page)
- `aspCost`
- `targetObject`
- `range`
- `duration`
- `castingTime`
- `wirkung`
- `modifications`
- `variants`

Command:

```bash
python tool/import_liber_cantiones.py \
  --pdf "C:/path/to/Liber Cantiones.pdf" \
  --catalog assets/catalogs/house_rules_v1/magie.json \
  --review tool/generated/liber_cantiones_missing_spells.json
```

Notes:

- The importer keeps all existing spell identities and base catalog fields.
- For multi-page spells, `source` stores the first printed spell page from
  `Liber Cantiones` (for example `Liber Cantiones S. 153`).
- Imported long-text fields are whitespace-normalized; PDF line breaks are
  flattened to regular spaces instead of preserving page layout.
- The importer also applies a conservative OCR cleanup pass for obvious split
  words such as `Verstandesfunk - tionen`, `T iere` or `wer den`.
- Ambiguous, unmatched, or PDF-only-reference cases are written to
  `tool/generated/liber_cantiones_missing_spells.json` for manual review.
- The script requires `pypdf` and, for AES-encrypted PDFs, `cryptography`.

## Combat talent UI note

- Combat talents remain sourced from `assets/catalogs/house_rules_v1/waffentalente.json`.
- The in-app combat talent tab mirrors the Excel `Kampftechniken` layout/validation for editing (`TaW`/`AT`/`PA` rules).
- This is UI logic only and does not require importing combat talent values from `Charaktersheet_DSA_mit_Hausregeln Hexe.xlsx`.

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
