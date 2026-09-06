import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_se_pools.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/learn/learn_complexity.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_special_ability_state.dart';
import 'package:flutter_test/flutter_test.dart';

const _attributes = Attributes(
  mu: 12,
  kl: 12,
  inn: 12,
  ch: 12,
  ff: 12,
  ge: 12,
  ko: 12,
  kk: 12,
);
const _base = HeroSheet(
  id: 'hero',
  name: 'Held',
  level: 1,
  attributes: _attributes,
  apTotal: 1000,
  apAvailable: 1000,
  attributeSePool: HeroAttributeSePool(mu: 1),
  talents: {
    'climb': HeroTalentEntry(
      talentValue: 3,
      specialExperiences: 1,
      modifier: 2,
      specializations: 'Felsen',
    ),
  },
);
const _catalog = RulesCatalog(
  version: 'test',
  source: 'test',
  weapons: [],
  talents: [
    TalentDef(
      id: 'climb',
      name: 'Klettern',
      group: 'Körper',
      steigerung: 'B',
      attributes: ['MU', 'GE', 'KK'],
    ),
    TalentDef(
      id: 'sword',
      name: 'Schwerter',
      group: 'Kampftalent',
      type: 'nahkampf',
      steigerung: 'E',
      attributes: [],
    ),
  ],
  spells: [
    SpellDef(
      id: 'spell',
      name: 'Zauber',
      tradition: 'Mag',
      steigerung: 'C',
      attributes: ['MU', 'KL', 'IN'],
      availability: 'Mag6',
    ),
  ],
  generalSpecialAbilities: [
    SpecialAbilityDef(id: 'a', name: 'Stufe I', kosten: '100 AP'),
    SpecialAbilityDef(
      id: 'b',
      name: 'Stufe II',
      kosten: '100 AP',
      voraussetzungenStruktur: [
        SpecialAbilityRequirement(
          art: RequirementArt.sonderfertigkeit,
          name: 'Stufe I',
        ),
      ],
    ),
    SpecialAbilityDef(
      id: 'terrain',
      name: 'Geländekunde',
      kosten: '150 AP',
      mehrfachwaehlbar: true,
      varianten: ['Wüste', 'Wald'],
    ),
  ],
  combatSpecialAbilities: [
    CombatSpecialAbilityDef(id: 'ksf_ausweichen_i', name: 'Ausweichen I'),
  ],
  sprachen: [
    SpracheDef(id: 'lang', name: 'Garethi', familie: 'Garethi', maxWert: 18),
  ],
  schriften: [SchriftDef(id: 'script', name: 'Kusliker Zeichen', maxWert: 10)],
);

HeroAdvancementEntry _entry(
  String id,
  AdvancementKind kind,
  String target, {
  int? from,
  int? to,
  int cost = 10,
  int se = 0,
  Map<String, String> options = const {},
}) => HeroAdvancementEntry(
  id: id,
  sessionId: 'session',
  createdAt: DateTime.utc(2026),
  kind: kind,
  targetId: target,
  label: target,
  fromValue: from,
  toValue: to,
  apCost: cost,
  seSpent: se,
  options: options,
);

