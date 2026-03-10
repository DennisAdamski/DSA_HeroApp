# Schritt 4: Waffen-Editor vom Dialog zum eigenstaendigen Screen

## Ziel

Wandle den `_WeaponEditorDialog` (1.238 LOC) von einem modalen Dialog in
einen eigenstaendigen, testbaren Screen um. Auf breiten Bildschirmen
(>=1280dp, Helden-Deck-Layout) soll er als Side-Panel erscheinen, auf
schmalen Bildschirmen als Full-Screen-Page mit Zurueck-Navigation.

## Voraussetzung

Schritte 1-3 muessen abgeschlossen sein.

## Kontext

Lies zuerst:

1. `lib/ui/screens/hero_combat/weapon_editor_dialog.dart` — der aktuelle
   Editor. Verstehe die Sektionen: Basis-Info, Schadensprofil, Modifikatoren,
   Haltbarkeit, Fernkampf-spezifisch (Distanzen, Geschosse, Ladezeit),
   Beschreibung, Vorschau.
2. `lib/ui/screens/hero_workspace_screen.dart` — das Helden-Deck-Layout,
   um zu verstehen, wie Side-Panels eingebunden werden koennten
3. `lib/ui/screens/hero_combat/combat_weapons_section.dart` — der Aufrufer
   des Editors (aus Schritt 2a)
4. `lib/domain/combat_config.dart` — `MainWeaponSlot`, `RangedWeaponProfile`,
   `DistanceBand`, `Projectile` — die Datenmodelle, die der Editor bearbeitet

## Aufgabe

### 4a: Editor als ConsumerStatefulWidget mit eigenem State

Erstelle `lib/ui/screens/hero_combat/weapon_editor_screen.dart`:

- Eigener `ConsumerStatefulWidget` (KEIN Dialog mehr)
- Verwaltet seinen Draft-State lokal (`_draftWeapon: MainWeaponSlot`)
- Erhaelt die initiale Waffe und Kontext-Daten als Parameter:
  - `initialWeapon: MainWeaponSlot?` (null = neue Waffe)
  - `combatTalents` — fuer Talent-Dropdown
  - `effectiveAttributes` — fuer Vorschauberechnung
  - `catalogWeapons` — fuer Waffentyp-Dropdown-Optionen
- Liefert das Ergebnis ueber `Navigator.pop<MainWeaponSlot>(result)`

### 4b: Inhaltliche Gliederung in Sektionen

Teile den Editor in klar getrennte Sektionen auf, JEDE als eigenes Widget
in einer eigenen Datei unter `lib/ui/screens/hero_combat/weapon_editor/`:

1. `weapon_basic_info_section.dart` — Name, Talent, Waffentyp
   (~100 LOC)
2. `weapon_damage_section.dart` — Wuerfel, TP, KK-Schwelle
   (~100 LOC)
3. `weapon_modifiers_section.dart` — WM AT/PA, INI, BE
   (~80 LOC)
4. `weapon_ranged_section.dart` — Distanzbänder, Geschosse, Ladezeit
   (nur sichtbar bei Fernkampf, ~250 LOC)
5. `weapon_preview_section.dart` — Read-only Vorschau der berechneten
   AT/PA/TP/INI-Werte (~100 LOC)

Jede Sektion:
- Erhaelt die relevanten Draft-Felder als Parameter
- Meldet Aenderungen ueber `onChanged`-Callbacks
- Ist ein StatelessWidget ohne eigenen State

### 4c: Responsive Einbindung

In `combat_weapons_section.dart` (der Waffen-Tabelle):
- Pruefe `MediaQuery.sizeOf(context).width >= 1280`
- **Breit:** Oeffne den Editor als rechtes Panel neben der Waffentabelle
  (z.B. per `Row` mit `Expanded` fuer Tabelle und `SizedBox(width: 400)`
  fuer den Editor). Der Editor erscheint inline ohne Navigation.
- **Schmal:** Oeffne den Editor per `Navigator.push` als eigene Page.
  Der Zurueck-Button schliesst den Editor und liefert das Ergebnis.

### 4d: Validierung und Speichern

- Die Validierungslogik bleibt inhaltlich identisch (Name, Talent, Waffentyp,
  TP >= 1, BF >= 0, etc.)
- Extrahiere die Validierung in eine pure Funktion
  `validateWeaponSlot(MainWeaponSlot) → List<String>` in
  `lib/domain/validation/weapon_validation.dart`
- Der Save-Button im Editor ruft die Validierung auf und zeigt Fehler inline
- Bei Erfolg: `Navigator.pop(result)` oder Callback bei Panel-Modus

### 4e: Test

Erstelle `test/ui/screens/hero_combat/weapon_editor_screen_test.dart`:
- Testet, dass alle Sektionen gerendert werden
- Testet Validierung (leerer Name → Fehler sichtbar)
- Testet, dass Fernkampf-Sektion nur bei Fernkampf-Talent erscheint
- Testet, dass Save das korrekte MainWeaponSlot-Objekt liefert

## Einschraenkungen

- Der alte `weapon_editor_dialog.dart` wird geloescht, NACHDEM der neue
  Screen vollstaendig funktioniert.
- Keine Aenderungen an Domain-Modellen (ausser der neuen Validierungs-
  Funktion).
- Keine Aenderungen an Rules oder Providern.
- Jede Datei unter 300 LOC (ausser `weapon_ranged_section.dart` max 400).
- `weapon_editor_screen.dart` (der Orchestrator) unter 200 LOC.

## Abnahmekriterien

- `flutter analyze` ohne Fehler
- `flutter test` — alle bestehenden Tests + neue Tests gruen
- Waffen-Editor funktioniert auf schmalen UND breiten Screens
- Alle Felder und Validierungen identisch zum alten Dialog
- Die Vorschau zeigt weiterhin korrekte AT/PA/TP/INI-Werte
- Kein File ueber 400 LOC
- Alte Dialog-Datei geloescht
