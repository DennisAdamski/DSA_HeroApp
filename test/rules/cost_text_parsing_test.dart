import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/cost_text_parsing.dart';

void main() {
  group('parseLeadingApAmount', () {
    test('parst einfachen Betrag', () {
      expect(parseLeadingApAmount('400 AP'), 400);
    });

    test('parst Betrag mit Zusatztext', () {
      expect(parseLeadingApAmount('200 AP pro Stufe (5 Stufen)'), 200);
    });

    test('parst Betrag vor Semikolon-Zusatz', () {
      expect(
        parseLeadingApAmount('50 AP; nur 20 AP bei vorhandener SF Block'),
        50,
      );
    });

    test('liefert null bei unterschiedlichen Kosten', () {
      expect(parseLeadingApAmount('unterschiedliche Kosten'), isNull);
    });

    test('liefert null bei fehlendem Betrag', () {
      expect(parseLeadingApAmount('—'), isNull);
    });

    test('liefert null wenn keine Zahl direkt vor AP steht', () {
      expect(
        parseLeadingApAmount('AP-Kosten des verwendeten Manövers × 2'),
        isNull,
      );
    });
  });

  group('parseGpAmount', () {
    test('parst negativen Betrag', () {
      expect(parseGpAmount('-7 GP'), -7);
    });

    test('parst negativen Betrag mit Praefix', () {
      expect(parseGpAmount('je -1 GP pro Punkt'), -1);
    });

    test('parst positiven Betrag', () {
      expect(parseGpAmount('7 GP'), 7);
    });

    test('liefert null bei unterschiedlichen Kosten', () {
      expect(parseGpAmount('unterschiedliche Kosten'), isNull);
    });
  });
}
