# Schritt 5: Integrations-Check und Aufraeumen

## Ziel

Stelle sicher, dass der umgebaute Kampf-Tab vollstaendig funktioniert,
keine verwaisten Dateien existieren, das LOC-Budget eingehalten wird,
und die Test-Abdeckung die neuen Widgets umfasst.

## Voraussetzung

Schritte 1-4 muessen abgeschlossen sein.

## Aufgabe

### 5a: Verwaiste Dateien identifizieren und entfernen

Pruefe mit `python tool/report_unreferenced_dart.py`, ob Dateien in `lib/`
existieren, die nirgends importiert werden. Loesche verwaiste Dateien, die
durch den Umbau entstanden sind (z.B. alte Subtab-Dateien, alter Dialog).

Pruefe insbesondere:
- `hero_combat_melee_subtab.dart` — sollte geloescht oder stark reduziert sein
- `hero_combat_special_rules_subtab.dart` — ersetzt durch `combat_rules_subtab.dart`
- `hero_combat_maneuvers_subtab.dart` — ersetzt durch `combat_rules_subtab.dart`
- `weapon_editor_dialog.dart` — ersetzt durch `weapon_editor_screen.dart`

### 5b: LOC-Budget pruefen

Fuehre `python tool/check_screen_loc_budget.py --max-lines 700` aus.
Kein Screen-File darf ueber 700 LOC liegen. Falls Verstoesse existieren,
identifiziere die betroffene Datei und extrahiere weitere Sub-Widgets.

Pruefe zusaetzlich manuell alle neuen Dateien:
- `combat_quick_stats.dart` — Ziel: unter 150 LOC
- `combat_weapons_section.dart` — Ziel: unter 800 LOC
- `combat_offhand_section.dart` — Ziel: unter 500 LOC
- `combat_armor_section.dart` — Ziel: unter 500 LOC
- `combat_preview_subtab.dart` — Ziel: unter 500 LOC
- `combat_rules_subtab.dart` — Ziel: unter 700 LOC
- `weapon_editor_screen.dart` — Ziel: unter 200 LOC
- Alle Weapon-Editor-Sektionen — Ziel: unter 300 LOC

### 5c: Rebuild-Guardrails aktualisieren

Pruefe `test/ui/performance/ui_rebuild_guardrails_test.dart`:
- Falls der Test Widget-Namen referenziert, die sich durch den Umbau geaendert
  haben (umbenannte Widgets, geloeschte Widgets), aktualisiere die Referenzen.
- Fuege Rebuild-Checks fuer die neuen Widgets hinzu:
  - `CombatQuickStats` darf bei Namensaenderung des Helden nicht rebuilden
  - `CombatWeaponsSection` darf bei Aenderung der manuellen Mods nicht
    rebuilden
  - `CombatArmorSection` darf bei Waffenaenderung nicht rebuilden

### 5d: CLAUDE.md aktualisieren

Aktualisiere die Directory-Structure-Sektion in `CLAUDE.md`:
- Ergaenze die neuen Dateien unter `lib/ui/screens/hero_combat/`
- Ergaenze `lib/ui/widgets/combat_quick_stats.dart`
- Entferne Referenzen auf geloeschte Dateien
- Ergaenze einen kurzen Abschnitt unter "Update 2026-03-10" mit:
  - Kampf-Tab neu strukturiert: Kampfwerte, Waffen, Ruestung & Verteidigung,
    Kampftechniken, Kampfregeln
  - Waffen-Editor als eigenstaendiger Screen statt Dialog
  - CombatQuickStats als wiederverwendbares Widget
  - Ruestungsanzeige nur noch an einer Stelle (keine Duplikation)

### 5e: Vollstaendiger Testlauf

Fuehre aus:
```bash
flutter analyze
flutter test
python tool/check_screen_loc_budget.py --max-lines 700
```

Alle drei muessen erfolgreich durchlaufen.

## Abnahmekriterien

- Keine verwaisten Dart-Dateien in `lib/`
- Kein Screen-File ueber 700 LOC
- `flutter analyze` ohne Fehler
- `flutter test` ohne Fehler
- Rebuild-Guardrail-Test aktualisiert und gruen
- CLAUDE.md aktualisiert mit neuer Struktur
- Alle Kampf-Tab-Features funktionieren:
  - Kampfwerte-Quickview zeigt AT/PA/TP/INI/RS/eBE
  - Waffen koennen hinzugefuegt, bearbeitet, geloescht werden
  - Ruestung konfigurierbar (nur an einer Stelle)
  - Nebenhand (Schild/Parierwaffe) konfigurierbar
  - Sonderfertigkeiten-Toggles funktionieren
  - Manoever-Toggles funktionieren
  - Manuelle Modifikatoren editierbar
  - Berechnungsschritte aufklappbar
