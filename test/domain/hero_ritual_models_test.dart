import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';

void main() {
  test('ritual category roundtrip keeps own knowledge, fields and rituals', () {
    const category = HeroRitualCategory(
      id: 'ritual_cat_1',
      name: 'Elfenlieder',
      knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
      ownKnowledge: HeroRitualKnowledge(
        name: 'Elfenlieder',
        value: 3,
        learningComplexity: 'E',
      ),
      additionalFieldDefs: <HeroRitualFieldDef>[
        HeroRitualFieldDef(
          id: 'field_probe',
          label: 'Probe',
          type: HeroRitualFieldType.threeAttributes,
        ),
        HeroRitualFieldDef(
          id: 'field_material',
          label: 'Material',
          type: HeroRitualFieldType.text,
        ),
      ],
      rituals: <HeroRitualEntry>[
        HeroRitualEntry(
          name: 'Lied des Trostes',
          wirkung: 'Beruhigt das Ziel.',
          kosten: '4 AsP',
          wirkungsdauer: '1 Stunde',
          merkmale: 'Einfluss',
          additionalFieldValues: <HeroRitualFieldValue>[
            HeroRitualFieldValue(
              fieldDefId: 'field_probe',
              attributeCodes: <String>['MU', 'CH', 'IN'],
            ),
            HeroRitualFieldValue(
              fieldDefId: 'field_material',
              textValue: 'Laute',
            ),
          ],
        ),
      ],
    );

    final reloaded = HeroRitualCategory.fromJson(category.toJson());

    expect(reloaded.id, 'ritual_cat_1');
    expect(reloaded.name, 'Elfenlieder');
    expect(reloaded.knowledgeMode, HeroRitualKnowledgeMode.ownKnowledge);
    expect(reloaded.ownKnowledge?.value, 3);
    expect(reloaded.additionalFieldDefs.length, 2);
    expect(reloaded.rituals.single.name, 'Lied des Trostes');
    expect(
      reloaded.rituals.single.additionalFieldValues.first.attributeCodes,
      <String>['MU', 'CH', 'IN'],
    );
  });

  test('ritual category roundtrip keeps derived talents', () {
    const category = HeroRitualCategory(
      id: 'ritual_cat_2',
      name: 'Elfenlieder',
      knowledgeMode: HeroRitualKnowledgeMode.derivedTalents,
      derivedTalentIds: <String>['tal_singen', 'tal_musizieren'],
    );

    final reloaded = HeroRitualCategory.fromJson(category.toJson());

    expect(reloaded.derivedTalentIds, <String>['tal_singen', 'tal_musizieren']);
    expect(reloaded.ownKnowledge, isNull);
  });
}
