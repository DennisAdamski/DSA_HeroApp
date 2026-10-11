import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ritual_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ritual_knowledge_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_requirement_context.dart';

void main() {
  const category = HeroRitualCategory(
    id: 'staff',
    name: 'Stabzauber',
    knowledgeMode: HeroRitualKnowledgeMode.traditionKnowledge,
    traditionId: 'gildenmagier',
  );
  const knowledge = HeroRitualKnowledge(
    name: 'Gildenmagie',
    value: 9,
    unbekannteFelder: {'futureKnowledge': 17},
  );
  const hero = HeroSheet(
    id: 'shared',
    name: 'Shared',
    level: 1,
    attributes: Attributes.zero(),
    ritualKnowledge: {'gildenmagier': knowledge},
    ritualCategories: [category],
  );
  test('shared reference survives normalization and follows common value', () {
    final normalized = normalizeRitualCategory(category);
    expect(normalized.ownKnowledge, isNull);
    expect(normalized.traditionId, 'gildenmagier');
    expect(resolveRitualKnowledge(hero, normalized), knowledge);
    final changed = hero.copyWith(
      ritualKnowledge: {'gildenmagier': knowledge.copyWith(value: 12)},
    );
    expect(resolveRitualKnowledge(changed, normalized)?.value, 12);
    expect(
      resolveRitualKnowledge(hero.copyWith(ritualKnowledge: {}), normalized),
      isNull,
    );
  });
  test('JSON preserves shared knowledge, category refs and unknown fields', () {
    final restored = HeroSheet.fromJson(hero.toJson()).copyWith(name: 'Edited');
    expect(restored.ritualKnowledge['gildenmagier'], knowledge);
    expect(restored.ritualCategories.single, category);
    expect(
      restored.ritualKnowledge['gildenmagier']!.toJson()['futureKnowledge'],
      17,
    );
  });
  test(
    'requirement context sees common knowledge without ritual categories',
    () {
      final context = buildHeroRequirementContext(
        hero.copyWith(ritualCategories: []),
      );
      expect(context.ritualkenntnisse['Gildenmagie'], 9);
    },
  );
  test('legacy categories are never merged during JSON loading', () {
    final old = hero.copyWith(
      ritualKnowledge: {},
      ritualCategories: [
        category.copyWith(
          knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
          traditionId: '',
          ownKnowledge: knowledge,
        ),
        category.copyWith(
          id: 'bowl',
          knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
          traditionId: '',
          ownKnowledge: knowledge.copyWith(value: 5),
        ),
      ],
    );
    final restored = HeroSheet.fromJson(old.toJson());
    expect(restored.ritualKnowledge, isEmpty);
    expect(restored.ritualCategories.map((e) => e.ownKnowledge!.value), [9, 5]);
  });
}
