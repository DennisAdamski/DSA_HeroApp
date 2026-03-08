import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ritual_rules.dart';

void main() {
  test(
    'resolveDerivedRitualTalents uses catalog names and hero taw values',
    () {
      const category = HeroRitualCategory(
        id: 'ritual_cat_1',
        name: 'Elfenlieder',
        knowledgeMode: HeroRitualKnowledgeMode.derivedTalents,
        derivedTalentIds: <String>['tal_singen', 'tal_musizieren'],
      );
      const catalogTalents = <TalentDef>[
        TalentDef(
          id: 'tal_singen',
          name: 'Singen',
          group: 'Koerper',
          steigerung: 'B',
          attributes: <String>['MU', 'CH', 'CH'],
        ),
        TalentDef(
          id: 'tal_musizieren',
          name: 'Musizieren',
          group: 'Koerper',
          steigerung: 'B',
          attributes: <String>['KL', 'CH', 'FF'],
        ),
      ];
      const heroTalents = <String, HeroTalentEntry>{
        'tal_singen': HeroTalentEntry(talentValue: 7),
        'tal_musizieren': HeroTalentEntry(talentValue: 9),
      };

      final resolved = resolveDerivedRitualTalents(
        category: category,
        catalogTalents: catalogTalents,
        heroTalents: heroTalents,
      );

      expect(resolved.map((entry) => entry.talentName).toList(), <String>[
        'Singen',
        'Musizieren',
      ]);
      expect(resolved.map((entry) => entry.talentValue).toList(), <int>[7, 9]);
    },
  );

  test('normalizeRitualAttributeCodes maps aliases to canonical codes', () {
    final normalized = normalizeRitualAttributeCodes(const <String>[
      'Mut',
      'Charisma',
      'intuition',
    ]);

    expect(normalized, <String>['MU', 'CH', 'IN']);
  });

  test(
    'normalizeRitualAttributeCodes rejects incomplete or invalid values',
    () {
      final normalized = normalizeRitualAttributeCodes(const <String>[
        'Mut',
        'invalid',
        '',
      ]);

      expect(normalized, isEmpty);
    },
  );

  test(
    'normalizeRitualCategory syncs own knowledge name and drops stale values',
    () {
      const category = HeroRitualCategory(
        id: 'ritual_cat_1',
        name: 'Flueche',
        knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
        ownKnowledge: HeroRitualKnowledge(
          name: 'Altname',
          value: 4,
          learningComplexity: 'X',
        ),
        additionalFieldDefs: <HeroRitualFieldDef>[
          HeroRitualFieldDef(
            id: 'field_probe',
            label: 'Probe',
            type: HeroRitualFieldType.threeAttributes,
          ),
        ],
        rituals: <HeroRitualEntry>[
          HeroRitualEntry(
            name: 'Hexenfluch',
            wirkung: 'Test',
            kosten: '1',
            wirkungsdauer: '1',
            merkmale: 'Einfluss',
            additionalFieldValues: <HeroRitualFieldValue>[
              HeroRitualFieldValue(
                fieldDefId: 'field_probe',
                attributeCodes: <String>['MU', 'CH', 'IN'],
              ),
              HeroRitualFieldValue(
                fieldDefId: 'field_missing',
                textValue: 'verwaist',
              ),
            ],
          ),
        ],
      );

      final normalized = normalizeRitualCategory(category);

      expect(normalized.ownKnowledge?.name, 'Flueche');
      expect(normalized.ownKnowledge?.learningComplexity, 'E');
      expect(
        normalized.rituals.single.additionalFieldValues.map((value) {
          return value.fieldDefId;
        }).toList(),
        <String>['field_probe'],
      );
    },
  );
}
