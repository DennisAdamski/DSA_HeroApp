import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/rules/derived/learning_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_rules.dart';

void main() {
  const attributes = Attributes(
    mu: 12,
    kl: 14,
    inn: 18,
    ch: 11,
    ff: 10,
    ge: 13,
    ko: 9,
    kk: 15,
  );

  group('reduceLernkomplexitaet', () {
    test('reduces single steps and supports H', () {
      expect(
        reduceLernkomplexitaet(basisKomplexitaet: 'E', reductionSteps: 1),
        'D',
      );
      expect(
        reduceLernkomplexitaet(basisKomplexitaet: 'B', reductionSteps: 1),
        'A',
      );
      expect(
        reduceLernkomplexitaet(basisKomplexitaet: 'H', reductionSteps: 1),
        'G',
      );
      expect(
        reduceLernkomplexitaet(basisKomplexitaet: 'G', reductionSteps: 1),
        'F',
      );
    });

    test('clamps to A* for oversized reductions', () {
      expect(
        reduceLernkomplexitaet(basisKomplexitaet: 'A', reductionSteps: 1),
        'A*',
      );
      expect(
        reduceLernkomplexitaet(basisKomplexitaet: 'A*', reductionSteps: 3),
        'A*',
      );
      expect(
        reduceLernkomplexitaet(basisKomplexitaet: 'B', reductionSteps: 4),
        'A*',
      );
    });
  });

  group('effective spell complexity', () {
    test('adds all reduction sources', () {
      expect(
        effectiveSteigerung(
          basisSteigerung: 'C',
          istHauszauber: true,
          zauberMerkmale: const <String>['Kraft'],
          heldMerkmalskenntnisse: const <String>['Kraft'],
        ),
        'A',
      );
      expect(
        effectiveSteigerung(
          basisSteigerung: 'B',
          istHauszauber: true,
          zauberMerkmale: const <String>['Kraft'],
          heldMerkmalskenntnisse: const <String>['Kraft'],
          istBegabt: true,
        ),
        'A*',
      );
      expect(
        effectiveSteigerung(
          basisSteigerung: 'H',
          istHauszauber: true,
          zauberMerkmale: const <String>['Kraft'],
          heldMerkmalskenntnisse: const <String>['Kraft'],
          istBegabt: true,
        ),
        'E',
      );
    });

    test('handles each source independently', () {
      expect(
        effectiveSteigerung(
          basisSteigerung: 'D',
          istHauszauber: true,
          zauberMerkmale: const <String>['Kraft'],
          heldMerkmalskenntnisse: const <String>[],
        ),
        'C',
      );
      expect(
        effectiveSteigerung(
          basisSteigerung: 'D',
          istHauszauber: false,
          zauberMerkmale: const <String>['Kraft'],
          heldMerkmalskenntnisse: const <String>['Kraft'],
        ),
        'C',
      );
      expect(
        effectiveSteigerung(
          basisSteigerung: 'D',
          istHauszauber: false,
          zauberMerkmale: const <String>['Kraft'],
          heldMerkmalskenntnisse: const <String>[],
          istBegabt: true,
        ),
        'C',
      );
    });
  });

  group('max value rules', () {
    test('uses highest regular talent attribute', () {
      expect(
        computeTalentMaxValue(
          effectiveAttributes: attributes,
          attributeNames: const <String>['Mut', 'Klugheit', 'Intuition'],
          gifted: false,
        ),
        21,
      );
      expect(
        computeTalentMaxValue(
          effectiveAttributes: attributes,
          attributeNames: const <String>['Mut', 'Klugheit', 'Intuition'],
          gifted: true,
        ),
        23,
      );
    });

    test('uses GE or KK for Nahkampf', () {
      expect(
        computeCombatTalentMaxValue(
          effectiveAttributes: attributes,
          talentType: 'Nahkampf',
          gifted: false,
        ),
        18,
      );
      expect(
        computeCombatTalentMaxValue(
          effectiveAttributes: attributes,
          talentType: 'Nahkampf',
          gifted: true,
        ),
        20,
      );
    });

    test('uses FF or KK for Fernkampf and ignores IN', () {
      expect(
        computeCombatTalentMaxValue(
          effectiveAttributes: attributes,
          talentType: 'Fernkampf',
          gifted: false,
        ),
        18,
      );
      expect(
        computeCombatTalentMaxValue(
          effectiveAttributes: attributes,
          talentType: 'Fernkampf',
          gifted: true,
        ),
        20,
      );
    });
  });
}
