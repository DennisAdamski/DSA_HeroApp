# Schritt 3: Subtab-Struktur neu verdrahten und Ruestungs-Redundanz eliminieren

## Ziel

Strukturiere die Kampf-Subtabs um: Erstelle einen neuen "Kampfwerte"-Subtab
als primaere Spieltisch-Ansicht, eliminiere die doppelte Ruestungsanzeige,
und lege Sonderfertigkeiten + Manoever zu einem "Kampfregeln"-Subtab zusammen.

## Voraussetzung

Schritt 2 muss abgeschlossen sein (eigenstaendige Widgets fuer Waffen,
Nebenhand, Ruestung).

## Kontext

Lies zuerst:

1. `lib/ui/screens/hero_combat_tab.dart` — die aktuelle TabBar-Konfiguration
   mit 5 Subtabs und dem TabController
2. `lib/ui/screens/hero_combat/hero_combat_melee_subtab.dart` — der
   Orchestrator aus Schritt 2 (Ausruestung-Tab)
3. `lib/ui/screens/hero_combat/weapon_detail_expansion.dart` — die
   Berechnungsschritte-Expansion (wird in den neuen Kampfwerte-Tab verschoben)
4. `lib/ui/screens/hero_combat/hero_combat_special_rules_subtab.dart` —
   Sonderfertigkeiten-Toggles
5. `lib/ui/screens/hero_combat/hero_combat_maneuvers_subtab.dart` —
   Manoever-Toggles
6. `lib/ui/widgets/combat_quick_stats.dart` — das Widget aus Schritt 1

## Aufgabe

### 3a: Neuen "Kampfwerte"-Subtab erstellen

Erstelle `lib/ui/screens/hero_combat/combat_preview_subtab.dart`:

Dieser Subtab ist die **Spieltisch-Schnellansicht**. Er zeigt:

1. **Haupthand-Auswahl** (Dropdown der Waffenslots) — bereits im alten
   "Kampf"-Subtab vorhanden, hierher verschieben
2. **CombatQuickStats-Widget** (aus Schritt 1) mit den Werten der aktiven
   Waffe — prominent, oben
3. **Nebenhand-Auswahl** (Dropdown) mit kompakter Vorschau (Name + Typ +
   relevante Mods als Chips) — vereinfacht gegenueber der alten Version
4. **Aufklappbare Berechnungsschritte** (`ExpansionTile`) — die bestehende
   Logik aus `weapon_detail_expansion.dart` einbinden. Standardmaessig
   zugeklappt, damit die Spieltisch-Ansicht kompakt bleibt.
5. **Manuelle Modifikatoren** (INI, Ausweichen, AT, PA) — editierbare Felder,
   nur im Edit-Modus sichtbar

Dieser Subtab ersetzt den bisherigen "Kampf"-Subtab. Er enthaelt KEINE
Ruestungstabelle mehr — nur die abgeleiteten RS/eBE-Werte ueber das
CombatQuickStats-Widget.

**Ziel-LOC:** unter 500 LOC.

### 3b: Sonderfertigkeiten + Manoever zusammenlegen

Erstelle `lib/ui/screens/hero_combat/combat_rules_subtab.dart`:

- Obere Sektion: Alle Sonderfertigkeiten-Toggles (aus dem bisherigen
  `hero_combat_special_rules_subtab.dart`)
- Untere Sektion (mit Ueberschrift "Manoever"): Alle Manoever-Toggles (aus
  dem bisherigen `hero_combat_maneuvers_subtab.dart`)
- Getrennt durch eine `Divider` oder Sektions-Ueberschrift
- Keine inhaltliche Aenderung — nur zusammengefuehrt

Die alten Dateien `hero_combat_special_rules_subtab.dart` und
`hero_combat_maneuvers_subtab.dart` werden danach geloescht.

**Ziel-LOC:** unter 700 LOC (beide zusammen waren vorher deutlich darunter).

### 3c: TabBar in hero_combat_tab.dart anpassen

Aendere die Tab-Konfiguration von 5 auf 5 Tabs (gleiche Anzahl, andere
Aufteilung):

| Position | Alt                  | Neu                      |
|----------|----------------------|--------------------------|
| Tab 0    | Kampftechniken       | **Kampfwerte** (neu, 3a) |
| Tab 1    | Ausruestung          | Waffen (umbenannt)       |
| Tab 2    | Kampf                | Ruestung & Verteidigung  |
| Tab 3    | Sonderfertigkeiten   | Kampftechniken           |
| Tab 4    | Manoever             | **Kampfregeln** (neu, 3b)|

**Tab 2 "Ruestung & Verteidigung"** enthaelt:
- `CombatArmorSection` (aus Schritt 2c) — die Ruestungstabelle
- `CombatOffhandSection` (aus Schritt 2b) — Parierwaffen und Schilde
- Dies ist die EINZIGE Stelle, wo Ruestung konfiguriert wird (Redundanz
  eliminiert)

**Tab 1 "Waffen"** enthaelt:
- `CombatWeaponsSection` (aus Schritt 2a) — nur die Waffentabelle
- Kein Nebenhand, keine Ruestung mehr

Passe den `TabController` und die `TabBar`-Labels entsprechend an.

### 3d: Alten Kampf-Subtab-Code entfernen

Loesche den gesamten Code des alten "Kampf"-Subtabs aus
`hero_combat_melee_subtab.dart`, der jetzt durch `combat_preview_subtab.dart`
(Kampfwerte) und die separate Ruestungs-/Nebenhand-Einbindung ersetzt ist.

Wenn `hero_combat_melee_subtab.dart` danach leer oder trivial ist, loesche
die Datei komplett.

## Einschraenkungen

- Alle Informationen, die vorher sichtbar waren, muessen weiterhin erreichbar
  sein — nur die POSITION aendert sich.
- Die Ruestungskonfiguration existiert NUR NOCH im Tab "Ruestung &
  Verteidigung" — nicht mehr zusaetzlich im Kampf-Preview.
- Keine Aenderungen an Domain-Modellen, Rules oder Providern.
- Alle Dateien unter 700 LOC.

## Abnahmekriterien

- `flutter analyze` ohne Fehler
- `flutter test` — alle bestehenden Tests gruen
- 5 Subtabs mit den neuen Namen in der TabBar
- Kein duplizierter Ruestungs-Code mehr
- "Kampfwerte"-Tab zeigt CombatQuickStats prominent an
- Ruestungstabelle nur noch in "Ruestung & Verteidigung"
- Sonderfertigkeiten und Manoever in einem gemeinsamen Tab
- Keine Datei ueber 700 LOC
