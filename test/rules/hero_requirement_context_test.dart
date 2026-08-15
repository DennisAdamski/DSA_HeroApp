import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/magic_special_ability.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_requirement_context.dart';
import 'package:dsa_heldenverwaltung/rules/derived/requirement_evaluation_rules.dart';

void main() {
  const catalog = RulesCatalog(
    version: 'test',
    source: 'test',
    talents: <TalentDef>[
      TalentDef(
        id: 'tal_magiekunde',
        name: 'Magiekunde',
        group: 'Wissen',
        steigerung: 'B',
        attributes: <String>['KL', 'KL', 'IN'],
      ),
    ],
    spells: <SpellDef>[
      SpellDef(
        id: 'spell_arcanovi',
        name: 'ARCANOVI',
        tradition: 'Mag',
        steigerung: 'C',
        attributes: <String>['KL', 'FF', 'KK'],
      ),
    ],
    weapons: <WeaponDef>[],
  );

  HeroSheet buildHero() {
    return const HeroSheet(
      id: 'h1',
      name: 'Alrik',
      level: 8,
      attributes: Attributes(
        mu: 15,
        kl: 16,
        inn: 13,
        ch: 12,
        ff: 12,
        ge: 11,
        ko: 12,
        kk: 10,
      ),
      representationen: <String>['Mag'],
      merkmalskenntnisse: <String>['Antimagie'],
      magicSpecialAbilities: <MagicSpecialAbility>[
        MagicSpecialAbility(name: 'Eiserner Wille I'),
      ],
      talentSpecialAbilities: <TalentSpecialAbility>[
        TalentSpecialAbility(name: 'Kulturkunde (Novadi)'),
      ],
      talents: <String, HeroTalentEntry>{
        'tal_magiekunde': HeroTalentEntry(talentValue: 12),
      },
      spells: <String, HeroSpellEntry>{
        'spell_arcanovi': HeroSpellEntry(spellValue: 14),
      },
      ritualCategories: <HeroRitualCategory>[
        HeroRitualCategory(
          id: 'cat_gildenmagie',
          name: 'Gildenmagie',
          knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
          ownKnowledge: HeroRitualKnowledge(name: 'Gildenmagie', value: 9),
        ),
      ],
      vorteileText: 'Zweistimmiger Gesang, Astrale Regeneration',
      nachteileText: 'Unstet',
    );
  }

  test('uebernimmt die Eigenschaften des Helden', () {
    final context = buildHeroRequirementContext(buildHero(), catalog: catalog);

    expect(context.eigenschaften['MU'], 15);
    expect(context.eigenschaften['IN'], 13);
    expect(context.eigenschaften['KK'], 10);
  });

  test('sammelt allgemeine und magische Sonderfertigkeiten', () {
    final context = buildHeroRequirementContext(buildHero(), catalog: catalog);

    expect(context.sonderfertigkeiten, contains('Eiserner Wille I'));
    expect(context.sonderfertigkeiten, contains('Kulturkunde (Novadi)'));
  });

  test('loest Talent- und Zauber-IDs in Klarnamen auf', () {
    final context = buildHeroRequirementContext(buildHero(), catalog: catalog);

    expect(context.talentwerte['Magiekunde'], 12);
    expect(context.zauberwerte['ARCANOVI'], 14);
  });

  test('leitet Tradition und Leiteigenschaft aus der Repraesentation ab', () {
    final context = buildHeroRequirementContext(buildHero(), catalog: catalog);

    expect(context.traditionen.map((t) => t.id), <String>['gildenmagier']);
    expect(context.leiteigenschaften, <String>{'KL'});
    expect(context.istSpruchzauberer, isTrue);
  });

  test('liest Ritualkenntnisse mit ihrem Wert', () {
    final context = buildHeroRequirementContext(buildHero(), catalog: catalog);

    expect(context.ritualkenntnisse['Gildenmagie'], 9);
  });

  test('zerlegt Vor- und Nachteilstexte in Fragmente', () {
    final context = buildHeroRequirementContext(buildHero(), catalog: catalog);

    expect(context.vorteile, contains('Zweistimmiger Gesang'));
    expect(context.nachteile, contains('Unstet'));
  });

  test('prueft Gedankenschutz gegen einen echten Helden', () {
    final context = buildHeroRequirementContext(buildHero(), catalog: catalog);
    const gedankenschutz = <SpecialAbilityRequirement>[
      SpecialAbilityRequirement(
        art: RequirementArt.eigenschaft,
        code: 'MU',
        min: 15,
      ),
      SpecialAbilityRequirement(
        art: RequirementArt.eigenschaft,
        code: 'IN',
        min: 13,
      ),
      SpecialAbilityRequirement(
        art: RequirementArt.sonderfertigkeit,
        name: 'Eiserner Wille',
        stufe: 1,
      ),
    ];

    final ergebnisse = evaluateRequirements(gedankenschutz, context);

    expect(alleVoraussetzungenErfuellt(ergebnisse), isTrue);
  });

  test('ohne Katalog bleiben Talent- und Zauberwerte unaufgeloest', () {
    final context = buildHeroRequirementContext(buildHero());

    expect(context.talentwerte.containsKey('Magiekunde'), isFalse);
    expect(context.talentwerte['tal_magiekunde'], 12);
  });
}
