import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/currency_rules.dart';

void main() {
  group('currency_rules', () {
    test('liest Dezimal-Dukaten mit Kreuzerpräzision', () {
      expect(parseDsaCurrencyToKreuzer('1,101'), 1101);
      expect(parseDsaCurrencyToKreuzer('1.101'), 1101);
      expect(parseDsaCurrencyToKreuzer('12,5'), 12500);
      expect(parseDsaCurrencyToKreuzer(''), 0);
    });

    test('liest Münzschreibweisen mit Dukaten, Silber und Kreuzern', () {
      expect(parseDsaCurrencyToKreuzer('1 D 2 S 3 K'), 1203);
      expect(parseDsaCurrencyToKreuzer('1 Dukat und 7 Silbertaler'), 1700);
      expect(parseDsaCurrencyToKreuzer('4 Silber + 9 Kreuzer'), 409);
    });

    test('formatiert Dukatenwerte ohne unnötige Nachkommastellen', () {
      expect(formatDsaCurrencyDukaten(1000), '1');
      expect(formatDsaCurrencyDukaten(1100), '1,1');
      expect(formatDsaCurrencyDukaten(1101), '1,101');
      expect(formatDsaCurrencyDukaten(1050), '1,05');
    });

    test('addiert Münzschritte und begrenzt negative Beträge bei null', () {
      expect(
        adjustDsaCurrencyText(rawValue: '5', deltaKreuzer: dsaKreuzerPerSilber),
        '5,1',
      );
      expect(adjustDsaCurrencyText(rawValue: '0', deltaKreuzer: -1), '0');
      expect(adjustDsaCurrencyText(rawValue: 'viel', deltaKreuzer: 1), isNull);
    });

    test('formatiert die sichtbare D/S/K-Aufschlüsselung', () {
      expect(formatDsaCurrencyBreakdown(1203), '1 D / 2 S / 3 K');
      expect(formatDsaCurrencyBreakdown(50), '50 K');
      expect(formatDsaCurrencyBreakdown(0), '0 D');
    });
  });
}
