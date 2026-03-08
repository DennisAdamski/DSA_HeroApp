# CLAUDE.md — DSA Heldenverwaltung

AI-assistant reference for the `dsa_heldenverwaltung` Flutter project.
Read this before making any changes.

---

## Project Overview

**DSA Heldenverwaltung** is a cross-platform Flutter app for managing heroes in the tabletop RPG *Das Schwarze Auge* (DSA). It provides:

- Local persistence using the Hive key-value database
- DSA rule calculations (attributes, derived stats, talents, combat)
- Hero import/export as JSON
- Catalog data (talents, weapons, spells) loaded from split JSON assets

The primary language of comments, variable names, UI strings, and commit messages is **German**.

---

## Technology Stack

| Layer | Technology |
|---|---|
| Language | Dart ^3.10.4 |
| Framework | Flutter (Material 3) |
| State management | flutter_riverpod ^2.6.1 |
| Local database | hive ^2.2.3, hive_flutter ^1.1.0 |
| File I/O | file_picker ^8.1.4, path_provider ^2.1.5 |
| Sharing | share_plus ^10.1.2 |
| IDs | uuid ^4.5.1 |
| Linting | flutter_lints ^6.0.0 |
| Testing | flutter_test, integration_test |

---

## Directory Structure

```
DSA_HeroApp/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── catalog/                     # Catalog loading and model
│   │   ├── catalog_loader.dart
│   │   └── rules_catalog.dart
│   ├── data/                        # Repository implementations & I/O
│   │   ├── hero_repository.dart     # Abstract repository interface
│   │   ├── hive_hero_repository.dart
│   │   ├── hero_transfer_codec.dart
│   │   ├── hero_transfer_file_gateway.dart   # Platform stub + io/web impls
│   │   └── startup_hero_importer.dart
│   ├── domain/                      # Pure domain models (no Flutter deps)
│   │   ├── hero_sheet.dart          # Core hero model (persisted)
│   │   ├── hero_state.dart          # Runtime state (LeP, AsP, …)
│   │   ├── attributes.dart
│   │   ├── combat_config.dart
│   │   ├── hero_talent_entry.dart
│   │   ├── hero_meta_talent.dart        # Heldenspezifische Meta-Talent-Definition
│   │   ├── hero_spell_entry.dart       # Zauber-Eintrag (ZfW, Hauszauber, …)
│   │   ├── hero_inventory_entry.dart
│   │   ├── magic_special_ability.dart  # Magische Sonderfertigkeit (Name+Notiz)
│   │   ├── stat_modifiers.dart
│   │   ├── bought_stats.dart
│   │   └── validation/
│   │       └── combat_talent_validation.dart
│   ├── rules/derived/               # DSA rule calculations (pure Dart)
│   │   ├── derived_stats.dart
│   │   ├── attributes_rules.dart
│   │   ├── modifier_parser.dart
│   │   ├── meta_talent_rules.dart
│   │   ├── talent_be_rules.dart
│   │   ├── ap_level_rules.dart
│   │   ├── combat_rules.dart        # placeholder — not wired up
│   │   ├── magic_rules.dart         # Magie-Regeln (Verfuegbarkeit, Steigerung, Merkmale)
│   │   └── mods_rules.dart          # placeholder — not wired up
│   ├── state/                       # Riverpod providers & snapshots
│   │   ├── hero_providers.dart      # All providers + HeroActions
│   │   ├── hero_computed_snapshot.dart
│   │   ├── hero_index_snapshot.dart
│   │   └── catalog_providers.dart
│   ├── ui/
│   │   ├── config/ui_feature_flags.dart
│   │   ├── debug/ui_rebuild_observer.dart
│   │   ├── widgets/flexible_table.dart
│   │   └── screens/
│   │       ├── heroes_home_screen.dart      # Hero list / selection
│   │       ├── hero_workspace_screen.dart   # Tab host for one hero
│   │       ├── workspace_edit_contract.dart
│   │       ├── workspace/                   # Workspace sub-components
│   │       ├── hero_overview_tab.dart       # Tab: Uebersicht
│   │       ├── hero_overview/               # Overview part files
│   │       ├── hero_talents_tab.dart        # Tab: Talente
│   │       ├── hero_talents/                # Talent part files
│   │       ├── hero_combat_tab.dart         # Tab: Kampf
│   │       ├── hero_combat/                 # Combat part files
│   │       ├── hero_magic_tab.dart           # Tab: Magie
│   │       ├── hero_magic/                  # Magic part files
│   │       ├── hero_inventory_tab.dart      # Tab: Inventar
│   │       └── hero_detail_screen.dart      # legacy placeholder
│   └── test_support/
│       └── fake_repository.dart
├── test/                            # Unit & widget tests
├── integration_test/                # Frame-timing integration tests
├── assets/
│   ├── catalogs/house_rules_v1/     # Split JSON catalog (runtime)
│   │   ├── manifest.json
│   │   ├── talente.json
│   │   ├── waffen.json
│   │   ├── waffentalente.json
│   │   └── magie.json
│   └── heroes/                      # Seed hero JSON files
├── tool/                            # Python helper scripts
│   ├── convert_excel_to_catalog.py
│   ├── import_liber_cantiones.py
│   ├── split_house_rules_catalog.py
│   ├── export_rule_cells.py
│   ├── report_unreferenced_dart.py
│   ├── check_screen_loc_budget.py
│   └── ios_bootstrap_spm.sh
├── docs/                            # Developer documentation
│   ├── catalog_import_workflow.md
│   ├── ios_xcode_setup.md
│   ├── rules_mapping_house_rules_v1.md
│   └── ui_performance_measurements.md
├── pubspec.yaml
├── analysis_options.yaml
├── AGENTS.md                        # Agent policy (binding)
└── README.md
```

