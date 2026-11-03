import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/spielen/karto_ressourcenleiste.dart';

void main() {
  group('ausgewogeneSpalten', () {
    test('vier Ressourcen bei Platz für drei ergeben 2×2 statt 3+1', () {
      expect(KartoRessourcenleiste.ausgewogeneSpalten(3, 4), 2);
    });

    test('passen alle nebeneinander, bleibt es eine Reihe', () {
      expect(KartoRessourcenleiste.ausgewogeneSpalten(4, 4), 4);
      expect(KartoRessourcenleiste.ausgewogeneSpalten(3, 3), 3);
      expect(KartoRessourcenleiste.ausgewogeneSpalten(2, 2), 2);
    });

    test('teilt keine Spaltenzahl die Anzahl, gilt der Platz', () {
      // Drei Ressourcen bei Platz für zwei: 2+1 und nicht drei Reihen.
      expect(KartoRessourcenleiste.ausgewogeneSpalten(2, 3), 2);
    });

    test('eine Spalte bleibt eine Spalte', () {
      expect(KartoRessourcenleiste.ausgewogeneSpalten(1, 4), 1);
      expect(KartoRessourcenleiste.ausgewogeneSpalten(1, 1), 1);
    });

    test('zwei Spalten für vier Ressourcen bleiben 2×2', () {
      expect(KartoRessourcenleiste.ausgewogeneSpalten(2, 4), 2);
    });
  });
}
