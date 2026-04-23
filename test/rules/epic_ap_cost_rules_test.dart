import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/epic_ap_cost_rules.dart';

void main() {
  group('applyEpicApSurcharge', () {
    test('keine Aenderung bei deaktivierter Regel', () {
      expect(
        applyEpicApSurcharge(
          100,
          ruleActive: false,
          isEpisch: true,
        ),
        100,
      );
    });

    test('keine Aenderung bei nicht-epischem Helden', () {
      expect(
        applyEpicApSurcharge(
          100,
          ruleActive: true,
          isEpisch: false,
        ),
        100,
      );
    });

    test('+25 % fuer normale Inhalte bei aktiver Regel und epischem Helden',
        () {
      expect(
        applyEpicApSurcharge(
          100,
          ruleActive: true,
          isEpisch: true,
        ),
        125,
      );
    });

    test('kein Aufschlag fuer epische Inhalte', () {
      expect(
        applyEpicApSurcharge(
          400,
          ruleActive: true,
          isEpisch: true,
          isEpicContent: true,
        ),
        400,
      );
    });

    test('kein Aufschlag bei Begabung', () {
      expect(
        applyEpicApSurcharge(
          200,
          ruleActive: true,
          isEpisch: true,
          isBegabung: true,
        ),
        200,
      );
    });

    test('kein Aufschlag bei Sondererfahrungs-Nutzung', () {
      expect(
        applyEpicApSurcharge(
          200,
          ruleActive: true,
          isEpisch: true,
          isSpecialExperience: true,
        ),
        200,
      );
    });

    test('Lehrmeister hebt den Aufschlag auf', () {
      expect(
        applyEpicApSurcharge(
          100,
          ruleActive: true,
          isEpisch: true,
          lehrmeisterHebtAuf: true,
        ),
        100,
      );
    });

    test('Basiskosten <= 0 bleiben unveraendert', () {
      expect(
        applyEpicApSurcharge(
          0,
          ruleActive: true,
          isEpisch: true,
        ),
        0,
      );
    });

    test('Rundung zur naechsten ganzen Zahl', () {
      // 7 * 1.25 = 8.75 -> 9
      expect(
        applyEpicApSurcharge(
          7,
          ruleActive: true,
          isEpisch: true,
        ),
        9,
      );
    });
  });

  group('computeEpicApSurchargeDelta', () {
    test('liefert 0 wenn Regel inaktiv ist', () {
      expect(
        computeEpicApSurchargeDelta(
          100,
          ruleActive: false,
          isEpisch: true,
        ),
        0,
      );
    });

    test('liefert die Differenz zwischen Aufschlag und Basis', () {
      expect(
        computeEpicApSurchargeDelta(
          100,
          ruleActive: true,
          isEpisch: true,
        ),
        25,
      );
    });
  });
}
