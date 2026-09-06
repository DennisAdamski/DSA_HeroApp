import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_impact_rules.dart';

const _attrs = Attributes(
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
  id: 'impact',
  name: 'Held',
  level: 1,
  attributes: _attrs,
  apAvailable: 0,
  apTotal: 0,
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
    TalentDef(
      id: 'bow',
      name: 'Bogen',
      group: 'Kampftalent',
      type: 'fernkampf',
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
    ),
  ],
);

// Verwendet echte Katalogregeln, auch wenn keine AP für einen Kauf vorhanden sind.
AdvancementImpact _impact(HeroSheet hero, AttributeCode code, int target) =>
    computeAttributeAdvancementImpact(
      hero: hero,
      catalog: _catalog,
      state: const HeroState.empty(),
      attribute: code,
      targetValue: target,
      epicAdvantagesActive: true,
    );

void main() {
  test('Basiswerte berücksichtigen Rundung und mehrere Schritte', () {
    final one = _impact(_hero, AttributeCode.mu, 13);
    final two = _impact(_hero, AttributeCode.mu, 14);
    final atOne = one.stats.firstWhere((s) => s.label == 'AT-Basis');
    final atTwo = two.stats.firstWhere((s) => s.label == 'AT-Basis');
    expect((atOne.before, atOne.after, atOne.delta), (7, 7, 0));
    expect((atTwo.before, atTwo.after, atTwo.delta), (7, 8, 1));
    expect(_hero.attributes.mu, 12);
  });

  test('Nur belegte Werte am Limit mit neuem Spielraum erscheinen', () {
    for (final value in [null, -1, 14, 15, 16, 17]) {
      final hero = _hero.copyWith(
        talents: {'climb': HeroTalentEntry(talentValue: value)},
      );
      final result = _impact(hero, AttributeCode.mu, 14);
      expect(
        result.unlocked.map((e) => e.before.targetId),
        value == 15 || value == 16 ? ['climb'] : isEmpty,
      );
    }
  });

  test('Eine beteiligte, aber niedrigere Eigenschaft reicht nicht', () {
    final hero = _hero.copyWith(
      attributes: _attrs.copyWith(kk: 14),
      talents: {'climb': const HeroTalentEntry(talentValue: 17)},
    );
    expect(_impact(hero, AttributeCode.mu, 13).unlocked, isEmpty);
    expect(_impact(hero, AttributeCode.mu, 14).unlocked, isEmpty);
    expect(_impact(hero, AttributeCode.mu, 15).unlocked, hasLength(1));
  });

  test('Begabung erhöht das bisherige und neue Maximum', () {
    final hero = _hero.copyWith(
      talents: {'climb': const HeroTalentEntry(talentValue: 17, gifted: true)},
    );
    final entry = _impact(hero, AttributeCode.mu, 13).unlocked.single;
    expect((entry.before.maxValue, entry.after.maxValue), (17, 18));
  });

  test('Nahkampf und Fernkampf verwenden ihre eigenen Eigenschaften', () {
    final hero = _hero.copyWith(
      talents: {
        'sword': const HeroTalentEntry(talentValue: 15),
        'bow': const HeroTalentEntry(talentValue: 15),
      },
    );
    expect(
      _impact(
        hero,
        AttributeCode.ge,
        13,
      ).unlocked.map((e) => e.before.targetId),
      ['sword'],
    );
    expect(
      _impact(
        hero,
        AttributeCode.ff,
        13,
      ).unlocked.map((e) => e.before.targetId),
      ['bow'],
    );
    expect(
      _impact(
        hero,
        AttributeCode.kk,
        13,
      ).unlocked.map((e) => e.before.targetId),
      ['bow', 'sword'],
    );
  });

  test('Aktivierte Zauber werden ohne verfügbare AP berücksichtigt', () {
    final hero = _hero.copyWith(
      spells: {'spell': const HeroSpellEntry(spellValue: 15)},
    );
    final entry = _impact(hero, AttributeCode.mu, 13).unlocked.single;
    expect((entry.before.currentValue, entry.after.maxValue), (15, 16));
    expect(_impact(_hero, AttributeCode.mu, 13).unlocked, isEmpty);
  });

  test('Epische Sondergrenze bleibt durch weitere Eigenschaften begrenzt', () {
    final hero = _hero.copyWith(
      isEpisch: true,
      epicUnactivatedTalentIds: {'climb'},
      talents: {'climb': const HeroTalentEntry(talentValue: 12)},
    );
    expect(_impact(hero, AttributeCode.mu, 13).unlocked, isEmpty);
    final ready = hero.copyWith(attributes: _attrs.copyWith(ge: 13, kk: 13));
    expect(_impact(ready, AttributeCode.mu, 13).unlocked, hasLength(1));
  });

  test('Effektiver Zielwert zählt Herkunftsboni nicht doppelt', () {
    final hero = _hero.copyWith(
      background: const HeroBackground(rasseModText: 'MU+1'),
      talents: {'climb': const HeroTalentEntry(talentValue: 16)},
    );
    final result = _impact(hero, AttributeCode.mu, 14);
    final entry = result.unlocked.single;
    expect((entry.before.maxValue, entry.after.maxValue), (16, 17));
    final at = result.stats.firstWhere((s) => s.label == 'AT-Basis');
    expect((at.before, at.after), (7, 8));
  });

  test(
    'Inventar, temporäre Boni und Wunden bleiben in beiden Summen enthalten',
    () {
      final hero = _hero.copyWith(
        inventoryEntries: const [
          HeroInventoryEntry(
            istAusgeruestet: true,
            itemType: InventoryItemType.ausruestung,
            modifiers: [
              InventoryItemModifier(
                kind: InventoryModifierKind.attribut,
                targetId: 'mu',
                wert: 1,
              ),
              InventoryItemModifier(
                kind: InventoryModifierKind.stat,
                targetId: 'at',
                wert: 2,
              ),
            ],
          ),
        ],
        talents: {'climb': const HeroTalentEntry(talentValue: 15)},
      );
      final state = const HeroState.empty().copyWith(
        tempAttributeMods: const AttributeModifiers(mu: 4),
        tempMods: const StatModifiers(at: 3),
        wpiZustand: const WundZustand(wundenProZone: {WundZone.brust: 1}),
      );
      final result = computeAttributeAdvancementImpact(
        hero: hero,
        catalog: _catalog,
        state: state,
        attribute: AttributeCode.mu,
        targetValue: 15,
        epicAdvantagesActive: true,
      );
      final at = result.stats.firstWhere((s) => s.label == 'AT-Basis');
      // round((17+12+12)/5)+2+3-3 = 10, danach round(44/5)+2 = 11.
      expect((at.before, at.after), (10, 11));
      final au = result.stats.firstWhere((s) => s.label == 'Au');
      // Ressourcen verwenden MU 13 bzw. 16 ohne den temporären Bonus von 4.
      expect((au.before, au.after), (21, 22));
      // Die vorhandene Steigerungsgrenze zählt weder Inventar noch Attributo.
      expect(result.unlocked.single.before.maxValue, 15);
      expect(result.unlocked.single.after.maxValue, 18);
    },
  );
}