---

## Architecture

### Layered Design

```
UI (flutter_riverpod ConsumerWidgets)
        │  watches
        ▼
State layer (Riverpod providers in lib/state/)
        │  reads/writes
        ▼
Domain models (lib/domain/) — immutable, pure Dart
        │
        ├── Rules (lib/rules/derived/) — pure functions, no side effects
        ├── Repository interface (lib/data/hero_repository.dart)
        └── Catalog (lib/catalog/)
```

### Core Data Flow

1. **App start** (`main.dart`): `HiveHeroRepository` is created, seed heroes imported, then injected into `ProviderScope` via `heroRepositoryProvider.overrideWithValue(...)`.
2. **Hero index**: `heroIndexProvider` (StreamProvider) streams `Map<String, HeroSheet>` from the repository and wraps it in `HeroIndexSnapshot` for O(1) ID lookup.
3. **Computed snapshot**: `heroComputedProvider` (Provider.family) watches a single hero and its `HeroState`, applies modifier parsing, effective attributes, derived stats, and combat preview — all bundled in `HeroComputedSnapshot`. This is the single source of truth for all derived values displayed in the UI.
4. **Write path**: The UI calls `HeroActions` (obtained from `heroActionsProvider`) for create/save/delete/import/export. `HeroActions` normalises data (AP, level) before persisting.

### Key Models

| Class | File | Purpose |
|---|---|---|
| `HeroSheet` | `domain/hero_sheet.dart` | Persisted hero data; immutable, has `copyWith` and `toJson`/`fromJson` |
| `HeroTalentModifier` | `domain/hero_talent_entry.dart` | Einzelner Modifikatorbaustein fuer Nicht-Kampftalente (Wert + Beschreibung) |
| `HeroMetaTalent` | `domain/hero_meta_talent.dart` | Heldenspezifische Meta-Talent-Definition mit Komponenten, Eigenschaften und BE-Regel |
| `HeroState` | `domain/hero_state.dart` | Runtime state (current LeP/AsP/KaP/Au, temp modifiers) |
| `HeroComputedSnapshot` | `state/hero_computed_snapshot.dart` | All derived values for one hero, computed in one pass |
| `HeroIndexSnapshot` | `state/hero_index_snapshot.dart` | Sorted hero list + O(1) ID map |
| `HeroSpellEntry` | `domain/hero_spell_entry.dart` | Persisted spell entry (ZfW, Hauszauber, modifier, Legacy-Spezialisierungen, Text-Overrides) |
| `HeroSpellTextOverrides` | `domain/hero_spell_text_overrides.dart` | Heldenspezifische Korrekturen fuer importierte Zauberdetails |
| `MagicSpecialAbility` | `domain/magic_special_ability.dart` | Persisted magic special ability (name + note) |
| `HeroTransferBundle` | `domain/hero_transfer_bundle.dart` | Export/import envelope (hero + state + timestamp) |

### Providers Cheat-Sheet

