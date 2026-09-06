import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_language_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_rules.dart';
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

const _hero = HeroSheet(
  id: 'hero',
  name: 'Held',
  level: 1,
  attributes: _attributes,
  apTotal: 5000,
  apAvailable: 5000,
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
      id: 'swim',
      name: 'Schwimmen',
      group: 'Körper',
      steigerung: 'B',
      attributes: ['MU', 'GE', 'KK'],
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
  sprachen: [
    SpracheDef(id: 'lang', name: 'Garethi', familie: 'Garethi', maxWert: 18),
  ],
  schriften: [SchriftDef(id: 'script', name: 'Kusliker Zeichen', maxWert: 10)],
  generalSpecialAbilities: [
    // Kette mit drei Stufen; nur die naechste fehlende darf im aktiven
    // Umfang erscheinen.
    SpecialAbilityDef(
      id: 'will1',
      name: 'Eiserner Wille I',
      kosten: '100 AP',
      kette: SpecialAbilityChainRef(
        id: 'wille',
        stufe: 1,
        label: 'Eiserner Wille',
      ),
      aliasNamen: ['Eiserner Wille I / II'],
    ),
    SpecialAbilityDef(
      id: 'will2',
      name: 'Eiserner Wille II',
      kosten: '200 AP',
      kette: SpecialAbilityChainRef(
        id: 'wille',
        stufe: 2,
        label: 'Eiserner Wille',
      ),
    ),
    SpecialAbilityDef(
      id: 'will3',
      name: 'Eiserner Wille III',
      kosten: '300 AP',
      kette: SpecialAbilityChainRef(
        id: 'wille',
        stufe: 3,
        label: 'Eiserner Wille',
      ),
    ),
    // Unangetastete Kette: gehoert vollstaendig ins Erwerbsblatt.
    SpecialAbilityDef(
      id: 'reg1',
      name: 'Regeneration I',
      kosten: '100 AP',
      kette: SpecialAbilityChainRef(id: 'regeneration', stufe: 1),
    ),
    SpecialAbilityDef(
      id: 'reg2',
      name: 'Regeneration II',
      kosten: '200 AP',
      kette: SpecialAbilityChainRef(id: 'regeneration', stufe: 2),
    ),
    SpecialAbilityDef(
      id: 'terrain',
      name: 'Geländekunde',
      kosten: '150 AP',
      mehrfachwaehlbar: true,
      varianten: ['Wüste', 'Wald'],
      apErstwerb: 150,
      apFolgeerwerb: 75,
    ),
  ],
);

List<AdvancementOption> _options(HeroSheet hero, AdvancementScope scope) =>
    buildAdvancementOptions(hero: hero, catalog: _catalog, scope: scope);

AdvancementOption? _find(
  List<AdvancementOption> options,
  AdvancementKind kind,
  String targetId,
) => options
    .where((option) => option.kind == kind && option.targetId == targetId)
    .firstOrNull;

