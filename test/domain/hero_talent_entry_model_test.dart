import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';

void main() {
  test('talent entry roundtrip keeps normalized talent modifiers and sum', () {
    final entry = HeroTalentEntry(
      talentValue: 8,
      talentModifiers: <HeroTalentModifier>[
        HeroTalentModifier(modifier: 2, description: 'Sichtbonus'),
        HeroTalentModifier(modifier: -1, description: 'Erschwertes Terrain'),
      ],
    );

    final reloaded = HeroTalentEntry.fromJson(entry.toJson());
    expect(reloaded.modifier, 1);
    expect(reloaded.talentModifiers.length, 2);
    expect(reloaded.talentModifiers.first.description, 'Sichtbonus');
    expect(reloaded.talentModifiers.last.modifier, -1);
  });

  test('talent modifier description is limited to 60 characters', () {
    final modifier = HeroTalentModifier(
      modifier: 1,
      description:
          '123456789012345678901234567890123456789012345678901234567890XYZ',
    );

    expect(modifier.description.length, 60);
    expect(
      modifier.description,
      '123456789012345678901234567890123456789012345678901234567890',
    );
  });

  test('legacy modifier without talent modifiers is ignored on json load', () {
    final reloaded = HeroTalentEntry.fromJson(const <String, dynamic>{
      'talentValue': 5,
      'modifier': 4,
    });

    expect(reloaded.modifier, 0);
    expect(reloaded.talentModifiers, isEmpty);
  });
}
