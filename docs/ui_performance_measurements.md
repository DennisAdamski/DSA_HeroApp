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
flutter test integration_test/ui_edit_frame_timing_test.dart
```

Aktueller Test:
- Repeated row edits im Talents-Tab.
- p95 Build-Duration als Kennzahl.

Hinweis:
- Die harte Zielvorgabe bleibt in Release-Builds bei ~16ms p95.
- Debug/Integration-Laeufe haben in der Praxis hoehere Werte; der Test nutzt deshalb einen konservativen Grenzwert als Regression-Guardrail.

## 3) LOC-Guardrail (Tooling/CI)

Verhindert erneutes Anwachsen monolithischer Screen-Dateien.

```bash
python tool/check_screen_loc_budget.py --max-lines 700
```

Verhalten:
- Exit-Code `0`: alle Dateien im Budget.
- Exit-Code `1`: mindestens eine Datei liegt ueber Budget.
- Exit-Code `2`: Root-Verzeichnis fehlt.