void main() {
  test('eingeblendete Werte ohne Wert gelten als aktiv', () {
    final hero = _hero.copyWith(
      representationen: ['Mag'],
      talents: {'climb': const HeroTalentEntry()},
      spells: {'spell': const HeroSpellEntry()},
      sprachen: {'lang': const HeroLanguageEntry()},
    );
    final active = _options(hero, AdvancementScope.active);
    for (final (kind, id) in [
      (AdvancementKind.talent, 'climb'),
      (AdvancementKind.spell, 'spell'),
      (AdvancementKind.language, 'lang'),
    ]) {
      final option = _find(active, kind, id);
      expect(option, isNotNull, reason: '$kind $id fehlt im aktiven Umfang');
      expect(option!.isOwned, isTrue);
      expect(option.currentValue, -1);
      expect(option.unavailableReason, isNull);
    }
    // Nicht gefuehrte Ziele bleiben aussen vor.
    expect(_find(active, AdvancementKind.talent, 'swim'), isNull);
    expect(_find(active, AdvancementKind.script, 'script'), isNull);
  });

  test('Eigenschaften und Grundwerte sind immer aktiv, nie erwerbbar', () {
    final active = _options(_hero, AdvancementScope.active);
    final inactive = _options(_hero, AdvancementScope.inactive);
    expect(_find(active, AdvancementKind.attribute, 'mu')!.isOwned, isTrue);
    expect(_find(active, AdvancementKind.boughtStat, 'lep')!.isOwned, isTrue);
    expect(
      inactive.any(
        (option) =>
            option.kind == AdvancementKind.attribute ||
            option.kind == AdvancementKind.boughtStat,
      ),
      isFalse,
    );
  });

  test('aktiver und inaktiver Umfang ergeben zusammen den ganzen Katalog', () {
    final hero = _hero.copyWith(
      talents: {'climb': const HeroTalentEntry(talentValue: 4)},
      talentSpecialAbilities: [
        const TalentSpecialAbility(name: 'Eiserner Wille I'),
      ],
    );
    String key(AdvancementOption option) =>
        '${option.kind.name}:${option.targetId}';
    final all = _options(hero, AdvancementScope.all).map(key).toSet();
    final active = _options(hero, AdvancementScope.active).map(key).toSet();
    final inactive = _options(hero, AdvancementScope.inactive).map(key).toSet();
    // Die naechste Kettenstufe steht im aktiven Umfang und trotzdem im
    // Erwerbsblatt-Gegenstueck nicht doppelt: sie ist dort schlicht nicht
    // ausgeschlossen, weil sie noch nicht erworben ist.
    expect(active.union(inactive), all);
    expect(active.intersection(inactive), {'generalAbility:will2'});
  });

  test('nur die naechste Stufe einer begonnenen Kette ist handlungsfähig', () {
    final hero = _hero.copyWith(
      talentSpecialAbilities: [
        const TalentSpecialAbility(name: 'Eiserner Wille I'),
      ],
    );
    final active = _options(hero, AdvancementScope.active);
    final stufe1 = _find(active, AdvancementKind.generalAbility, 'will1');
    expect(stufe1, isNotNull);
    expect(stufe1!.isOwned, isTrue);
    expect(stufe1.unavailableReason, 'Bereits erworben');
    final stufe2 = _find(active, AdvancementKind.generalAbility, 'will2');
    expect(stufe2, isNotNull);
    expect(stufe2!.isOwned, isFalse);
    expect(stufe2.unavailableReason, isNull);
    expect(_find(active, AdvancementKind.generalAbility, 'will3'), isNull);
    // Eine unangetastete Kette bleibt vollstaendig im Erwerbsblatt.
    expect(_find(active, AdvancementKind.generalAbility, 'reg1'), isNull);
    final inactive = _options(hero, AdvancementScope.inactive);
    expect(_find(inactive, AdvancementKind.generalAbility, 'reg1'), isNotNull);
    expect(_find(inactive, AdvancementKind.generalAbility, 'reg2'), isNotNull);
  });

  test('Alias-Namen zählen als erworben und sperren den Doppelerwerb', () {
    final hero = _hero.copyWith(
      talentSpecialAbilities: [
        const TalentSpecialAbility(name: 'Eiserner Wille I / II'),
      ],
    );
    final active = _options(hero, AdvancementScope.active);
    final stufe1 = _find(active, AdvancementKind.generalAbility, 'will1');
    expect(stufe1, isNotNull);
    expect(stufe1!.isOwned, isTrue);
    expect(stufe1.unavailableReason, 'Bereits erworben');
  });

  test(
    'mehrfach wählbare SF bleibt nach der ersten Variante handlungsfähig',
    () {
      final hero = _hero.copyWith(
        talentSpecialAbilities: [
          const TalentSpecialAbility(name: 'Geländekunde (Wüste)'),
        ],
      );
      final option = _find(
        _options(hero, AdvancementScope.active),
        AdvancementKind.generalAbility,
        'terrain',
      );
      expect(option, isNotNull);
      expect(option!.isOwned, isTrue);
      expect(option.ownedCount, 1);
      expect(option.unavailableReason, isNull);
      expect(option.apCost, 75);
      // Mit gewaehlter Variante gilt weiterhin der Einzelabgleich.
      final belegt = resolveAdvancementOption(
        hero: hero,
        catalog: _catalog,
        kind: AdvancementKind.generalAbility,
        targetId: 'terrain',
        options: const {'variant': 'Wüste'},
      );
      expect(belegt!.unavailableReason, 'Bereits erworben');
    },
  );

  test('Aktivierung auf 0 verrechnet die Aktivierungskosten', () {
    final entry = HeroAdvancementEntry(
      id: 'entry',
      sessionId: 'session',
      createdAt: DateTime.utc(2026),
      kind: AdvancementKind.talent,
      targetId: 'climb',
      label: 'Klettern',
      fromValue: -1,
      toValue: 0,
      // Lernkomplexitaet B: initialStepCost = 10.
      apCost: 10,
    );
    final replay = replayAdvancements(
      base: _hero,
      entries: [entry],
      catalog: _catalog,
    );
    expect(replay.errors, isEmpty);
    expect(replay.hero.talents['climb']!.talentValue, 0);
    expect(replay.apReserved, 10);
    expect(replay.hero.apAvailable, 4990);
    // Erst danach steht das Talent im aktiven Umfang.
    final option = _find(
      _options(replay.hero, AdvancementScope.active),
      AdvancementKind.talent,
      'climb',
    );
    expect(option!.isOwned, isTrue);
    expect(option.currentValue, 0);
  });
}
