import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/trait_ap_cost_rules.dart';

void main() {
  group('computeTraitApCost', () {
    test('Canon-Beispiel: Krankheitsanfaellig (-7 GP) Abbau kostet 700 AP', () {
      expect(computeTraitApCost(-7, kNachteilAbbauFaktor), 700);
    });

    test('Vorteil-Erwerb nutzt 50er Faktor', () {
      expect(computeTraitApCost(7, kVorteilErwerbFaktor), 350);
    });

    test('Schlechte Eigenschaft per Spezieller Erfahrung', () {
      expect(computeTraitApCost(-2, kSchlechteEigenschaftSpezErfahrungFaktor), 100);
    });

    test('Schlechte Eigenschaft im Selbststudium (1,5-fach)', () {
      expect(computeTraitApCost(-2, kSchlechteEigenschaftSelbststudiumFaktor), 150);
    });

    test('ignoriert Vorzeichen des GP-Werts', () {
      expect(
        computeTraitApCost(-5, kVorteilErwerbFaktor),
        computeTraitApCost(5, kVorteilErwerbFaktor),
      );
    });

    test('liefert 0 bei GP-Wert 0', () {
      expect(computeTraitApCost(0, kNachteilAbbauFaktor), 0);
    });
  });
}
