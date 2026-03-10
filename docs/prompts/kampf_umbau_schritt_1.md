# Schritt 1: CombatQuickStats-Widget extrahieren

## Ziel

Erstelle ein wiederverwendbares `CombatQuickStats`-Widget, das die wichtigsten
Kampfwerte (AT, PA, TP, INI, Ausweichen, RS, eBE) als kompakte Chip-Reihe
darstellt. Dieses Widget wird spaeter in mehreren Tabs verwendet und ersetzt
die aktuell mehrfach duplizierten Chip-Darstellungen.

## Kontext

Lies zuerst diese Dateien, um zu verstehen, wie die Kampfwerte heute angezeigt
werden:

1. `lib/ui/screens/hero_combat/hero_combat_melee_subtab.dart` — suche nach
   den Stellen, wo AT/PA/TP/INI/RS/eBE als Chips oder Text dargestellt werden
   (insbesondere die "Ergebnis"-Card und die "Aktive Waffe - Uebersicht"-Card)
2. `lib/rules/derived/combat_rules.dart` — die Klasse `CombatPreviewStats`,
   um zu verstehen, welche Felder verfuegbar sind
3. `lib/ui/screens/hero_overview_tab.dart` — dort werden ebenfalls
   Kampfwerte angezeigt (abgeleitete Werte Sektion)

## Aufgabe

1. Erstelle `lib/ui/widgets/combat_quick_stats.dart` mit einem
   `CombatQuickStats`-Widget (StatelessWidget):
   - Einziger required Parameter: die relevanten Kampfwerte (AT, PA, TP-
     Ausdruck, INI, Ausweichen, RS, eBE). Verwende NICHT den gesamten
     `CombatPreviewStats`-Typ als Parameter — extrahiere nur die Felder, die
     tatsaechlich angezeigt werden, als benannte Parameter oder als schlankes
     Value-Objekt.
   - Optionaler Parameter `isRanged` (bool) — bei Fernkampf wird PA
     ausgeblendet und stattdessen Ladezeit + Geschosse angezeigt.
   - Darstellung als `Wrap` mit `Chip`-Widgets (analog zum bestehenden Stil
     in der Ergebnis-Card).
   - Kompaktes Layout: eine bis zwei Zeilen auf typischer Bildschirmbreite.
   - Keine Edit-Funktionalitaet — rein read-only.

2. Schreibe einen Widget-Test in
   `test/ui/widgets/combat_quick_stats_test.dart`:
   - Testet, dass alle erwarteten Chips gerendert werden (AT, PA, TP, INI,
     Ausweichen, RS, eBE).
   - Testet, dass bei `isRanged: true` PA ausgeblendet und Ladezeit angezeigt
     wird.
   - Testet, dass die Werte korrekt formatiert dargestellt werden.

3. Ersetze in `hero_combat_melee_subtab.dart` die bestehende
   Ergebnis-Chip-Darstellung durch das neue `CombatQuickStats`-Widget.
   Achte darauf, dass sich das Verhalten und die angezeigten Werte nicht
   aendern — rein visuell identisch.

## Einschraenkungen

- Aendere KEINE Logik in `combat_rules.dart` oder Providern.
- Das Widget muss ohne Provider-Zugriff funktionieren (pure Daten rein,
  Widget raus).
- Folge den Projektkonventionen: `prefer_single_quotes`, deutsche Kommentare,
  kein `print`.

## Abnahmekriterien

- `flutter analyze` ohne Fehler
- `flutter test` — alle bestehenden Tests + neuer Widget-Test gruen
- Die Ergebnis-Card im Kampf-Tab sieht visuell identisch aus
- Das neue Widget ist in keiner Weise an `hero_combat_tab.dart` gekoppelt
