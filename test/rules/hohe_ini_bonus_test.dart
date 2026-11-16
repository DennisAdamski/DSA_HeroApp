import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/ausweichen_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ini_rules.dart';

void main() {
  // Wege des Schwerts S. 78, optionale Regel „Hohe Initiative-Werte“:
  // über 20 +1, über 30 +2, über 40 +3.
  group('hoheIniBonus', () {
    const faelle = <int, int>{
      -3: 0,
      0: 0,
      20: 0,
      21: 1,
      30: 1,
      31: 2,
      40: 2,
      41: 3,
      50: 3,
      // Das Buch kennt keine Stufe über +3.
      51: 3,
      80: 3,
    };
    faelle.forEach((ini, bonus) {
      test('INI $ini gibt +$bonus', () {
        expect(hoheIniBonus(ini), bonus);
      });
    });

    test('Kampfvorschau rechnet PA und Ausweichen mit derselben Stufe', () {
      for (var ini = -5; ini <= 90; ini++) {
        expect(computeIniParadeMod(ini), hoheIniBonus(ini), reason: '$ini');
        expect(
          computeIniAusweichenBonus(kampfInitiative: ini),
          hoheIniBonus(ini),
          reason: '$ini',
        );
      }
    });
  });
}