void main() {
  test('replay reserves AP and consumes SE without appending history', () {
    final entry = _entry(
      'one',
      AdvancementKind.talent,
      'climb',
      from: 3,
      to: 5,
      cost: 20,
      se: 1,
    );
    final result = replayAdvancements(
      base: _base,
      entries: [entry],
      catalog: _catalog,
    );
    expect(result.errors, isEmpty);
    expect(result.apReserved, 20);
    expect(result.hero.apAvailable, 980);
    expect(result.hero.apSpent, 20);
    expect(result.hero.talents['climb']!.talentValue, 5);
    expect(result.hero.talents['climb']!.specialExperiences, 0);
    expect(result.hero.talents['climb']!.modifier, 2);
    expect(result.hero.talents['climb']!.specializations, 'Felsen');
    expect(result.hero.advancementHistory, isEmpty);
    expect(_base.talents['climb']!.talentValue, 3);
  });

  test(
    'removal invalidates dependent value but preserves independent entries',
    () {
      final next = _entry(
        'next',
        AdvancementKind.talent,
        'climb',
        from: 4,
        to: 5,
      );
      final independent = _entry(
        'other',
        AdvancementKind.attribute,
        'mu',
        from: 12,
        to: 13,
        se: 1,
      );
      final result = replayAdvancements(
        base: _base,
        entries: [next, independent],
        catalog: _catalog,
      );
      expect(result.errors.keys, ['next']);
      expect(result.hero.talents['climb']!.talentValue, 3);
      expect(result.hero.attributes.mu, 13);
      expect(result.hero.attributeSePool.mu, 0);
      expect(result.apReserved, 10);
    },
  );

  test(
    'rejects overspending AP, SE, decreasing values and exceeding maxima',
    () {
      for (final entry in [
        _entry(
          'ap',
          AdvancementKind.talent,
          'climb',
          from: 3,
          to: 4,
          cost: 1001,
        ),
        _entry('se', AdvancementKind.talent, 'climb', from: 3, to: 5, se: 2),
        _entry('down', AdvancementKind.talent, 'climb', from: 3, to: 2),
        _entry('max', AdvancementKind.talent, 'climb', from: 3, to: 16),
        _entry(
          'negative',
          AdvancementKind.talent,
          'climb',
          from: 3,
          to: 4,
          cost: -1,
        ),
      ]) {
        final result = replayAdvancements(
          base: _base,
          entries: [entry],
          catalog: _catalog,
        );
        expect(result.errors, contains(entry.id));
        expect(result.apReserved, 0);
        expect(result.hero.talents['climb']!.specialExperiences, 1);
      }
    },
  );

  test(
    'SF requirements replay sequentially and honor explicit Meisterentscheid',
    () {
      final first = _entry('first', AdvancementKind.generalAbility, 'a');
      final second = _entry('second', AdvancementKind.generalAbility, 'b');
      final valid = replayAdvancements(
        base: _base,
        entries: [first, second],
        catalog: _catalog,
      );
      expect(valid.errors, isEmpty);
      final invalid = replayAdvancements(
        base: _base,
        entries: [second],
        catalog: _catalog,
      );
      expect(invalid.errors, contains('second'));
      final override = _entry(
        'master',
        AdvancementKind.generalAbility,
        'b',
        options: {'meisterentscheid': 'true'},
      );
      expect(
        replayAdvancements(
          base: _base,
          entries: [override],
          catalog: _catalog,
        ).errors,
        isEmpty,
      );
      expect(
        () => commitAdvancements(
          base: _base,
          entries: [second],
          catalog: _catalog,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'commit records exactly valid commands and rejects historical duplicates',
    () {
      final entry = _entry('first', AdvancementKind.generalAbility, 'a');
      final committed = commitAdvancements(
        base: _base,
        entries: [entry],
        catalog: _catalog,
      );
      expect(committed.advancementHistory.single.id, entry.id);
      expect(committed.apSpent, 10);
      expect(
        () => commitAdvancements(
          base: committed,
          entries: [entry],
          catalog: _catalog,
        ),
        throwsStateError,
      );
    },
  );

  test('activation preserves spell modifiers and records representation', () {
    final hero = _base.copyWith(
      representationen: ['Mag'],
      spells: {'spell': const HeroSpellEntry(modifier: 3, hauszauber: true)},
    );
    final entry = _entry(
      'spell',
      AdvancementKind.spell,
      'spell',
      from: -1,
      to: 0,
      options: {'learnedRepresentation': 'Mag', 'learnedTradition': 'Mag'},
    );
    final result = replayAdvancements(
      base: hero,
      entries: [entry],
      catalog: _catalog,
    );
    expect(result.errors, isEmpty);
    expect(result.hero.spells['spell']!.spellValue, 0);
    expect(result.hero.spells['spell']!.modifier, 3);
    expect(result.hero.spells['spell']!.hauszauber, isTrue);
    expect(result.hero.spells['spell']!.learnedRepresentation, 'Mag');
  });

  test('activation unhides talent and distributes combat points', () {
    final hero = _base.copyWith(hiddenTalentIds: ['sword']);
    final entry = _entry(
      'sword',
      AdvancementKind.talent,
      'sword',
      from: -1,
      to: 3,
      options: {'atDelta': '2'},
    );
    final result = replayAdvancements(
      base: hero,
      entries: [entry],
      catalog: _catalog,
    );
    expect(result.errors, isEmpty);
    expect(result.hero.hiddenTalentIds, isEmpty);
    expect(result.hero.talents['sword']!.atValue, 2);
    expect(result.hero.talents['sword']!.paValue, 1);
  });

  test('SF variants reject duplicates and combat abilities update dedicated fields', () {
    final first = _entry(
      'first',
      AdvancementKind.generalAbility,
      'terrain',
      options: {'variant': 'Wüste'},
    );
    final duplicate = _entry(
      'duplicate',
      AdvancementKind.generalAbility,
      'terrain',
      options: {'variant': 'Wüste'},
    );
    final combat = _entry(
      'combat',
      AdvancementKind.combatAbility,
      'ksf_ausweichen_i',
    );
    final result = replayAdvancements(
      base: _base,
      entries: [first, duplicate, combat],
      catalog: _catalog,
    );
    expect(result.errors.keys, ['duplicate']);
    expect(
      result.hero.talentSpecialAbilities.single.name,
      'Geländekunde (Wüste)',
    );
    expect(
      isCombatSpecialAbilityActive(
        result.hero.combatConfig,
        'ksf_ausweichen_i',
      ),
      isTrue,
    );
  });

  test(
    'options retain all former numeric advancement kinds and language family',
    () {
      final hero = _base.copyWith(muttersprache: 'lang');
      final options = buildAdvancementOptions(hero: hero, catalog: _catalog);
      expect(
        options.map((o) => o.kind),
        containsAll([
          AdvancementKind.boughtStat,
          AdvancementKind.language,
          AdvancementKind.script,
        ]),
      );
      final language = resolveAdvancementOption(
        hero: hero,
        catalog: _catalog,
        kind: AdvancementKind.language,
        targetId: 'lang',
      );
      expect(language!.learnCost, LearnCost.a);
      final entries = [
        _entry('stat', AdvancementKind.boughtStat, 'lep', from: 0, to: 1),
        _entry('lang', AdvancementKind.language, 'lang', from: -1, to: 1),
        _entry('script', AdvancementKind.script, 'script', from: -1, to: 1),
      ];
      final result = replayAdvancements(
        base: hero,
        entries: entries,
        catalog: _catalog,
      );
      expect(result.errors, isEmpty);
      expect(result.hero.bought.lep, 1);
      expect(result.hero.sprachen['lang']!.wert, 1);
      expect(result.hero.schriften['script']!.wert, 1);
    },
  );
}
