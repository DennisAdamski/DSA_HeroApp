import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_se_pools.dart';
import 'package:dsa_heldenverwaltung/domain/hero_connection_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/adventure_rewards_rules.dart';

void main() {
  HeroSheet buildHero({
    List<HeroAdventureEntry> adventures = const <HeroAdventureEntry>[],
    Map<String, HeroTalentEntry> talents = const <String, HeroTalentEntry>{},
    int apTotal = 100,
    int apSpent = 20,
    HeroAttributeSePool attributeSePool = const HeroAttributeSePool(),
    HeroStatSePool statSePool = const HeroStatSePool(),
  }) {
    return HeroSheet(
      id: 'hero',
      name: 'Testheld',
      level: 1,
      apTotal: apTotal,
      apSpent: apSpent,
      apAvailable: apTotal - apSpent,
      attributes: const Attributes(
        mu: 12,
        kl: 11,
        inn: 11,
        ch: 10,
        ff: 10,
        ge: 11,
        ko: 12,
        kk: 12,
      ),
      adventures: adventures,
      talents: talents,
      attributeSePool: attributeSePool,
      statSePool: statSePool,
    );
  }

  const adventure = HeroAdventureEntry(
    id: 'adv_1',
    title: 'Das Purpurzeichen',
    apReward: 50,
    seRewards: <HeroAdventureSeReward>[
      HeroAdventureSeReward(
        targetType: HeroAdventureSeTargetType.talent,
        targetId: 'tal_schwerter',
        targetLabel: 'Schwerter',
        count: 2,
      ),
      HeroAdventureSeReward(
        targetType: HeroAdventureSeTargetType.grundwert,
        targetId: 'lep',
        targetLabel: 'LeP',
        count: 1,
      ),
      HeroAdventureSeReward(
        targetType: HeroAdventureSeTargetType.eigenschaft,
        targetId: 'mu',
        targetLabel: 'Mut',
        count: 1,
      ),
    ],
  );

  test(
    'applyAdventureRewards erhoeht AP und verteilt SE auf alle Zieltypen',
    () {
      final hero = buildHero(
        adventures: const <HeroAdventureEntry>[adventure],
        talents: const <String, HeroTalentEntry>{
          'tal_schwerter': HeroTalentEntry(talentValue: 8),
        },
      );

      final result = applyAdventureRewards(hero: hero, adventureId: 'adv_1');

      expect(result.apTotal, 150);
      expect(result.talents['tal_schwerter']?.specialExperiences, 2);
      expect(result.statSePool.lep, 1);
      expect(result.attributeSePool.mu, 1);
      expect(result.adventures.single.rewardsApplied, isTrue);
    },
  );

  test(
    'canRevokeAdventureRewards erlaubt Ruecknahme solange AP und SE ungenutzt sind',
    () {
      final hero = buildHero(
        adventures: <HeroAdventureEntry>[
          adventure.copyWith(rewardsApplied: true),
        ],
        talents: const <String, HeroTalentEntry>{
          'tal_schwerter': HeroTalentEntry(
            talentValue: 8,
            specialExperiences: 2,
          ),
        },
        apTotal: 150,
        apSpent: 20,
        attributeSePool: const HeroAttributeSePool(mu: 1),
        statSePool: const HeroStatSePool(lep: 1),
      );

      final check = canRevokeAdventureRewards(hero: hero, adventureId: 'adv_1');

      expect(check.isAllowed, isTrue);
      final reverted = revokeAdventureRewards(hero: hero, adventureId: 'adv_1');
      expect(reverted.apTotal, 100);
      expect(reverted.talents['tal_schwerter']?.specialExperiences, 0);
      expect(reverted.attributeSePool.mu, 0);
      expect(reverted.statSePool.lep, 0);
      expect(reverted.adventures.single.rewardsApplied, isFalse);
    },
  );

  test(
    'canRevokeAdventureRewards blockiert wenn AP bereits verbraucht wurden',
    () {
      final hero = buildHero(
        adventures: <HeroAdventureEntry>[
          adventure.copyWith(rewardsApplied: true),
        ],
        talents: const <String, HeroTalentEntry>{
          'tal_schwerter': HeroTalentEntry(
            talentValue: 8,
            specialExperiences: 2,
          ),
        },
        apTotal: 150,
        apSpent: 120,
        attributeSePool: const HeroAttributeSePool(mu: 1),
        statSePool: const HeroStatSePool(lep: 1),
      );

      final check = canRevokeAdventureRewards(hero: hero, adventureId: 'adv_1');

      expect(check.isAllowed, isFalse);
      expect(check.reason, contains('AP'));
    },
  );

  test(
    'canRevokeAdventureRewards blockiert wenn eine Talent-SE bereits verbraucht wurde',
    () {
      final hero = buildHero(
        adventures: <HeroAdventureEntry>[
          adventure.copyWith(rewardsApplied: true),
        ],
        talents: const <String, HeroTalentEntry>{
          'tal_schwerter': HeroTalentEntry(
            talentValue: 8,
            specialExperiences: 1,
          ),
        },
        apTotal: 150,
        apSpent: 20,
        attributeSePool: const HeroAttributeSePool(mu: 1),
        statSePool: const HeroStatSePool(lep: 1),
      );

      final check = canRevokeAdventureRewards(hero: hero, adventureId: 'adv_1');

      expect(check.isAllowed, isFalse);
      expect(check.reason, contains('Schwerter'));
    },
  );

  test('cleanupAdventureReferences leert ungueltige Kontakt-Referenzen', () {
    final connections = cleanupAdventureReferences(
      connections: const <HeroConnectionEntry>[
        HeroConnectionEntry(name: 'Jucho', adventureId: 'adv_1'),
        HeroConnectionEntry(name: 'Laila', adventureId: 'adv_2'),
      ],
      validAdventureIds: const <String>{'adv_1'},
    );

    expect(connections.first.adventureId, 'adv_1');
    expect(connections.last.adventureId, isEmpty);
  });
}
