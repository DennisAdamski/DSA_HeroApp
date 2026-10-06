import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_summen_rules.dart';

// Wert und Gewicht gelten pro Stück (ARCH-03, Entscheidung vom 07.10.2026).

void main() {
  const pfeile = HeroInventoryEntry(
    gegenstand: 'Pfeil',
    anzahl: '20',
    menge: 20,
    gewichtGramm: 30,
    wertSilber: 2,
  );
  const seil = HeroInventoryEntry(
    gegenstand: 'Seil',
    anzahl: 'ein paar Schritt',
    gewichtGramm: 1000,
    wertSilber: 5,
  );
  const leer = HeroInventoryEntry(
    gegenstand: 'Bolzen',
    anzahl: '0',
    menge: 0,
    gewichtGramm: 40,
    wertSilber: 3,
  );

  test('ein Stapel zählt Menge mal Stückwert', () {
    expect(inventarStapelGewichtGramm(pfeile), 600);
    expect(inventarStapelWertSilber(pfeile), 40);
  });

  test('offene Menge zählt als ein Stück, 0 als nichts', () {
    expect(inventarStapelGewichtGramm(seil), 1000);
    expect(inventarStapelWertSilber(leer), 0);
  });

  test('Summen über alle Einträge', () {
    expect(inventarGesamtgewichtGramm(const [pfeile, seil, leer]), 1600);
    expect(inventarGesamtwertSilber(const [pfeile, seil, leer]), 45);
  });
}
