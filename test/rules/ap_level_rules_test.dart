import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/ap_level_rules.dart';

void main() {
  test('computeLevelFromSpentAp handles boundaries and negatives', () {
    expect(computeLevelFromSpentAp(-1), 1);
    expect(computeLevelFromSpentAp(0), 1);
    expect(computeLevelFromSpentAp(50), 1);
    expect(computeLevelFromSpentAp(99), 1);
    expect(computeLevelFromSpentAp(100), 2);
    expect(computeLevelFromSpentAp(150), 2);
    expect(computeLevelFromSpentAp(2571), 7);
    expect(computeLevelFromSpentAp(2799), 7);
    expect(computeLevelFromSpentAp(2800), 8);
    expect(computeLevelFromSpentAp(21000), 21);
    expect(computeLevelFromSpentAp(35100), 27);
    expect(computeLevelFromSpentAp(56100), greaterThan(33));
  });

  test('computeAvailableAp handles normal and overspent values', () {
    expect(computeAvailableAp(100, 20), 80);
    expect(computeAvailableAp(100, 200), 0);
    expect(computeAvailableAp(-5, 10), 0);
  });

  group('epicAspStufenbonus', () {
    test('liefert 0 bei inaktiver Regel', () {
      expect(
        epicAspStufenbonus(
          kategorie: ZaubererKategorie.voll,
          ruleActive: false,
          isEpisch: true,
        ),
        0,
      );
    });

    test('liefert 0 bei nicht-epischem Helden', () {
      expect(
        epicAspStufenbonus(
          kategorie: ZaubererKategorie.voll,
          ruleActive: true,
          isEpisch: false,
        ),
        0,
      );
    });

    test('Vollzauberer behaelt vollen Stufenbonus', () {
      expect(
        epicAspStufenbonus(
          kategorie: ZaubererKategorie.voll,
          ruleActive: true,
          isEpisch: true,
        ),
        6,
      );
    });

    test('Halbzauberer bekommt nur 1 AsP je Stufe', () {
      expect(
        epicAspStufenbonus(
          kategorie: ZaubererKategorie.halb,
          ruleActive: true,
          isEpisch: true,
        ),
        1,
      );
    });

    test('Viertelzauberer bekommt 0 AsP je Stufe', () {
      expect(
        epicAspStufenbonus(
          kategorie: ZaubererKategorie.viertel,
          ruleActive: true,
          isEpisch: true,
        ),
        0,
      );
    });

    test('Nicht-Zauberer bekommt 0 AsP', () {
      expect(
        epicAspStufenbonus(
          kategorie: ZaubererKategorie.keine,
          ruleActive: true,
          isEpisch: true,
        ),
        0,
      );
    });

    test('fullCasterBonus ist konfigurierbar', () {
      expect(
        epicAspStufenbonus(
          kategorie: ZaubererKategorie.voll,
          ruleActive: true,
          isEpisch: true,
          fullCasterBonus: 8,
        ),
        8,
      );
    });
  });
}
