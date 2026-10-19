import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';

void main() {
  group('bereinigeStandort', () {
    test('entfernt Leerraum außen und faltet ihn innen', () {
      expect(bereinigeStandort('  Bad \n  Garetz  '), 'Bad Garetz');
    });

    test('leere Eingabe bleibt leer', () {
      expect(bereinigeStandort('   \n '), '');
    });

    test('kürzt auf die Höchstlänge', () {
      final lang = 'a' * (kStandortMaxLaenge + 30);
      expect(bereinigeStandort(lang).length, kStandortMaxLaenge);
    });
  });

  group('avesmapsLink', () {
    test('baut den Siedlungslink', () {
      expect(
        avesmapsLink('Gareth').toString(),
        'https://avesmaps.de/?siedlung=Gareth',
      );
    });

    test('kodiert Leerzeichen und Umlaute', () {
      final link = avesmapsLink('Bad Garetz Süd')!;
      expect(link.host, 'avesmaps.de');
      expect(link.queryParameters['siedlung'], 'Bad Garetz Süd');
      expect(link.toString(), isNot(contains(' ')));
    });

    test('ohne Standort gibt es keinen Link', () {
      expect(avesmapsLink(''), isNull);
      expect(avesmapsLink('   '), isNull);
    });
  });
}
