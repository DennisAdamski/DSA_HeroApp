import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_meta_talent.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/meta_talent_rules.dart';

void main() {
  test('meta talent base taw uses kaufmaennisch rounded mean', () {
    final entries = <String, HeroTalentEntry>{
      'tal_a': const HeroTalentEntry(talentValue: 7),
      'tal_b': const HeroTalentEntry(talentValue: 8),
      'tal_c': const HeroTalentEntry(talentValue: 8),
    };

    final result = computeMetaTalentBaseTaw(
      talentEntries: entries,
      componentTalentIds: const <String>['tal_a', 'tal_b', 'tal_c'],
    );

    expect(result, 8);
  });

  test('meta talent base taw includes combat talents by talentValue only', () {
    final entries = <String, HeroTalentEntry>{
      'tal_sinne': const HeroTalentEntry(talentValue: 9),
      'tal_wildnis': const HeroTalentEntry(talentValue: 6),
      'tal_schwerter': const HeroTalentEntry(
        talentValue: 3,
        atValue: 10,
        paValue: 7,
      ),
    };

    final result = computeMetaTalentBaseTaw(
      talentEntries: entries,
      componentTalentIds: const <String>[
        'tal_sinne',
        'tal_wildnis',
        'tal_schwerter',
      ],
    );

    expect(result, 6);
  });

  test('meta talent computed taw applies own be rule after mean', () {
    final ebe = computeMetaTalentEbe(baseBe: 2, beRule: 'x2');
    final result = computeMetaTalentComputedTaw(baseTaw: 7, ebe: ebe);

    expect(ebe, -4);
    expect(result, 3);
  });

  test('meta talent validation accepts duplicates in attributes', () {
    const metaTalent = HeroMetaTalent(
      id: 'meta_orientierung',
      name: 'Orientierung im Sturm',
      componentTalentIds: <String>['tal_a', 'tal_b'],
      attributes: <String>['MU', 'IN', 'IN'],
      be: '-',
    );

    final issues = validateHeroMetaTalent(
      metaTalent: metaTalent,
      allowedTalentIds: const <String>{'tal_a', 'tal_b', 'tal_c'},
    );

    expect(issues, isEmpty);
  });

  test('meta talent validation rejects malformed be rule', () {
    const metaTalent = HeroMetaTalent(
      id: 'meta_invalid',
      name: 'Unsauber',
      componentTalentIds: <String>['tal_a', 'tal_b'],
      attributes: <String>['MU', 'IN', 'FF'],
      be: 'foo',
    );

    final issues = validateHeroMetaTalent(
      metaTalent: metaTalent,
      allowedTalentIds: const <String>{'tal_a', 'tal_b'},
    );

    expect(issues.single, contains('BE-Regel'));
  });

  test(
    'activating referenced meta talent components fills missing draft entries',
    () {
      final result = activateReferencedMetaTalentComponents(
        talents: const <String, HeroTalentEntry>{
          'tal_a': HeroTalentEntry(talentValue: 5),
        },
        metaTalents: const <HeroMetaTalent>[
          HeroMetaTalent(
            id: 'meta_1',
            name: 'Pflanzensuchen',
            componentTalentIds: <String>['tal_a', 'tal_b'],
            attributes: <String>['MU', 'IN', 'FF'],
          ),
        ],
      );

      expect(result.keys, containsAll(<String>['tal_a', 'tal_b']));
      expect(result['tal_b']?.talentValue, isNull);
    },
  );
}
