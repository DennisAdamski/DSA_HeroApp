# UI Performance Measurements (Phase 3A)

## Ziel

Messbare Guardrails fuer Edit-Workflows in den grossen Workspace-Tabs:
- `Combat`
- `Talents`
- `Overview`
- `Magic`

## 1) Rebuild-Guardrail (Widget-Test)

Testet, dass ein einzelner Feld-Edit nicht den gesamten Tab-Root neu rendert.

```bash
flutter test test/ui/performance/ui_rebuild_guardrails_test.dart
```

Technik:
- Debug-Counter ueber `UiRebuildObserver` fuer Root-Builds zentraler Tabs.
- Assertion pro Edit-Szenario auf geringe Root-Rebuilds.
- Dieser Test bleibt der Standard-Guardrail fuer UI-Performance-Regressionsschutz.

Magie-spezifisch:
- Geschuetzte Langtexte wie Zauberwirkung und Varianten werden in der aktiven
  Zaubertabelle nicht mehr beim Tab-Aufbau entschluesselt.
- Die Tabelle zeigt stattdessen einen Detail-Hinweis; vollstaendige Inhalte
  werden erst im Zauberdetaildialog aufgeloest und fuer die Sitzung gecached.

## 2) Ad-hoc Profiling (manuell)

Fuer echte Frame-Messungen werden keine dedizierten Integration-Tests mehr
vorgehalten. Bei Bedarf erfolgt Profiling ad hoc auf einem Zielgeraet ueber
Flutter DevTools oder den Performance-Overlay-Workflow.

Hinweis:
- Operative Zielwerte fuer fluide Edit-Workflows bleiben bei etwa 16 ms pro
  Frame.
- Fuer belastbare Messungen weiterhin `--profile` oder einen release-nahen
  Workflow auf realer Hardware nutzen.

## 3) LOC-Guardrail (Tooling/CI)

Verhindert erneutes Anwachsen monolithischer Screen-Dateien.

```bash
python tool/check_screen_loc_budget.py --max-lines 700
```

Verhalten:
- Exit-Code `0`: alle Dateien im Budget.
- Exit-Code `1`: mindestens eine Datei liegt ueber Budget.
- Exit-Code `2`: Root-Verzeichnis fehlt.
