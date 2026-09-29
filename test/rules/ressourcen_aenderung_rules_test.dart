import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';

void main() {
  group('Schritt', () {
    test('zählt vom gespeicherten Wert', () {
      const minusEins = RessourcenAenderung.schritt(-1);
      const plusFuenf = RessourcenAenderung.schritt(5);

      expect(minusEins.wendeAn(20), 19);
      expect(minusEins.wendeAn(minusEins.wendeAn(20)), 18);
      expect(plusFuenf.wendeAn(20), 25);
    });

    test('Untergrenze begrenzt nur nach unten', () {
      const minusFuenf = RessourcenAenderung.schritt(-5, untergrenze: -10);

      expect(minusFuenf.wendeAn(-3), -8);
      expect(minusFuenf.wendeAn(-8), -10);
      expect(minusFuenf.wendeAn(-10), -10);
      // Schon darunter: nie anheben.
      expect(minusFuenf.wendeAn(-12), -12);
    });

    test('Obergrenze begrenzt nur nach oben', () {
      const plusEins = RessourcenAenderung.schritt(1, obergrenze: 30);

      expect(plusEins.wendeAn(29), 30);
      expect(plusEins.wendeAn(30), 30);
      // Überheilt: nie absenken.
      expect(plusEins.wendeAn(33), 33);
    });

    test('ein negativer Wert fällt mit Untergrenze 0 nicht auf 0', () {
      const minusEins = RessourcenAenderung.schritt(-1, untergrenze: 0);

      expect(minusEins.wendeAn(1), 0);
      expect(minusEins.wendeAn(0), 0);
      expect(minusEins.wendeAn(-3), -3);
    });

    test('Grenzen gelten nicht gegen die Schrittrichtung', () {
      const plusEins = RessourcenAenderung.schritt(1, untergrenze: 0);
      const minusEins = RessourcenAenderung.schritt(-1, obergrenze: 30);

      expect(plusEins.wendeAn(-3), -2);
      expect(minusEins.wendeAn(33), 32);
    });
  });

  test('Setzen ignoriert den gespeicherten Wert', () {
    const aufMaximum = RessourcenAenderung.setzen(30);

    expect(aufMaximum.wendeAn(-4), 30);
    expect(aufMaximum.wendeAn(35), 30);
  });
}
