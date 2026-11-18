import 'package:dsa_heldenverwaltung/rules/derived/tp_ausdruck_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rechnet den Zuschlag in den festen Anteil', () {
    expect(tpMitZuschlag('2W6+1', 2), '2W6+3');
    expect(tpMitZuschlag('1W6', 2), '1W6+2');
    expect(tpMitZuschlag('1W6-1', 1), '1W6');
    expect(tpMitZuschlag('1W6 + 2', 2), '1W6+4');
    expect(tpMitZuschlag('1W6+1', -3), '1W6-2');
  });

  test('Text hinter dem festen Anteil bleibt stehen', () {
    expect(tpMitZuschlag('1W+4 (A)', 1), '1W+5 (A)');
  });

  test('unlesbare Angaben bekommen den Zuschlag angehaengt', () {
    expect(tpMitZuschlag('Huf', 2), 'Huf +2');
    expect(tpMitZuschlag('', 2), '+2');
  });

  test('ohne Zuschlag bleibt die Angabe unveraendert', () {
    expect(tpMitZuschlag(' 1W6 + 2 ', 0), ' 1W6 + 2 ');
  });

  group('tpAusdruckZuWuerfel', () {
    test('liest Würfel mit festem Anteil', () {
      final a = tpAusdruckZuWuerfel('1W6+3')!;
      expect((a.count, a.sides, a.modifier), (1, 6, 3));
      final b = tpAusdruckZuWuerfel('2W6')!;
      expect((b.count, b.sides, b.modifier), (2, 6, 0));
      final c = tpAusdruckZuWuerfel(' 2 W 6 - 1 ')!;
      expect((c.count, c.sides, c.modifier), (2, 6, -1));
      final d = tpAusdruckZuWuerfel('W20')!;
      expect((d.count, d.sides, d.modifier), (1, 20, 0));
    });

    test('ohne Seitenzahl gilt der W6 der DSA-Schreibweise', () {
      final a = tpAusdruckZuWuerfel('1W+4')!;
      expect((a.count, a.sides, a.modifier), (1, 6, 4));
    });

    test('ein Zusatz in Klammern wird übergangen', () {
      final a = tpAusdruckZuWuerfel('1W+4 (A)')!;
      expect((a.count, a.sides, a.modifier), (1, 6, 4));
    });

    test('Freitext und leere Angaben sind nicht lesbar', () {
      expect(tpAusdruckZuWuerfel('Huf +2'), isNull);
      expect(tpAusdruckZuWuerfel(''), isNull);
      expect(tpAusdruckZuWuerfel('Gift'), isNull);
      expect(tpAusdruckZuWuerfel('3'), isNull);
      expect(tpAusdruckZuWuerfel('1W6 und mehr'), isNull);
      expect(tpAusdruckZuWuerfel('0W6'), isNull);
    });

    test('die Anzeige passt zu tpMitZuschlag', () {
      expect(tpAusdruckZuWuerfel(tpMitZuschlag('1W6', 2))!.label, '1W6+2');
    });
  });
}
