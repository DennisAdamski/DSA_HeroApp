# UI Performance Measurements (Phase 3A)

## Ziel

Messbare Guardrails fuer Edit-Workflows in den grossen Workspace-Tabs:
- `Combat`
- `Talents`
- `Overview`

## 1) Rebuild-Guardrail (Widget-Test)

Testet, dass ein einzelner Feld-Edit nicht den gesamten Tab-Root neu rendert.

```bash
flutter test test/ui_rebuild_guardrails_test.dart
```

Technik:
- Debug-Counter ueber `UiRebuildObserver` fuer Root-Builds zentraler Tabs.
- Assertion pro Edit-Szenario auf geringe Root-Rebuilds.

## 2) FrameTiming-Guardrail (Integration-Test)

Misst Frame-Build-Zeiten waehrend wiederholter Edit-Aktionen.

```bash
flutter drive --profile \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/ui_edit_frame_timing_test.dart \
  -d <deviceId>
```

Aktueller Test:
- Repeated row edits im Talents-Tab.
- Repeated row edits im Combat-Talents-Tab.
- Repeated overview edits (AP Feld).
- Repeated AP-Increment Aktion in Overview.
- p50/p95 Build-Duration als Kennzahl.

Hinweis:
- Die harte Zielvorgabe bleibt in Release-Builds bei ~16ms p95.
- Fuer belastbare Werte immer `--profile` nutzen.
- Der Test nutzt 32ms als Regression-Grenzwert; operative Zielwerte bleiben strenger.

## Letzte Baseline (Android Tablet Emulator, 2026-03-01)

- talents_edit: p95 `2568 us` (2.57 ms)
- combat_edit: p95 `1297 us` (1.30 ms)
- overview_edit: p95 `1989 us` (1.99 ms)
- overview_ap_increment: p95 `1395 us` (1.40 ms)

## 3) LOC-Guardrail (Tooling/CI)

Verhindert erneutes Anwachsen monolithischer Screen-Dateien.

```bash
python tool/check_screen_loc_budget.py --max-lines 700
```

Verhalten:
- Exit-Code `0`: alle Dateien im Budget.
- Exit-Code `1`: mindestens eine Datei liegt ueber Budget.
- Exit-Code `2`: Root-Verzeichnis fehlt.
