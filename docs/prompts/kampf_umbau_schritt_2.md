# Schritt 2: Melee-Subtab in eigenstaendige Widgets aufbrechen

## Ziel

Zerlege `hero_combat_melee_subtab.dart` (2.562 LOC) in drei eigenstaendige
Widget-Dateien, die per `import` statt `part of` eingebunden werden. Jede
Datei soll unter 800 LOC bleiben. Es darf KEIN Informationsgehalt verloren
gehen — alle bestehenden UI-Elemente muessen erhalten bleiben.

## Kontext

Lies zuerst vollstaendig:

1. `lib/ui/screens/hero_combat_tab.dart` — der Parent, der die Subtabs
   koordiniert und den Draft-State (CombatConfig, Talents) verwaltet
2. `lib/ui/screens/hero_combat/hero_combat_melee_subtab.dart` — das Ziel
   der Zerlegung. Identifiziere die drei Hauptsektionen:
   - **Waffen-Sektion**: Waffen-Tabelle, Katalog-Zugriff, Waffen-Slots
   - **Nebenhand-Sektion**: Parierwaffen- und Schild-Tabelle + Editor
   - **Ruestungs-Sektion**: Ruestungstabelle + Berechnungsvorschau
3. `lib/ui/screens/hero_combat/weapon_editor_dialog.dart` — wird von der
   Waffen-Sektion aufgerufen
4. `lib/ui/screens/hero_combat/hero_combat_form_fields.dart` — gemeinsame
   Formularfelder
5. `lib/domain/combat_config.dart` — das Domain-Modell, um die
   Datenschnittstelle zu verstehen

## Aufgabe

### 2a: Waffen-Widget extrahieren

Erstelle `lib/ui/screens/hero_combat/combat_weapons_section.dart`:
- Enthaelt die komplette Waffen-Uebersichtstabelle (alle 14 Spalten)
- Enthaelt den Katalog-Zugriff (Bottom-Sheet mit Waffenkatalog)
- Enthaelt die Konvertierung Katalogwaffe → MainWeaponSlot
- Kommunikation mit dem Parent ueber Callbacks:
  - `onWeaponsChanged(List<MainWeaponSlot>)` — wenn Waffen hinzugefuegt,
    geaendert oder entfernt werden
  - `onWeaponEdit(int index)` — wenn der Waffen-Editor geoeffnet werden soll
- Eingabeparameter:
  - `weapons: List<MainWeaponSlot>` — aktuelle Waffenliste
  - `isEditing: bool` — Edit-Modus aktiv?
  - `combatTalents` — fuer Talent-Referenz in der Tabelle
  - `effectiveAttributes` — fuer Vorschauberechnung
  - Weitere Parameter nach Bedarf, aber so wenige wie moeglich

### 2b: Nebenhand-Widget extrahieren

Erstelle `lib/ui/screens/hero_combat/combat_offhand_section.dart`:
- Enthaelt die Parierwaffen-/Schild-Tabelle
- Enthaelt den Nebenhand-Editor-Dialog (inline, kein separater Dialog-File)
- Kommunikation ueber Callbacks:
  - `onOffhandEquipmentChanged(List<OffhandEquipmentEntry>)`
- Eingabeparameter:
  - `offhandEquipment: List<OffhandEquipmentEntry>`
  - `isEditing: bool`
  - `hasLinkhand: bool` — fuer Linkhand-Warnung

### 2c: Ruestungs-Widget extrahieren

Erstelle `lib/ui/screens/hero_combat/combat_armor_section.dart`:
- Enthaelt die Ruestungstabelle (Name, RS, BE, Aktiv, RG I)
- Enthaelt die Ruestungs-Berechnungsvorschau (RS gesamt, BE Kampf, eBE)
- Enthaelt den Ruestungs-Editor-Dialog
- Kommunikation ueber Callbacks:
  - `onArmorChanged(ArmorConfig)`
- Eingabeparameter:
  - `armor: ArmorConfig`
  - `isEditing: bool`
  - `previewStats` — fuer die Berechnungsvorschau (nur die relevanten
    RS/BE/eBE-Werte, nicht der gesamte CombatPreviewStats)

### 2d: Melee-Subtab als Orchestrator

Reduziere `hero_combat_melee_subtab.dart` auf einen schlanken Orchestrator,
der die drei neuen Widgets per `import` einbindet und in einer `ListView`
untereinander anordnet. Der Orchestrator leitet die Callbacks an den
Parent-State (`_draftCombatConfig`) weiter.

**Wichtig:** Die Datei darf KEIN `part of` mehr verwenden. Aendere die
Einbindung in `hero_combat_tab.dart` entsprechend von `part` auf `import`.

Falls `hero_combat_tab.dart` derzeit private Members (`_draft*`, `_sync*`)
an den Subtab weitergibt, muessen diese ueber Parameter/Callbacks exponiert
werden. Pruefe genau, welcher State vom Parent kommt und welcher lokal ist.

## Einschraenkungen

- Aendere KEINE Geschaeftslogik, keine Rules, keine Provider.
- Alle bestehenden UI-Elemente muessen visuell identisch bleiben.
- Kein neuer State — die Widgets sind rein praesentational mit Callbacks.
- Jede neue Datei unter 800 LOC.
- `hero_combat_melee_subtab.dart` (der Orchestrator) unter 200 LOC.
- Folge den Projektkonventionen: `prefer_single_quotes`, deutsche Kommentare.

## Abnahmekriterien

- `flutter analyze` ohne Fehler
- `flutter test` — alle bestehenden Tests gruen
- Kein `part of` mehr in den Kampf-Subtab-Dateien
- Jede Datei unter 800 LOC (pruefe mit `wc -l`)
- Die Ausruestungs-Ansicht im Kampf-Tab ist visuell identisch zum Vorher
- Der Waffen-Editor-Dialog funktioniert weiterhin korrekt
