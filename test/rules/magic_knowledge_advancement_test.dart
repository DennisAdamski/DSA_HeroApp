import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_status_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_magic_knowledge_rules.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';

HeroAdvancementEntry step(
  String id,
  AdvancementKind kind,
  String target,
  int cost, {
  int? from,
  int? to,
  Map<String, String> options = const {},
}) => HeroAdvancementEntry(
  id: id,
  sessionId: 's',
  createdAt: DateTime.utc(2026),
  kind: kind,
  targetId: target,
  label: target,
  apCost: cost,
  fromValue: from,
  toValue: to,
  options: options,
);

const catalog = RulesCatalog(
  version: 'test',
  source: 'test',
  weapons: [],
  talents: [],
  spells: [],
);
const hero = HeroSheet(
  id: 'h',
  name: 'Held',
  level: 1,
  attributes: Attributes.zero(),
);
void main() {
  const integrationCatalog = RulesCatalog(
    version: 'integration',
    source: 'test',
    weapons: [],
    talents: [],
    spells: [
      SpellDef(
        id: 'newSpell',
        name: 'Illusion',
        tradition: 'Srl',
        steigerung: 'B',
        availability: 'Srl7',
        attributes: ['MU', 'KL', 'IN'],
      ),
    ],
    magicSpecialAbilities: [
      SpecialAbilityDef(
        id: 'ritual',
        name: 'Neues Ritual',
        kosten: '100 AP',
        voraussetzungenStruktur: [
          SpecialAbilityRequirement(
            art: RequirementArt.ritualkenntnis,
            name: 'Gildenmagie',
            min: 4,
          ),
        ],
      ),
    ],
  );
  final magical = hero.copyWith(
    apAvailable: 10000,
    vorteileText: 'Vollzauberer',
    attributes: const Attributes(
      mu: 15,
      kl: 18,
      inn: 15,
      ch: 15,
      ff: 15,
      ge: 15,
      ko: 15,
      kk: 15,
    ),
    representationen: ['Mag'],
    spells: {
      'one': const HeroSpellEntry(spellValue: 50, learnedRepresentation: 'Srl'),
    },
  );
  const confirmation = {
    'teacherConfirmed': 'true',
    'trainingYearConfirmed': 'true',
  };
  test('ritual acquisition sees a planned RkW and loses it when the parent step is removed', () {
    final activation = step(
      'activate',
      AdvancementKind.ritualKnowledge,
      'gildenmagier',
      250,
      from: -1,
      to: 3,
      options: {'permissionConfirmed': 'true'},
    );
    final preview = replayAdvancements(
      base: magical,
      entries: [activation],
      catalog: integrationCatalog,
    );
    final option = resolveMagicKnowledge(
      AdvancementContext(hero: preview.hero, catalog: integrationCatalog),
      AdvancementKind.ritualKnowledge,
      'gildenmagier',
      {'targetValue': '4'},
    )!;
    final raise = step(
      'raise',
      AdvancementKind.ritualKnowledge,
      'gildenmagier',
      option.apCost!,
      from: 3,
      to: 4,
      options: {'bookConfirmed': 'true'},
    );
    final ritual = step('ritual', AdvancementKind.magicAbility, 'ritual', 100);
    final entries = [activation, raise, ritual];
    final all = replayAdvancements(
      base: magical,
      entries: entries,
      catalog: integrationCatalog,
    );
    expect(all.errors, isEmpty);
    expect(all.hero.magicSpecialAbilities.single.name, 'Neues Ritual');
    final withoutRaise = replayAdvancements(
      base: magical,
      entries: [activation, ritual],
      catalog: integrationCatalog,
    );
    expect(withoutRaise.errors.keys, contains('ritual'));
    final saved = commitAdvancements(
      base: magical,
      entries: entries,
      catalog: integrationCatalog,
    );
    expect(saved.advancementHistory.length, 3);
    expect(saved.apAvailable, magical.apAvailable - all.apReserved);
    expect(
      () => commitAdvancements(
        base: saved,
        entries: entries,
        catalog: integrationCatalog,
      ),
      throwsStateError,
    );
  });
  test('planned representation unlocks regular spell acquisition and removes foreign surcharge', () {
    final before = resolveAdvancementOption(
      hero: magical,
      catalog: integrationCatalog,
      kind: AdvancementKind.spell,
      targetId: 'newSpell',
      options: {'learnedRepresentation': 'Mag', 'learnedTradition': 'Srl'},
    )!;
    final repr = step(
      'repr',
      AdvancementKind.representation,
      'Srl',
      1000,
      options: confirmation,
    );
    final preview = replayAdvancements(
      base: magical,
      entries: [repr],
      catalog: integrationCatalog,
    );
    expect(preview.errors, isEmpty);
    final after = resolveAdvancementOption(
      hero: preview.hero,
      catalog: integrationCatalog,
      kind: AdvancementKind.spell,
      targetId: 'newSpell',
      options: {'learnedRepresentation': 'Srl', 'learnedTradition': 'Srl'},
    )!;
    expect(before.complexityHint, 'Lernkomplexität D');
    expect(after.complexityHint, 'Lernkomplexität B');
    final spell = step(
      'spell',
      AdvancementKind.spell,
      'newSpell',
      10,
      from: -1,
      to: 0,
      options: {'learnedRepresentation': 'Srl', 'learnedTradition': 'Srl'},
    );
    expect(
      replayAdvancements(
        base: magical,
        entries: [repr, spell],
        catalog: integrationCatalog,
      ).errors,
      isEmpty,
    );
    expect(
      replayAdvancements(
        base: magical,
        entries: [spell],
        catalog: integrationCatalog,
      ).errors.keys,
      contains('spell'),
    );
  });
  test(
    'representation rebates are directional and use best applicable price',
    () {
      expect(representationDiscount({'Mag'}, 'Srl'), .5);
      expect(representationDiscount({'Srl'}, 'Mag'), .75);
      expect(representationDiscount({'Bor'}, 'Mag'), 1);
      expect(representationDiscount({'Dru'}, 'Geo'), .75);
    },
  );
  test('preview acquires second representation and commits exactly once', () {
    final command = step(
      'repr',
      AdvancementKind.representation,
      'Srl',
      1000,
      options: confirmation,
    );
    final preview = replayAdvancements(
      base: magical,
      entries: [command],
      catalog: catalog,
    );
    expect(preview.errors, isEmpty);
    expect(preview.hero.representationen, ['Mag', 'Srl']);
    expect(preview.hero.repraesentationsTraditionen['Srl'], 'scharlatan');
    expect(preview.hero.apAvailable, 9000);
    expect(magical.representationen, ['Mag']);
    expect(preview.hero.advancementHistory, isEmpty);
    final saved = commitAdvancements(
      base: magical,
      entries: [command],
      catalog: catalog,
    );
    expect(saved.advancementHistory.single.id, 'repr');
    expect(
      replayAdvancements(
        base: saved,
        entries: [command],
        catalog: catalog,
      ).errors,
      isNotEmpty,
    );
  });
  test('missing prerequisites need documented override and cost changes remain explicit', () {
    final noPoints = magical.copyWith(spells: {});
    final invalid = step(
      'repr',
      AdvancementKind.representation,
      'Srl',
      0,
      options: {...confirmation, 'meisterentscheid': 'true'},
    );
    expect(
      replayAdvancements(
        base: noPoints,
        entries: [invalid],
        catalog: catalog,
      ).errors,
      isNotEmpty,
    );
    final valid = step(
      'repr',
      AdvancementKind.representation,
      'Srl',
      0,
      options: {
        ...confirmation,
        'meisterentscheid': 'true',
        'meisterentscheidReason': 'Meisterfreigabe',
        'customApCost': '0',
      },
    );
    expect(
      replayAdvancements(
        base: noPoints,
        entries: [valid],
        catalog: catalog,
      ).errors,
      isEmpty,
    );
  });
  test('first acquired representation cannot silently receive profession zero cost', () {
    final first = step(
      'r',
      AdvancementKind.representation,
      'Mag',
      0,
      options: confirmation,
    );
    expect(
      replayAdvancements(
        base: magical.copyWith(representationen: []),
        entries: [first],
        catalog: catalog,
      ).errors,
      isNotEmpty,
    );
  });
  test('ritual activation and raise replay sequentially and removal invalidates raise', () {
    final activation = step(
      'a',
      AdvancementKind.ritualKnowledge,
      'gildenmagier',
      250,
      from: -1,
      to: 3,
      options: {'permissionConfirmed': 'true'},
    );
    final activated = replayAdvancements(
      base: magical,
      entries: [activation],
      catalog: catalog,
    );
    expect(activated.errors, isEmpty);
    final option = resolveMagicKnowledge(
      AdvancementContext(hero: activated.hero, catalog: catalog),
      AdvancementKind.ritualKnowledge,
      'gildenmagier',
      {'targetValue': '4'},
    )!;
    final raise = step(
      'b',
      AdvancementKind.ritualKnowledge,
      'gildenmagier',
      option.apCost!,
      from: 3,
      to: 4,
      options: {'bookConfirmed': 'true'},
    );
    final both = replayAdvancements(
      base: magical,
      entries: [activation, raise],
      catalog: catalog,
    );
    expect(both.errors, isEmpty);
    expect(both.hero.ritualKnowledge['gildenmagier']!.value, 4);
    expect(
      replayAdvancements(
        base: magical,
        entries: [raise],
        catalog: catalog,
      ).errors,
      isNotEmpty,
    );
  });
  test('free recording uses chosen start value and does not silently merge legacy groups', () {
    final legacy = magical.copyWith(
      ritualCategories: [
        const HeroRitualCategory(
          id: 'legacy',
          name: 'Stabzauber',
          knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
          ownKnowledge: HeroRitualKnowledge(name: 'Stabzauber', value: 9),
        ),
      ],
    );
    final command = step(
      'a',
      AdvancementKind.ritualKnowledge,
      'gildenmagier',
      0,
      from: -1,
      to: 7,
      options: {'source': 'creation', 'startValue': '7'},
    );
    final result = replayAdvancements(
      base: legacy,
      entries: [command],
      catalog: catalog,
    );
    expect(result.errors, isEmpty);
    expect(result.apReserved, 0);
    expect(result.hero.ritualKnowledge['gildenmagier']!.value, 7);
    expect(result.hero.ritualCategories.single.ownKnowledge!.value, 9);
  });
  test('magic UI activation alone never supplies a caster status', () {
    expect(detectMagicStatus(hero, catalog), isNull);
  });
  test(
    'recorded representation clarifies unknown or conflicting caster status',
    () {
      final unknown = magical.copyWith(vorteileText: '', representationen: []);
      final command = step(
        'r',
        AdvancementKind.representation,
        'Mag',
        0,
        options: {'source': 'creation'},
      );
      expect(
        replayAdvancements(
          base: unknown,
          entries: [command],
          catalog: catalog,
        ).errors,
        isNotEmpty,
      );
      final confirmed = step(
        'r',
        AdvancementKind.representation,
        'Mag',
        0,
        options: {'source': 'creation', 'magicStatus': 'full'},
      );
      expect(
        replayAdvancements(
          base: unknown,
          entries: [confirmed],
          catalog: catalog,
        ).errors,
        isEmpty,
      );
      final conflict = unknown.copyWith(
        vorteileText: 'Vollzauberer; Halbzauberer',
      );
      expect(
        replayAdvancements(
          base: conflict,
          entries: [command],
          catalog: catalog,
        ).errors,
        isNotEmpty,
      );
      expect(
        replayAdvancements(
          base: conflict,
          entries: [confirmed],
          catalog: catalog,
        ).errors,
        isEmpty,
      );
    },
  );
  test('foreign ritual acquisition clarifies unknown status and quarter restrictions', () {
    final command = step(
      'rk',
      AdvancementKind.ritualKnowledge,
      'scharlatan',
      250,
      from: -1,
      to: 3,
      options: {'permissionConfirmed': 'true'},
    );
    for (final status in ['', 'Viertelzauberer']) {
      final base = magical.copyWith(vorteileText: status);
      expect(
        replayAdvancements(
          base: base,
          entries: [command],
          catalog: catalog,
        ).errors,
        isNotEmpty,
      );
    }
    final allowed = step(
      'rk',
      AdvancementKind.ritualKnowledge,
      'scharlatan',
      250,
      from: -1,
      to: 3,
      options: {'permissionConfirmed': 'true', 'magicStatus': 'half'},
    );
    expect(
      replayAdvancements(
        base: magical.copyWith(vorteileText: ''),
        entries: [allowed],
        catalog: catalog,
      ).errors,
      isEmpty,
    );
  });
  test('book confirmation alone cannot claim a teacher discount', () {
    final base = magical.copyWith(
      ritualKnowledge: {
        'gildenmagier': const HeroRitualKnowledge(name: 'Gildenmagie'),
      },
    );
    final resolved = resolveMagicKnowledge(
      AdvancementContext(hero: base, catalog: catalog),
      AdvancementKind.ritualKnowledge,
      'gildenmagier',
      {'targetValue': '4', 'learningMethod': 'teacher'},
    )!;
    final command = step(
      'rk',
      AdvancementKind.ritualKnowledge,
      'gildenmagier',
      resolved.apCost!,
      from: 3,
      to: 4,
      options: {'bookConfirmed': 'true', 'learningMethod': 'teacher'},
    );
    expect(
      replayAdvancements(
        base: base,
        entries: [command],
        catalog: catalog,
      ).errors,
      isNotEmpty,
    );
  });
  test('foreign representation raises ritual learning by two columns', () {
    final own = magical.copyWith(
      ritualKnowledge: {
        'gildenmagier': const HeroRitualKnowledge(name: 'Gildenmagie'),
        'scharlatan': const HeroRitualKnowledge(
          name: 'Scharlatanerie',
          learningComplexity: 'D',
        ),
      },
    );
    final context = AdvancementContext(hero: own, catalog: catalog);
    expect(
      resolveMagicKnowledge(
        context,
        AdvancementKind.ritualKnowledge,
        'gildenmagier',
        const {},
      )!.complexityHint,
      'Lernkomplexität E',
    );
    expect(
      resolveMagicKnowledge(
        context,
        AdvancementKind.ritualKnowledge,
        'scharlatan',
        const {},
      )!.complexityHint,
      'Lernkomplexität F',
    );
    expect(
      resolveMagicKnowledge(
        AdvancementContext(
          hero: own.copyWith(representationen: ['Mag', 'Srl']),
          catalog: catalog,
        ),
        AdvancementKind.ritualKnowledge,
        'scharlatan',
        const {},
      )!.complexityHint,
      'Lernkomplexität D',
    );
  });
  test('epic acquisition ban applies to further representations not ritual knowledge', () {
    final epic = magical.copyWith(isEpisch: true);
    final repr = step(
      'r',
      AdvancementKind.representation,
      'Srl',
      1000,
      options: confirmation,
    );
    expect(
      replayAdvancements(base: epic, entries: [repr], catalog: catalog).errors,
      isNotEmpty,
    );
    final ritual = step(
      'rk',
      AdvancementKind.ritualKnowledge,
      'alchimist',
      250,
      from: -1,
      to: 3,
      options: {'permissionConfirmed': 'true'},
    );
    expect(
      replayAdvancements(
        base: epic,
        entries: [ritual],
        catalog: catalog,
      ).errors,
      isEmpty,
    );
  });
  test('effective advantages distinguish full half quarter and conflicts', () {
    expect(
      detectMagicStatus(hero.copyWith(vorteileText: 'Vollzauberer'), catalog),
      'full',
    );
    expect(
      detectMagicStatus(hero.copyWith(vorteileText: 'Halbzauberer'), catalog),
      'half',
    );
    expect(
      detectMagicStatus(
        hero.copyWith(vorteileText: 'Viertelzauberer'),
        catalog,
      ),
      'quarter',
    );
    expect(
      detectMagicStatus(
        hero.copyWith(vorteileText: 'Vollzauberer; Halbzauberer'),
        catalog,
      ),
      isNull,
    );
  });
}
