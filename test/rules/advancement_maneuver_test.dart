import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_rules.dart';

const _hero = HeroSheet(
  id: 'hero',
  name: 'Held',
  level: 1,
  attributes: Attributes(
    mu: 15,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 15,
    ge: 15,
    ko: 15,
    kk: 15,
  ),
  apAvailable: 1000,
  apTotal: 1000,
  talents: {
    'bow': HeroTalentEntry(talentValue: 15),
    'crossbow': HeroTalentEntry(talentValue: 15),
  },
);
const _catalog = RulesCatalog(
  version: 'test',
  source: 'test',
  weapons: [],
  spells: [],
  talents: [
    TalentDef(
      id: 'bow',
      name: 'Bogen',
      group: 'Kampftalent',
      type: 'fernkampf',
      steigerung: 'C',
      attributes: [],
    ),
    TalentDef(
      id: 'crossbow',
      name: 'Armbrust',
      group: 'Kampftalent',
      type: 'fernkampf',
      steigerung: 'C',
      attributes: [],
    ),
  ],
  maneuvers: [
    ManeuverDef(id: 'man_base', name: 'Grundmanöver', kosten: '100 AP'),
    ManeuverDef(
      id: 'man_next',
      name: 'Folgemanöver',
      kosten: '200 AP',
      voraussetzungenStruktur: [
        SpecialAbilityRequirement(
          art: RequirementArt.manoever,
          name: 'Grundmanöver',
        ),
      ],
    ),
    ManeuverDef(
      id: 'man_sharp',
      name: 'Scharfschütze',
      kosten: '100 AP',
      mussSeparatErlerntWerden: true,
      giltFuerTalentTyp: 'fernkampf',
    ),
    ManeuverDef(
      id: 'man_master',
      name: 'Meisterschütze',
      kosten: '200 AP',
      mussSeparatErlerntWerden: true,
      giltFuerTalentTyp: 'fernkampf',
      voraussetzungenStruktur: [
        SpecialAbilityRequirement(
          art: RequirementArt.manoever,
          name: r'Scharfschütze ($talent)',
        ),
      ],
    ),
  ],
);

HeroAdvancementEntry _entry(String target, int cost) => HeroAdvancementEntry(
  id: target,
  sessionId: 'session',
  createdAt: DateTime.utc(2026),
  kind: AdvancementKind.maneuver,
  targetId: target,
  label: target,
  apCost: cost,
);

void main() {
  test(
    'Manöver werden geplant, geprüft und erst beim Übernehmen historisiert',
    () {
      final first = _entry('man_base', 100);
      final next = _entry('man_next', 200);
      final replay = replayAdvancements(
        base: _hero,
        entries: [first, next],
        catalog: _catalog,
      );
      expect(replay.errors, isEmpty);
      expect(replay.hero.apAvailable, 700);
      expect(replay.hero.combatConfig.specialRules.activeManeuvers, [
        'man_base',
        'man_next',
      ]);
      expect(replay.hero.advancementHistory, isEmpty);
      expect(_hero.combatConfig.specialRules.activeManeuvers, isEmpty);
      final committed = commitAdvancements(
        base: _hero,
        entries: [first, next],
        catalog: _catalog,
      );
      expect(committed.advancementHistory, hasLength(2));
      final removed = replayAdvancements(
        base: _hero,
        entries: [next],
        catalog: _catalog,
      );
      expect(removed.errors, contains('man_next'));
      expect(removed.hero.apAvailable, 1000);
    },
  );

  test('Fernkampf-Voraussetzung gilt für genau das gewählte Talent', () {
    final replay = replayAdvancements(
      base: _hero,
      entries: [
        _entry('man_sharp::bow', 100),
        _entry('man_master::crossbow', 200),
      ],
      catalog: _catalog,
    );
    expect(replay.errors, contains('man_master::crossbow'));
    final valid = replayAdvancements(
      base: _hero,
      entries: [_entry('man_sharp::bow', 100), _entry('man_master::bow', 200)],
      catalog: _catalog,
    );
    expect(valid.errors, isEmpty);
    expect(valid.hero.combatConfig.specialRules.activeManeuvers, [
      'man_sharp::bow',
      'man_master::bow',
    ]);
  });

  test('Doppelte und nicht zum Talent passende Manöver werden abgewiesen', () {
    final replay = replayAdvancements(
      base: _hero,
      entries: [_entry('man_sharp::missing', 100)],
      catalog: _catalog,
    );
    expect(replay.errors, isNotEmpty);
    final owned = replayAdvancements(
      base: _hero,
      entries: [_entry('man_base', 100)],
      catalog: _catalog,
    ).hero;
    expect(
      replayAdvancements(
        base: owned,
        entries: [_entry('man_base', 100)],
        catalog: _catalog,
      ).errors,
      isNotEmpty,
    );
  });

  test('Manöver-Voraussetzungen bleiben im Katalog-Roundtrip erhalten', () {
    final def = _catalog.maneuvers[1];
    final restored = ManeuverDef.fromJson(def.toJson());
    expect(restored.voraussetzungenStruktur.single.name, 'Grundmanöver');
    expect(
      HeroAdvancementEntry.fromJson(_entry('man_base', 100).toJson()).kind,
      AdvancementKind.maneuver,
    );
  });
}
