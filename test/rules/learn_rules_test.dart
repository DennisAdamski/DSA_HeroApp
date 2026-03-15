import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/learn/learn_complexity.dart';
import 'package:dsa_heldenverwaltung/domain/learn/learn_rules.dart';

void main() {
  group('learnCostFromKomplexitaet', () {
    test('maps all supported complexity labels', () {
      expect(learnCostFromKomplexitaet('A*'), LearnCost.z);
      expect(learnCostFromKomplexitaet('A'), LearnCost.a);
      expect(learnCostFromKomplexitaet('B'), LearnCost.b);
      expect(learnCostFromKomplexitaet('C'), LearnCost.c);
      expect(learnCostFromKomplexitaet('D'), LearnCost.d);
      expect(learnCostFromKomplexitaet('E'), LearnCost.e);
      expect(learnCostFromKomplexitaet('F'), LearnCost.f);
      expect(learnCostFromKomplexitaet('G'), LearnCost.g);
      expect(learnCostFromKomplexitaet('H'), LearnCost.h);
    });

    test('returns null for unknown labels', () {
      expect(learnCostFromKomplexitaet('X'), isNull);
      expect(learnCostFromKomplexitaet(''), isNull);
    });
  });

  group('berechneSteigerungskosten', () {
    test('calculates regular costs without SE', () {
      final result = berechneSteigerungskosten(
        vonWert: 6,
        aufWert: 10,
        effektiveKomplexitaet: LearnCost.c,
      );

      expect(result.apKosten, 126);
      expect(result.seVerbraucht, 0);
    });

    test('applies SE to the first matching steps', () {
      final result = berechneSteigerungskosten(
        vonWert: 6,
        aufWert: 10,
        effektiveKomplexitaet: LearnCost.c,
        seAnzahl: 2,
      );

      expect(result.apKosten, 108);
      expect(result.seVerbraucht, 2);
    });

    test('charges activation costs for inactive talents', () {
      final result = berechneSteigerungskosten(
        vonWert: -1,
        aufWert: 0,
        effektiveKomplexitaet: LearnCost.a,
      );

      expect(result.apKosten, 5);
      expect(result.seVerbraucht, 0);
    });
  });

  test('apMitLehrmeister applies a 20 percent discount', () {
    expect(apMitLehrmeister(100), 80);
  });

  test('dukatenFuerLehrmeister uses the agreed formula', () {
    expect(dukatenFuerLehrmeister(80, 15), 24.0);
  });
}
