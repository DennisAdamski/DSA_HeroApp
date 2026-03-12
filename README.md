# DSA Heldenverwaltung

Flutter-App zur Verwaltung von DSA-Helden mit:
- lokaler Persistenz (Hive)
- Regeln/abgeleiteten Werten
- Import/Export von Helden als JSON
- Katalogdaten aus Excel-Quellen
- Kampfmanöver und Kampf-Sonderfertigkeiten aus Split-JSON-Katalogen

## Aktuelle Fachlogik

- Neue Helden werden ueber einen Dialog mit Name und 8 Roh-Startwerten angelegt.
- `rawStartAttributes` speichern die eingegebenen Rohwerte.
- `startAttributes` speichern die effektiven Startwerte nach Rasse/Kultur/Profession.
- Das Eigenschaftsmaximum wird aus dem effektiven Startwert berechnet: `ceil(Start * 1.5)`.
- Der Magie-Tab verwaltet neben Zaubern jetzt auch heldenspezifische Ritualkategorien und Rituale.
- Der Notizen-Tab ist in `Notizen` und `Verbindungen` unterteilt und speichert beide Bereiche direkt im Heldendatensatz.
- Der Kampf-Tab verwaltet Waffenmeisterschaften ueber `CombatConfig.waffenmeisterschaften` und den Waffenmeister-Baukasten im Kampfregeln-Tab.
- Waffenlose Kampftechniken aus `Wege des Schwerts` werden als katalogbasierte Kampf-Sonderfertigkeiten gefuehrt und schalten ihre zugeordneten Manöver direkt frei.

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
- Der Kampf-Katalog umfasst jetzt auch `manoever.json` und `kampf_sonderfertigkeiten.json`.

### Architektur-Notiz (Stand: 2026-03-01)
- State-Layer nutzt einen stream-basierten Heldenindex (`HeroIndexSnapshot`) fuer O(1)-Lookup je ID.
- Abgeleitete Berechnungen werden zentral ueber `HeroComputedSnapshot` gebuendelt (Modifier, effektive Attribute, Derived, Combat-Preview).
- Repository-Schnittstelle ist auf inkrementelle Streams erweitert (`watchHeroIndex`, `watchHeroState`, `loadHeroById`).
- UI-Tabs (`Combat`, `Talents`, `Overview`) sind in kleinere Part-Dateien zerlegt; Root-Dateien bleiben unter 700 LOC.

### Kampf-UI (Stand: 2026-03-11)
- Der Sub-Tab `Ausrüstung` ist die zentrale Kampf-Inventaransicht fuer Waffen, Parierwaffen, Schilde und Ruestungen.
- Haupt- und Nebenhand referenzieren konkrete Eintraege aus diesem Kampf-Inventar.
- Die Waffen-Tabelle im Kampf-Tab ist kompakt und zeigt nur Kernwerte sowie Artefakt-Status.
- Waffendetails werden ueber einen Dialog bearbeitet; inline editierbar bleiben nur `Waffentalent` und `BF`.
- Nah- und Fernkampfwaffen werden gemeinsam gepflegt; Fernkampfwaffen bringen AT, Ladezeit, 5 Distanzstufen und persistente Geschossbestaende mit.
- Parierwaffen und Schilde werden als eigene Kampf-Inventargruppe erfasst; Schilde erzeugen eine eigene `Schild-PA`, Parierwaffen modifizieren nur die Hauptwaffe.
- Der Sub-Tab `Kampf` wechselt seine Anzeige automatisch je nach aktiver Waffe zwischen Nahkampfwerten und Fernkampfwerten.
- Fuehrt die Nebenhand eine normale Waffe, zeigt die UI deren eigene Werte in einer separaten Nebenhand-Karte; die Initiative bleibt von der Haupthand bestimmt.
- Der Waffen-Dialog gruppiert Stammdaten, berechnete Ausgabewerte sowie TP-/INI-/AT-Formelfelder; Formelwerte sind dort read-only sichtbar.
- Die angezeigte `PA` der aktiven Nahkampfwaffe enthaelt den heldenbezogenen INI-Parade-Bonus; dieser wird nicht mehr als eigener Waffenwert separat angezeigt.
- Neue Waffen werden ueber denselben Dialog angelegt; der Katalog-Button oeffnet dabei vorbefuellte Vorlagen.
- Axxeleratus aktiviert temporaer `Schnellziehen`, `Schnellladen (Bogen)` und `Schnellladen (Armbrust)`; Fernkampf-Ladezeiten werden im Kampf-Preview als `Aktion`/`Aktionen` ausgegeben.
- Der Bereich `Kampfregeln` enthaelt jetzt zusaetzlich einen Builder fuer Kampfmeisterschaften mit Zieltyp, Effekten, Anforderungswarnungen und Punktbudget.
- `CombatPreviewStats` zeigt anwendbare Meisterschaften sowie automatisch eingerechnete Boni fuer AT, PA, INI, Schild-PA, TP/KK, Ladezeit und Fernkampf-Reichweite.
- Aktive waffenlose Kampfstile werden im Kampfregel-Tab als eigene Katalogsektion gepflegt; direkte Stilboni auf `Raufen`/`Ringen` sowie die freigeschalteten waffenlosen Manöver werden in die Kampfvorschau eingerechnet.

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
