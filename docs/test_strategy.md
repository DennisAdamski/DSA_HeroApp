# Test Strategy

## Ziel

Die Testsuite ist fachlich getrennt, damit Regeln/Formeln isoliert und
technische UI-Aspekte getrennt getestet werden.

## Verbindliche Grundregel

- Regel-/Formeltests gehoeren **nur** nach `test/rules/`.
- UI-Tests unter `test/ui/` pruefen nur technische Aspekte:
  Rendering, Interaktion, Navigation, Persistenz-Flows.
- Mischtests (Regel + Technik in einer Testklasse) sind nicht erlaubt.

## Ordnerstruktur

- `test/rules/`: pure Logik, Formeln, Validierung
- `test/ui/`: Widget-/Smoke-/Performance-Tests
- `test/state/`: Provider- und Stream-Verhalten
- `test/data/`: Loader/Transfer/Repository-nahe Tests
- `test/domain/`: Serialisierung/Model-Roundtrips
- `test/workspace/`: Workspace-Koordinationslogik

## Zuordnungsmatrix

| Testdatei | Gruppe | Zweck |
|---|---|---|
| `test/rules/ap_level_rules_test.dart` | rules | AP-Level-Formeln |
| `test/domain/attribute_codes_test.dart` | domain | Attributcode-Parsing/Mapping |
| `test/rules/combat_rules_test.dart` | rules | Kampfberechnungen |
| `test/rules/combat_talent_validation_test.dart` | rules | Verteilungsregeln fuer Kampftalente |
| `test/rules/derived_stats_test.dart` | rules | Abgeleitete Basiswerte |
| `test/rules/modifier_text_parser_test.dart` | rules | Text-Modifier-Parsing |
| `test/rules/talent_be_rules_test.dart` | rules | Talent-BE-Regeln |
| `test/rules/talent_value_rules_test.dart` | rules | Formel `TaW + Mod + eBE` |
| `test/ui/combat/hero_combat_tab_test.dart` | ui | Combat-UI-Interaktion/Struktur |
| `test/ui/combat/hero_combat_talents_tab_test.dart` | ui | Combat-Talents-UI-Validierungsfluss |
| `test/ui/talents/hero_talents_tab_test.dart` | ui | Talents-UI-Interaktion |
| `test/ui/workspace/hero_workspace_edit_mode_test.dart` | ui | Workspace-Edit-Flow |
| `test/ui/workspace/hero_workspace_import_export_test.dart` | ui | Workspace Import/Export UI |
| `test/ui/home/heroes_home_screen_test.dart` | ui | Startscreen/Navigation |
| `test/ui/performance/ui_rebuild_guardrails_test.dart` | ui | Rebuild-Guardrail |
| `test/ui/smoke/widget_test.dart` | ui | App-Start Smoke |
| `test/state/hero_by_id_provider_test.dart` | state | Provider-ID-Lookup |
| `test/state/hero_computed_snapshot_test.dart` | state | Combined compute pipeline |
| `test/state/hero_provider_lookup_strategy_test.dart` | state | Lookup-Strategie ohne Listenscan |
| `test/state/hero_repository_stream_test.dart` | state | Repository-Streams |
| `test/data/catalog_loader_test.dart` | data | Katalog-Loading/Validierung |
| `test/data/catalog_model_test.dart` | data | Katalogmodell Roundtrip |
| `test/data/hero_actions_import_export_test.dart` | data | Actions Import/Export |
| `test/domain/hero_sheet_model_test.dart` | domain | HeroSheet-Kompatibilitaet |
| `test/domain/hero_transfer_bundle_test.dart` | domain | Transfer-Bundle-Kontrakt |
| `test/workspace/workspace_area_registry_test.dart` | workspace | Area-Registry |
| `test/workspace/workspace_tab_edit_controller_test.dart` | workspace | Tab-Edit-Controller |

## Laufbefehle

```bash
flutter analyze
flutter test test/rules
flutter test test/ui
flutter test
```
