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

  group('computeTraitAbbauApCost', () {
    test('Goldgier: 5 Punkte senken im Selbststudium (75x, -1 GP/Punkt)', () {
      expect(
        computeTraitAbbauApCost(
          gpWertProPunkt: -1,
          faktor: kSchlechteEigenschaftSelbststudiumFaktor,
          punkte: 5,
        ),
        375,
      );
    });

    test('Goldgier: 5 Punkte senken mit Spezieller Erfahrung (50x)', () {
      expect(
        computeTraitAbbauApCost(
          gpWertProPunkt: -1,
          faktor: kSchlechteEigenschaftSpezErfahrungFaktor,
          punkte: 5,
        ),
        250,
      );
    });

    test('gestufter Nachteil ohne SE-Marker nutzt den 100er Faktor', () {
      expect(
        computeTraitAbbauApCost(
          gpWertProPunkt: -2,
          faktor: kNachteilAbbauFaktor,
          punkte: 3,
        ),
        600,
      );
    });

    test('0 Punkte kosten 0 AP', () {
      expect(
        computeTraitAbbauApCost(
          gpWertProPunkt: -1,
          faktor: kNachteilAbbauFaktor,
          punkte: 0,
        ),
        0,
      );
    });

    test('negative Punktzahl kostet 0 AP', () {
      expect(
        computeTraitAbbauApCost(
          gpWertProPunkt: -1,
          faktor: kNachteilAbbauFaktor,
          punkte: -3,
        ),
        0,
      );
    });
  });
}
