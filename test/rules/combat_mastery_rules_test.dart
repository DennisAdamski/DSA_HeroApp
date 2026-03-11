import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/combat_mastery.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_mastery_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';

void main() {
  const attributes = Attributes(
    mu: 14,
    kl: 12,
    inn: 13,
    ch: 11,
    ff: 12,
    ge: 16,
    ko: 14,
    kk: 16,
  );
  const state = HeroState(
    currentLep: 0,
    currentAsp: 0,
    currentKap: 0,
    currentAu: 0,
  );
  const combatTalent = TalentDef(
    id: 'tal_schwerter',
    name: 'Schwerter',
    group: 'Kampftalent',
    steigerung: 'D',
    attributes: <String>['MU', 'GE', 'KK'],
    type: 'nahkampf',
  );
  const daggerTalent = TalentDef(
    id: 'tal_dolche',
    name: 'Dolche',
    group: 'Kampftalent',
    steigerung: 'C',
    attributes: <String>['MU', 'GE', 'KK'],
    type: 'nahkampf',
  );
  const bowTalent = TalentDef(
    id: 'tal_boegen',
    name: 'Boegen',
    group: 'Kampftalent',
    steigerung: 'D',
    attributes: <String>['IN', 'FF', 'KK'],
    type: 'fernkampf',
  );

  HeroSheet buildHero({
    List<CombatMastery> masteries = const <CombatMastery>[],
    Map<String, HeroTalentEntry> talents = const <String, HeroTalentEntry>{},
    CombatConfig combatConfig = const CombatConfig(),
  }) {
    return HeroSheet(
      id: 'hero',
      name: 'Test',
      level: 10,
      attributes: attributes,
      talents: talents,
      combatConfig: combatConfig,
      combatMasteries: masteries,
    );
  }

  test('budget applies base costs and maneuver discounts', () {
    const mastery = CombatMastery(
      id: 'm1',
      name: 'Test',
      targetScope: CombatMasteryTargetScope.singleWeapon,
      targetRefs: <String>['Langschwert'],
      effects: <CombatMasteryEffect>[
        CombatMasteryEffect(
          type: CombatMasteryEffectType.maneuverDiscount,
          maneuverId: 'man_finte',
          value: 2,
        ),
        CombatMasteryEffect(
          type: CombatMasteryEffectType.initiativeBonus,
          value: 1,
        ),
      ],
    );

    final budget = evaluateCombatMasteryBudget(
      mastery: mastery,
      relatedTalent: combatTalent,
    );

    expect(budget.baseCost, 2);
    expect(budget.effectCost, 5);
    expect(budget.totalCost, 7);
    expect(budget.remainingPoints, 8);
    expect(budget.issues, isEmpty);
  });

  test('budget rejects multiple large maneuver discounts', () {
    const mastery = CombatMastery(
      id: 'm2',
      name: 'Test',
      effects: <CombatMasteryEffect>[
        CombatMasteryEffect(
          type: CombatMasteryEffectType.maneuverDiscount,
          maneuverId: 'man_finte',
          value: 4,
        ),
        CombatMasteryEffect(
          type: CombatMasteryEffectType.maneuverDiscount,
          maneuverId: 'man_wuchtschlag',
          value: 4,
        ),
      ],
    );

    final budget = evaluateCombatMasteryBudget(
      mastery: mastery,
      relatedTalent: combatTalent,
    );

    expect(
      budget.issues,
      contains('Nur ein Manoever darf eine Erleichterung von 4 Punkten erhalten.'),
    );
  });

  test('budget rejects tpkk shift for non dagger talents', () {
    const mastery = CombatMastery(
      id: 'm3',
      name: 'Test',
      effects: <CombatMasteryEffect>[
        CombatMasteryEffect(
          type: CombatMasteryEffectType.tpkkShift,
          value: -1,
          secondaryValue: -1,
        ),
      ],
    );

    final budget = evaluateCombatMasteryBudget(
      mastery: mastery,
      relatedTalent: combatTalent,
    );

    expect(
      budget.issues,
      contains(
        'TP/KK-Verschiebung ist nur fuer Dolche und Fechtwaffen vorgesehen.',
      ),
    );
    final daggerBudget = evaluateCombatMasteryBudget(
      mastery: mastery,
      relatedTalent: daggerTalent,
    );
    expect(daggerBudget.issues, isEmpty);
  });

  test('applicability distinguishes weapon and shield scopes', () {
    const masteryWeapon = CombatMastery(
      id: 'm4',
      name: 'Waffe',
      targetScope: CombatMasteryTargetScope.singleWeapon,
      targetRefs: <String>['Kurzschwert'],
    );
    const masteryShield = CombatMastery(
      id: 'm5',
      name: 'Schild',
      targetScope: CombatMasteryTargetScope.shield,
    );
    const weapon = MainWeaponSlot(name: 'Kurzschwert', weaponType: 'Kurzschwert');
    const shield = OffhandEquipmentEntry(type: OffhandEquipmentType.shield);

    expect(
      combatMasteryAppliesToWeapon(mastery: masteryWeapon, weapon: weapon),
      isTrue,
    );
    expect(
      combatMasteryAppliesToOffhand(
        mastery: masteryShield,
        offhandEquipment: shield,
      ),
      isTrue,
    );
  });

  test('requirements use talent values and weapon specialization', () {
    const mastery = CombatMastery(
      id: 'm6',
      name: 'Test',
      targetScope: CombatMasteryTargetScope.singleWeapon,
      targetRefs: <String>['Kurzschwert'],
      requirements: CombatMasteryRequirements(
        requiredTalentId: 'tal_schwerter',
        attributeRequirements: <CombatMasteryAttributeRequirement>[
          CombatMasteryAttributeRequirement(attributeCode: 'GE', minimum: 16),
          CombatMasteryAttributeRequirement(attributeCode: 'KK', minimum: 16),
        ],
      ),
    );

    final withoutSpec = evaluateCombatMasteryRequirements(
      mastery: mastery,
      hero: buildHero(
        talents: const <String, HeroTalentEntry>{
          'tal_schwerter': HeroTalentEntry(talentValue: 18),
        },
      ),
      effectiveAttributes: attributes,
    );
    expect(withoutSpec.isFulfilled, isFalse);

    final withSpec = evaluateCombatMasteryRequirements(
      mastery: mastery,
      hero: buildHero(
        talents: const <String, HeroTalentEntry>{
          'tal_schwerter': HeroTalentEntry(
            talentValue: 18,
            combatSpecializations: <String>['Kurzschwert'],
          ),
        },
      ),
      effectiveAttributes: attributes,
    );
    expect(withSpec.isFulfilled, isTrue);
    expect(withSpec.warnings, isNotEmpty);
  });

  test('combat preview applies mastery modifiers to melee stats', () {
    const mastery = CombatMastery(
      id: 'm7',
      name: 'Waffenmeister (Kurzschwert)',
      targetScope: CombatMasteryTargetScope.singleWeapon,
      targetRefs: <String>['Kurzschwert'],
      effects: <CombatMasteryEffect>[
        CombatMasteryEffect(
          type: CombatMasteryEffectType.attackModifier,
          value: 1,
        ),
        CombatMasteryEffect(
          type: CombatMasteryEffectType.parryModifier,
          value: 1,
        ),
        CombatMasteryEffect(
          type: CombatMasteryEffectType.initiativeBonus,
          value: 1,
        ),
      ],
      requirements: CombatMasteryRequirements(requiredTalentId: 'tal_schwerter'),
    );
    const weapon = MainWeaponSlot(
      name: 'Kurzschwert',
      weaponType: 'Kurzschwert',
      talentId: 'tal_schwerter',
    );
    final baseHero = buildHero(
      talents: const <String, HeroTalentEntry>{
        'tal_schwerter': HeroTalentEntry(
          talentValue: 18,
          atValue: 9,
          paValue: 9,
          combatSpecializations: <String>['Kurzschwert'],
        ),
      },
      combatConfig: const CombatConfig(mainWeapon: weapon),
    );
    final masteryHero = baseHero.copyWith(combatMasteries: const <CombatMastery>[mastery]);

    final basePreview = computeCombatPreviewStats(
      baseHero,
      state,
      catalogTalents: const <TalentDef>[combatTalent],
    );
    final masteryPreview = computeCombatPreviewStats(
      masteryHero,
      state,
      catalogTalents: const <TalentDef>[combatTalent],
    );

    expect(masteryPreview.at, basePreview.at + 1);
    expect(masteryPreview.pa, basePreview.pa + 1);
    expect(
      masteryPreview.kampfInitiative,
      basePreview.kampfInitiative + 1,
    );
    expect(masteryPreview.applicableMasteries, hasLength(1));
  });

  test('combat preview applies reload divisor for ranged mastery', () {
    const mastery = CombatMastery(
      id: 'm8',
      name: 'Waffenmeister (Kurzbogen)',
      targetScope: CombatMasteryTargetScope.singleWeapon,
      targetRefs: <String>['Kurzbogen'],
      effects: <CombatMasteryEffect>[
        CombatMasteryEffect(
          type: CombatMasteryEffectType.reloadModifier,
          secondaryValue: 2,
        ),
      ],
      requirements: CombatMasteryRequirements(requiredTalentId: 'tal_boegen'),
    );
    const weapon = MainWeaponSlot(
      name: 'Kurzbogen',
      weaponType: 'Kurzbogen',
      talentId: 'tal_boegen',
      combatType: WeaponCombatType.ranged,
      rangedProfile: RangedWeaponProfile(reloadTime: 4),
    );
    final hero = buildHero(
      combatConfig: const CombatConfig(mainWeapon: weapon),
      masteries: const <CombatMastery>[mastery],
    );
    final preview = computeCombatPreviewStats(
      hero,
      state,
      catalogTalents: const <TalentDef>[bowTalent],
    );

    expect(preview.baseReloadTime, 4);
    expect(preview.reloadTime, 2);
    expect(preview.masteryReloadDivisor, 2);
  });
}
