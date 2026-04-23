# Catalog Import Workflow

This project uses a split JSON base catalog plus synchronizable custom catalog
files in the active hero storage.

## Canonical runtime structure

Base assets:

- `assets/catalogs/house_rules_v1/manifest.json`
- `assets/catalogs/house_rules_v1/packs/<packId>/manifest.json`
- `assets/catalogs/house_rules_v1/talente.json`
- `assets/catalogs/house_rules_v1/waffentalente.json`
- `assets/catalogs/house_rules_v1/waffen.json`
- `assets/catalogs/house_rules_v1/magie.json`
- `assets/catalogs/house_rules_v1/manoever.json`
- `assets/catalogs/house_rules_v1/kampf_sonderfertigkeiten.json`
- `assets/catalogs/house_rules_v1/sprachen.json`
- `assets/catalogs/house_rules_v1/schriften.json`

Separate runtime catalog:

- `assets/catalogs/reiseberichte/house_rules_v1/reisebericht.json`

Synchronizable custom entries in hero storage:

- `<hero-storage>/custom_catalogs/house_rules_v1/<sektion>/<id>.json`
- `<hero-storage>/house_rule_packs/house_rules_v1/<packId>/manifest.json`

Examples:

- `<hero-storage>/custom_catalogs/house_rules_v1/talente/tal_custom.json`
- `<hero-storage>/custom_catalogs/house_rules_v1/waffen/wpn_custom.json`

## Maintenance workflow

### Base catalog assets

- Base assets remain read-only at runtime.
- Their canonical source is still the split JSON structure below
  `assets/catalogs/house_rules_v1/`.
- Do not edit these files ad hoc inside feature work.
- Regenerate or maintain them through the Python tooling in `tool/`.

### Custom catalog entries

- Users create and edit custom entries inside the app via
  `Einstellungen -> Katalogverwaltung`.
- Only custom entries are editable; base entries are view-only.
- Each custom entry is stored as its own JSON file to reduce sync conflicts.
- Changes from external sync tools are picked up after app restart or
  `Katalog neu laden`.

### House rule packs

- House rule packs are loaded between the official base catalog and
  `custom_catalogs`.
- Built-in packs come from `assets/catalogs/house_rules_v1/packs/`.
- Imported packs are discovered in
  `<hero-storage>/house_rule_packs/<version>/<packId>/manifest.json`.
- Packs may override fields, add entries or deactivate entries; custom catalogs
  remain additive and must not replace IDs that are already present after pack
  resolution.
- Built-in packs may also gate base entries directly via `ruleMeta.sourceKey`
  without needing `addEntries`. This is used by
  `regelwerk_ueberarbeitung_v1` for optional maneuvers and Sonderfertigkeiten.
- Official baseline values and opt-in house-rule overlays may intentionally be
  split: for example the affected `Körperliche Talente` live officially in
  `talente.json`, while only the PDF deviations are reapplied through
  `regelwerk_ueberarbeitung_v1.talents_learning`.

## Split rules

- `talente.json`:
  - Contains non-combat talents only.
  - Must not contain entries with `group = "Kampftalent"`.
- `waffentalente.json`:
  - Contains combat talents only.
  - Every entry must have `group = "Kampftalent"`.
- `waffen.json`:
  - Contains weapon catalog entries.
  - Weapon entries may also include raw Arsenal metadata such as
    `weight`, `length`, `breakFactor`, `price`, `remarks`,
    `reloadTimeText`, `rangedDistanceBands`, and `rangedProjectiles`.
- Catalog entries for talents, weapons, spells, maneuvers, and combat special
  abilities may additionally carry optional structured `ruleMeta` data for
  origin layering (`official` vs. `house_rule`), citations, and epic opt-in
  gating.
- `magie.json`:
  - Contains spells only.
  - Spell detail fields from `Liber Cantiones.pdf` are maintained via
    `tool/import_liber_cantiones.py`.
- `reisebericht.json`:
  - Is intentionally excluded from the editable settings catalog management.
  - Remains a dedicated runtime catalog referenced through the manifest.
- `vertrautenmagie_rituale.json`:
  - Remains a separate preset/reference file and is not part of the settings
    catalog management.

## Loader validation behavior

The catalog loader validates the split structure at runtime:

- Each section file must be a JSON array.
- Invalid combat split (`group`) throws `FormatException`.
- Duplicate IDs inside each domain throw `FormatException`.
- The manifest may resolve files outside its own directory, which is used for
  the separate Reisebericht asset path.
- Missing `ruleMeta` remains valid and keeps older JSON files fully readable.

Custom catalog loading validates additional invariants:

- Each file must contain a JSON object.
- Empty IDs are rejected.
- Duplicate custom IDs in the same section are ignored and reported.
- Custom IDs that collide with base IDs are ignored and reported.
- Invalid custom files must not block the base catalog.

## Hero import/export

- `HeroTransferBundle.transferSchemaVersion` is currently `3`.
- Hero exports may embed the minimal set of referenced custom catalog entries.
- On import, embedded custom entries are written into the active hero storage
  before the hero itself is saved.

## Liber Cantiones import

Use the importer to enrich `magie.json` with:

- `source`
- `aspCost`
- `targetObject`
- `range`
- `duration`
- `castingTime`
- `wirkung`
- `modifications`
- `variants`

```bash
python tool/import_liber_cantiones.py \
  --pdf "C:/path/to/Liber Cantiones.pdf" \
  --catalog assets/catalogs/house_rules_v1/magie.json \
  --review tool/generated/liber_cantiones_missing_spells.json
```

## Tooling

```bash
python tool/convert_excel_to_catalog.py
python tool/split_house_rules_catalog.py \
  --input path/to/house_rules_v1.json \
  --output-dir assets/catalogs/house_rules_v1 \
  --version house_rules_v1
```
