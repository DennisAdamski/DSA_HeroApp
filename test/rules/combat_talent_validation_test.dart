import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/validation/combat_talent_validation.dart';

void main() {
  TalentDef buildTalent({
    required String id,
    required String name,
    required String type,
  }) {
    return TalentDef(
      id: id,
      name: name,
      group: 'Kampftalent',
      steigerung: 'B',
      attributes: const <String>['MU', 'GE', 'KK'],
      type: type,
    );
  }

  test('normalizeHiddenTalentIds trims and deduplicates ids', () {
    final ids = normalizeHiddenTalentIds(<String>[
      '  sword  ',
      '',
      'sword',
      'bow',
    ]);
    expect(ids, <String>{'sword', 'bow'});
  });

  test('isCombatTalentDef detects combat talents by group and type', () {
    final byGroup = TalentDef(
      id: 'a',
      name: 'A',
      group: 'Kampftalent',
      steigerung: 'B',
      attributes: const <String>['MU', 'GE', 'KK'],
    );
    final byType = TalentDef(
      id: 'b',
      name: 'B',
      group: 'Talente',
      steigerung: 'B',
      attributes: const <String>['MU', 'GE', 'KK'],
      type: 'Fernkampf',
    );

    expect(isCombatTalentDef(byGroup), isTrue);
    expect(isCombatTalentDef(byType), isTrue);
  });

  test('validateCombatTalentDistribution flags invalid Nahkampf AT/PA split', () {
    final talents = <TalentDef>[
      buildTalent(id: 'sword', name: 'Schwerter', type: 'Nahkampf'),
    ];
    final entries = <String, HeroTalentEntry>{
      'sword': const HeroTalentEntry(talentValue: 8, atValue: 5, paValue: 1),
    };

    final issues = validateCombatTalentDistribution(
      talents: talents,
      talentEntries: entries,
      filter: isCombatTalentDef,
    );

    expect(issues.length, 1);
    expect(issues.single.talentId, 'sword');
    expect(issues.single.message, contains('AT + PA = TaW'));
  });

  test('validateCombatTalentDistribution flags invalid Fernkampf split', () {
    final talents = <TalentDef>[
      buildTalent(id: 'bow', name: 'Boegen', type: 'Fernkampf'),
    ];
    final entries = <String, HeroTalentEntry>{
      'bow': const HeroTalentEntry(talentValue: 6, atValue: 5, paValue: 1),
    };

    final issues = validateCombatTalentDistribution(
      talents: talents,
      talentEntries: entries,
      filter: isCombatTalentDef,
    );

    expect(issues.length, 1);
    expect(issues.single.talentId, 'bow');
    expect(issues.single.message, contains('AT = TaW und PA = 0'));
  });
}
