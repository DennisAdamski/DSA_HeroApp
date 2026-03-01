# DSA Heldenverwaltung

Flutter-App zur Verwaltung von DSA-Helden mit:
- lokaler Persistenz (Hive)
- Regeln/abgeleiteten Werten
- Import/Export von Helden als JSON
- Katalogdaten aus Excel-Quellen

## Schnellstart

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## iOS/Xcode setup (SPM-first)

Fuer iOS-Builds auf Mac mit Xcode 15+:

```bash
bash tool/ios_bootstrap_spm.sh
```

Vollstaendige Anleitung:

- `docs/ios_xcode_setup.md`

## Dateistatus (Stand: 2026-02-23)

### Runtime-relevant
- `lib/main.dart` als Einstiegspunkt
- `lib/domain/`, `lib/state/`, `lib/data/`, `lib/rules/derived/`, `lib/ui/screens/`
- `assets/catalogs/house_rules_v1/` (Split-JSON mit `manifest.json` + Teilkatalogen)

### Architektur-Notiz (Stand: 2026-03-01)
- State-Layer nutzt einen stream-basierten Heldenindex (`HeroIndexSnapshot`) fuer O(1)-Lookup je ID.
- Abgeleitete Berechnungen werden zentral ueber `HeroComputedSnapshot` gebuendelt (Modifier, effektive Attribute, Derived, Combat-Preview).
- Repository-Schnittstelle ist auf inkrementelle Streams erweitert (`watchHeroIndex`, `watchHeroState`, `loadHeroById`).

### Tooling und Datenaufbereitung
- `tool/convert_excel_to_catalog.py`: erzeugt Runtime-Katalog aus Excel-Listen
- `tool/export_rule_cells.py`: Snapshot-Helfer fuer Regelzellen
- `tool/report_unreferenced_dart.py`: Report fuer unreferenzierte `lib/*.dart`

### Derzeit nicht angebundene Dart-Dateien (bewusst behalten)
- `lib/rules/derived/combat_rules.dart`
- `lib/rules/derived/magic_rules.dart`
- `lib/rules/derived/mods_rules.dart`
- `lib/ui/screens/hero_detail_screen.dart`

Diese Dateien sind aktuell als Platzhalter/Legacy dokumentiert und werden nicht geloescht.

## Hinweis zu Excel-Lockfiles (`~$*.xlsx`)

Im Repo sind temporaere Office-Lockfiles versioniert:
- `~$Charaktersheet_DSA_mit_Hausregeln Hexe.xlsx`
- `~$ListeTalente.xlsx`
- `~$ListeWaffenUndTalente.xlsx`
- `~$ListeZaubersprueche.xlsx`

Sie sind **nicht runtime-relevant**. Aktueller Status: nur dokumentiert, kein Cleanup in diesem Schritt.

## Relevante Docs

- `docs/catalog_import_workflow.md`
- `docs/rules_mapping_house_rules_v1.md`
