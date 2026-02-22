# Catalog Import Workflow

This project uses JSON as runtime source for talents, spells, and weapons.

## Canonical runtime file

- `assets/catalogs/house_rules_v1.json`

## Source files

- `ListeTalente.xlsx`
- `ListeWaffenUndTalente.xlsx`
- `ListeZaubersprueche.xlsx`

## Update workflow

1. Edit the source workbooks.
2. Run converter:

```bash
python tool/convert_excel_to_catalog.py \
  --talents "ListeTalente.xlsx" \
  --weapons "ListeWaffenUndTalente.xlsx" \
  --spells "ListeZaubersprueche.xlsx" \
  --output assets/catalogs/house_rules_v1.json \
  --version house_rules_v1
```

3. Run checks:

```bash
flutter analyze
flutter test
```

## Notes

- The converter reads sheet rows and Excel table ranges (for `ListeWaffenUndTalente.xlsx`).
- Important columns are mapped to dedicated fields:
  - `Waffengattung` -> `weaponCategory`
  - `Verfuegbarkeit` -> `availability`
- Keep stable `id` values where possible to avoid breaking persisted references.
- Use `active: false` for deprecations instead of deleting entries.
