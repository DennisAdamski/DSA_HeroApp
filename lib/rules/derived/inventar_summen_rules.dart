// Wert und Gewicht im Inventar (ARCH-03, Entscheidung vom 07.10.2026).
//
// `gewichtGramm` und `wertSilber` gelten pro Stück. Ein Stapel wiegt und
// kostet seine Menge mal den Stückwert; Teilen und Zusammenführen bleiben so
// ohne Umrechnung richtig. Eine offene Menge (leer oder Freitext) zählt als
// ein Stück, eine Menge von 0 als nichts.

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_menge_rules.dart';

/// Stückzahl, mit der Wert und Gewicht von [e] zählen.
int inventarStueckzahlFuerSummen(HeroInventoryEntry e) {
  return wirksameInventarMenge(e) ?? 1;
}

/// Gewicht des ganzen Stapels [e] in Gramm.
int inventarStapelGewichtGramm(HeroInventoryEntry e) {
  return e.gewichtGramm * inventarStueckzahlFuerSummen(e);
}

/// Wert des ganzen Stapels [e] in Silbertalern.
int inventarStapelWertSilber(HeroInventoryEntry e) {
  return e.wertSilber * inventarStueckzahlFuerSummen(e);
}

/// Gesamtgewicht aller [eintraege] in Gramm.
int inventarGesamtgewichtGramm(Iterable<HeroInventoryEntry> eintraege) {
  return eintraege.fold<int>(
    0,
    (summe, e) => summe + inventarStapelGewichtGramm(e),
  );
}

/// Gesamtwert aller [eintraege] in Silbertalern.
int inventarGesamtwertSilber(Iterable<HeroInventoryEntry> eintraege) {
  return eintraege.fold<int>(
    0,
    (summe, e) => summe + inventarStapelWertSilber(e),
  );
}

/// Gewicht in Gramm als Anzeigetext: „850 g“, ab 1000 g „1,5 kg“ mit
/// Dezimalkomma. [nullText] erscheint für 0 und weniger.
String formatiereGewichtGramm(int gramm, {String nullText = '0 g'}) {
  if (gramm <= 0) return nullText;
  if (gramm < 1000) return '$gramm g';
  final kilo = gramm / 1000.0;
  final ganz = kilo.truncateToDouble() == kilo;
  return '${kilo.toStringAsFixed(ganz ? 0 : 1).replaceAll('.', ',')} kg';
}
