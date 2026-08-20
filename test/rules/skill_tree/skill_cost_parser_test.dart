import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_cost_parser.dart';

void main() {
  group('parseApCost', () {
    test('parst einfache AP-Angabe', () {
      expect(parseApCost('200 AP'), 200);
      expect(parseApCost('450 AP'), 450);
    });

    test('nimmt die fuehrende Zahl bei Zusatztext', () {
      expect(
        parseApCost(
          '200 AP; verbilligt für Helden mit dem Vorteil Schlangenmensch (100 AP)',
        ),
        200,
      );
    });

    test('nimmt die erste Stufe bei Mehrfachangaben', () {
      expect(
        parseApCost('400 / 550 / 700 AP (je nach Merkmalsklassifikation I/II/III)'),
        400,
      );
    });

    test('toleriert Tausenderpunkte', () {
      expect(parseApCost('2.500 AP'), 2500);
    });

    test('parst Zahl ohne Tausenderpunkt korrekt', () {
      expect(parseApCost('2500 AP'), 2500);
    });

    test('findet Zahl auch nach Prosa', () {
      expect(
        parseApCost(
          'Je nach Waffe; allgemein mindestens 2.500 AP in Kampf-Sonderfertigkeiten',
        ),
        2500,
      );
    });

    test('gibt null ohne Zahl zurueck', () {
      expect(parseApCost(''), isNull);
      expect(parseApCost('Je nach Waffe'), isNull);
      expect(parseApCost('Variabel'), isNull);
    });
  });
}
