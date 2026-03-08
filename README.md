# DSA Heldenverwaltung

Flutter-App zur Verwaltung von DSA-Helden mit:
- lokaler Persistenz (Hive)
- Regeln/abgeleiteten Werten
- Import/Export von Helden als JSON
- Katalogdaten aus Excel-Quellen

## Aktuelle Fachlogik

- Neue Helden werden ueber einen Dialog mit Name und 8 Roh-Startwerten angelegt.
- `rawStartAttributes` speichern die eingegebenen Rohwerte.
- `startAttributes` speichern die effektiven Startwerte nach Rasse/Kultur/Profession.
- Das Eigenschaftsmaximum wird aus dem effektiven Startwert berechnet: `ceil(Start * 1.5)`.
- Der Magie-Tab verwaltet neben Zaubern jetzt auch heldenspezifische Ritualkategorien und Rituale.
- Der Notizen-Tab ist in `Notizen` und `Verbindungen` unterteilt und speichert beide Bereiche direkt im Heldendatensatz.

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
- UI-Tabs (`Combat`, `Talents`, `Overview`) sind in kleinere Part-Dateien zerlegt; Root-Dateien bleiben unter 700 LOC.

### Kampf-UI (Stand: 2026-03-08)
- Die Waffen-Tabelle im Kampf-Tab ist kompakt und zeigt nur Kernwerte sowie Artefakt-Status.
- Waffendetails werden ueber einen Dialog bearbeitet; inline editierbar bleiben nur `Waffentalent` und `BF`.
- Nah- und Fernkampfwaffen werden gemeinsam gepflegt; Fernkampfwaffen bringen AT, Ladezeit, 5 Distanzstufen und persistente Geschossbestaende mit.
- Der Sub-Tab `Kampf` wechselt seine Anzeige automatisch je nach aktiver Waffe zwischen Nahkampfwerten und Fernkampfwerten.
- Der Waffen-Dialog gruppiert Stammdaten, berechnete Ausgabewerte sowie TP-/INI-/AT-Formelfelder; Formelwerte sind dort read-only sichtbar.
- Die angezeigte `PA` der aktiven Nahkampfwaffe enthaelt den heldenbezogenen INI-Parade-Bonus; dieser wird nicht mehr als eigener Waffenwert separat angezeigt.
- Neue Waffen werden ueber denselben Dialog angelegt; der Katalog-Button oeffnet dabei vorbefuellte Vorlagen.

### Workspace-Layout (Stand: 2026-03-08)
- Ab `1280 dp` nutzt der Hero-Workspace das **Helden Deck** statt der klassischen TabBar.
- Die linke Navigationsleiste des Helden Decks ist per Button ein- und ausfahrbar.
- Die rechte Detailleiste ist ebenfalls ein- und ausfahrbar; im offenen Zustand startet sie ohne sichtbare Ueberschrift.

### UI-Performance Guardrails (Stand: 2026-03-01)
- Rebuild-Guardrail (Widget-Test): `flutter test test/ui/performance/ui_rebuild_guardrails_test.dart`
- FrameTiming-Messung (Profile, Integration): `flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/ui_edit_frame_timing_test.dart -d <deviceId>`
- LOC-Budget-Check fuer `lib/ui/screens`: `python tool/check_screen_loc_budget.py --max-lines 700`

### Tooling und Datenaufbereitung
- `tool/convert_excel_to_catalog.py`: erzeugt Runtime-Katalog aus Excel-Listen
- `tool/import_liber_cantiones.py`: reichert `magie.json` mit Liber-Cantiones-Details und Review-Datei an
- `tool/export_rule_cells.py`: Snapshot-Helfer fuer Regelzellen
- `tool/report_unreferenced_dart.py`: Report fuer unreferenzierte `lib/*.dart`
- `tool/check_screen_loc_budget.py`: LOC-Gate fuer Screen-Dateien (z. B. CI-Check auf 700 LOC)

### Derzeit nicht angebundene Dart-Dateien (bewusst behalten)
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
- `docs/test_strategy.md`
- `docs/ui_performance_measurements.md`