| Provider | Type | Purpose |
|---|---|---|
| `heroRepositoryProvider` | `Provider<HeroRepository>` | Repository (overridden at startup) |
| `heroIndexProvider` | `StreamProvider<HeroIndexSnapshot>` | All heroes, streamed |
| `heroListProvider` | `StreamProvider<List<HeroSheet>>` | Sorted hero list |
| `heroByIdProvider(id)` | `Provider.family<HeroSheet?>` | Fast O(1) lookup |
| `selectedHeroIdProvider` | `StateProvider<String?>` | Currently selected hero ID |
| `heroStateProvider(id)` | `StreamProvider.family<HeroState>` | Live runtime state |
| `heroComputedProvider(id)` | `Provider.family<AsyncValue<HeroComputedSnapshot>>` | All derived values |
| `effectiveAttributesProvider(id)` | `Provider.family<AsyncValue<Attributes>>` | Effective attributes only |
| `derivedStatsProvider(id)` | `Provider.family<AsyncValue<DerivedStats>>` | Derived stats only |
| `combatPreviewProvider(id)` | `Provider.family<AsyncValue<CombatPreviewStats>>` | Combat preview stats only |
| `heroActionsProvider` | `Provider<HeroActions>` | Write operations |
| `rulesCatalogProvider` | (catalog_providers.dart) | Async catalog data |

---

## Development Workflows

### Quick Start

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

### Testing

```bash
# Run all unit and widget tests
flutter test

# Run a specific guardrail test
flutter test test/ui/performance/ui_rebuild_guardrails_test.dart

# Run integration test with frame timing (requires a connected device)
flutter drive --profile \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/ui_edit_frame_timing_test.dart \
  -d <deviceId>
```

#### Test folder layout (since 2026-03-05)

- `test/rules/`: pure formula/rule tests only (no widget rendering)
- `test/ui/`: widget/smoke/performance tests, technical behavior only
- `test/state/`: provider/index/snapshot behavior
- `test/data/`: loader/repository import-export behavior
- `test/domain/`: serialization/model roundtrips
- `test/workspace/`: workspace coordination helpers

See `docs/test_strategy.md` and `test/README.md` for the full matrix and conventions.
The talent computed-value formula used by Talents UI is centralized in
`lib/rules/derived/talent_value_rules.dart`. Meta-talent aggregation,
validation, and component activation live in
`lib/rules/derived/meta_talent_rules.dart`.

### Linting & Static Analysis

```bash
flutter analyze
```

Linting is configured in `analysis_options.yaml` (extends `flutter_lints/flutter.yaml`). The only project-specific rule enabled is `prefer_single_quotes: true`.

### Update 2026-03-08

- `HeroSheet` verwendet jetzt `rawStartAttributes` fuer Roh-Startwerte und `startAttributes` fuer effektive Startwerte nach Rasse/Kultur/Profession.
- Neue Start-/Maximum-Logik liegt in `lib/rules/derived/attribute_start_rules.dart`.
- `HeroComputedSnapshot` enthaelt zusaetzlich effektive Startwerte und Eigenschaftsmaxima.
- Die aktuelle `schemaVersion` fuer `HeroSheet` ist **9**.
- Die Waffen-Uebersicht im Kampf-Tab ist kompakt; Detailwerte werden ueber
  `lib/ui/screens/hero_combat/weapon_editor_dialog.dart` bearbeitet.
- Der Waffen-Dialog ist ausgabeorientiert gruppiert und zeigt TP-/INI-
  Formelfelder als read-only Vorschau.
- Die sichtbare Parade der aktiven Waffe enthaelt den heldenbezogenen
  INI-Parade-Bonus; dieser wird nicht mehr als eigener Waffenwert separat
  ausgewiesen.
- Der `HeroWorkspaceScreen` nutzt ab `1280 dp` das breite **Helden-Deck**-
  Layout; die linke Navigationsleiste und die rechte Detailleiste koennen
  dort unabhaengig eingeklappt werden.

### LOC Budget Check (screens)

Screen files in `lib/ui/screens/` must stay under 700 lines:

```bash
python tool/check_screen_loc_budget.py --max-lines 700
```

### iOS Setup (Mac + Xcode 15+)

```bash
bash tool/ios_bootstrap_spm.sh
# See docs/ios_xcode_setup.md for full instructions
```

### Catalog Maintenance (Excel → JSON)

```bash
# Regenerate runtime catalog from Excel source files
python tool/convert_excel_to_catalog.py

# Import Liber Cantiones spell details into magie.json
python tool/import_liber_cantiones.py --pdf "<path-to-pdf>"

# Split a monolithic catalog into the split-JSON structure
python tool/split_house_rules_catalog.py

# Snapshot rule cells (for auditing)
python tool/export_rule_cells.py

# Report unreferenced Dart files in lib/
python tool/report_unreferenced_dart.py
```

