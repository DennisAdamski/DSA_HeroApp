import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('advancement history preserves commands and immutable options', () {
    final options = {'variant': 'Wüste', 'meisterentscheid': 'true'};
    final entry = HeroAdvancementEntry(
      id: 'entry',
      sessionId: 'session',
      createdAt: DateTime.utc(2026, 9, 5),
      kind: AdvancementKind.generalAbility,
      targetId: 'ability',
      label: 'Geländekunde (Wüste)',
      apCost: 75,
      options: options,
    );
    options['variant'] = 'Wald';
    expect(entry.options['variant'], 'Wüste');
    expect(() => entry.options['variant'] = 'Wald', throwsUnsupportedError);
    final hero = HeroSheet(
      id: 'hero',
      name: 'Held',
      level: 1,
      attributes: const Attributes.zero(),
      advancementHistory: [entry],
    );
    final restored = HeroSheet.fromJson(hero.toJson());
    expect(restored.advancementHistory.single.toJson(), entry.toJson());
    expect(
      restored.copyWith(name: 'Neu').advancementHistory.single.id,
      'entry',
    );
  });

  test(
    'legacy heroes omit empty history to preserve synchronization hashes',
    () {
      final hero = HeroSheet.fromJson({'id': 'hero'});
      expect(hero.advancementHistory, isEmpty);
      expect(hero.toJson(), isNot(contains('advancementHistory')));
      expect(
        hero.copyWith(advancementHistory: []).toJson(),
        isNot(contains('advancementHistory')),
      );
    },
  );

  test('numeric commands roundtrip activation and SE consumption', () {
    final entry = HeroAdvancementEntry(
      id: 'e',
      sessionId: 's',
      createdAt: DateTime.utc(2026),
      kind: AdvancementKind.talent,
      targetId: 'talent',
      label: 'Talent',
      fromValue: -1,
      toValue: 2,
      apCost: 7,
      seSpent: 1,
    );
    expect(
      HeroAdvancementEntry.fromJson(entry.toJson()).toJson(),
      entry.toJson(),
    );
  });
}