---

## Code Conventions

### Dart / Flutter

- **Immutable models**: all domain models use `const` constructors and `copyWith` for updates — never mutate directly.
- **Single quotes**: `prefer_single_quotes` is enforced by the linter.
- **No print statements**: `avoid_print` is active via flutter_lints.
- **File naming**: `snake_case.dart` for all files.
- **Screen size limit**: root screen/tab files must stay under **700 LOC**. Split into sub-files (e.g. `hero_combat/` directory) before exceeding this.
- **ConsumerWidget vs ConsumerStatefulWidget**: use `ConsumerWidget` (stateless) by default; use `ConsumerStatefulWidget` only when local widget state is genuinely needed.
- **Provider access in UI**: use `.watch` for reactive reads; use `.read` only inside callbacks (e.g. button presses).
- **Backward-compatible serialization**: `fromJson` must be lenient (use `?? defaultValue` for every field) to support older hero data schemas. The current `schemaVersion` is **9**.
- **German comments and identifiers**: code-level comments and domain names follow German (rasse, kultur, Held, Talente, etc.).

### Catalog

- The canonical catalog source is `assets/catalogs/house_rules_v1/` (split JSON with `manifest.json`).
- Do **not** modify catalog JSON files by hand; use the Python tools in `tool/`.
- Excel source files (`*.xlsx`) at the repo root are the upstream source; `~$*.xlsx` lockfiles are versioned but not runtime-relevant.

### Git Workflow

- Work on task branches named `task/<YYYYMMDD-HHMMSS>-<short-topic>` (e.g. `task/20260302-143000-combat-fix`).
- Never commit directly to `main` or `master`.
- Commit after each completed, tested change — one logical change per commit.
- Commit message format: `<bereich>: <konkrete Änderung>` (e.g. `combat: migrate weapons to editable table`).
- Run `flutter analyze` and `flutter test` before committing; do not commit if either fails.
- See `AGENTS.md` for the full binding agent policy including forbidden commands.

---

## Placeholder / Legacy Files

The following files are **intentionally kept** but not currently wired into the app. Do **not** delete them without explicit instruction:

| File | Reason |
|---|---|
| `lib/rules/derived/combat_rules.dart` | Placeholder for future combat rule expansion |
| `lib/rules/derived/mods_rules.dart` | Placeholder for modifier rules |
| `lib/ui/screens/hero_detail_screen.dart` | Legacy screen, kept for reference |

---

## UI Performance Guardrails

- **Rebuild guardrail test**: `test/ui/performance/ui_rebuild_guardrails_test.dart` — verifies that widgets do not rebuild excessively. Must pass before every commit that touches providers or widgets.
- **Frame timing**: `integration_test/ui_edit_frame_timing_test.dart` — profile-mode integration test measuring jank. Run on device when changing edit flows.
- **LOC budget**: `tool/check_screen_loc_budget.py` — gates screen files at 700 LOC. Exceeded files must be split into a subdirectory of part files.

---

## Platform Notes

- **Priority platforms**: The app is primarily developed for mobile (Android, iOS) and desktop.
- **Platform directories** (`android/`, `ios/`, `macos/`, `windows/`, `linux/`, `web/`): modify only when there is a clear platform-specific need. Avoid mass-edits to generated platform files.
- **Web**: `hero_transfer_file_gateway_web.dart` provides a web-specific implementation of file I/O via conditional imports (`_stub.dart` / `_io.dart` / `_web.dart` pattern).

---

## Before Making Changes — Checklist

1. State the goal and scope of the task clearly.
2. Identify only the files that need to change.
3. Inspect current state with `git status` and `git diff`.
4. Read the affected files before editing them.
5. Make the minimal necessary changes.
6. Run `flutter analyze` and relevant `flutter test` targets.
7. Commit with a precise message if tests pass.
8. Report any remaining risks or open issues.

> See `AGENTS.md` for the complete binding agent policy, including the list of forbidden commands and safe alternatives.

## Update 2026-03-07

- `HeroSpellEntry` stores an additional `gifted` flag for spell-specific
  aptitude.
- Shared learning-complexity and talent-cap logic lives in
  `lib/rules/derived/learning_rules.dart`.
- Learning categories are handled on the scale
  `A* < A < B < C < D < E < F < G < H`.
- Combat talent caps must use `GE/KK` for melee and `FF/KK` for ranged,
  without using `IN`.

