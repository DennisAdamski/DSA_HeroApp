import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';

void main() {
  const state = HeroState(
    currentLep: 0,
    currentAsp: 0,
    currentKap: 0,
    currentAu: 0,
  );
  const stateWithAxx = HeroState(
    currentLep: 0,
    currentAsp: 0,
    currentKap: 0,
    currentAu: 0,
    activeSpellEffects: ActiveSpellEffectsState(
      activeEffectIds: <String>[activeSpellEffectAxxeleratus],
    ),
  );
  const baseAttributes = Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  );
  final baseHero = HeroSheet(
    id: 'h',
    name: 'Testheld',
    level: 10,
    attributes: baseAttributes,
    talents: const <String, HeroTalentEntry>{},
    combatConfig: const CombatConfig(),
    vorteileText: '',
    nachteileText: '',
  );

  HeroSheet hero({
    int level = 10,
    Attributes? attributes,
    Map<String, HeroTalentEntry> talents = const <String, HeroTalentEntry>{},
    CombatConfig combatConfig = const CombatConfig(),
    String vorteileText = '',
    String nachteileText = '',
  }) {
    return baseHero.copyWith(
      level: level,
      attributes: attributes ?? baseAttributes,
      talents: talents,
      combatConfig: combatConfig,
      vorteileText: vorteileText,
      nachteileText: nachteileText,
    );
  }

  HeroSheet heroWithAttributes({
    int? mu,
    int? kl,
    int? inn,
    int? ch,
    int? ff,
    int? ge,
    int? ko,
    int? kk,
    CombatConfig combatConfig = const CombatConfig(),
  }) {
    return hero(
      attributes: baseAttributes.copyWith(
        mu: mu,
        kl: kl,
        inn: inn,
        ch: ch,
        ff: ff,
        ge: ge,
        ko: ko,
        kk: kk,
      ),
      combatConfig: combatConfig,
    );
  }

  CombatPreviewStats preview(
    HeroSheet sheet, {
    List<TalentDef> catalogTalents = const <TalentDef>[],
    HeroState heroState = state,
  }) {
    return computeCombatPreviewStats(
      sheet,
      heroState,
      catalogTalents: catalogTalents,
    );
  }

  test('TP/KK rounds towards zero for positive and negative values', () {
    // Dieser Test prüft die TP/KK-Regel.
    // Bei Werten überhalb des Basiswertes und oberhalb der Schwelle, steigt der Wert mit jedem Schwellenwert.
    // Bei Werten unterhalb des Basiswertes und unterhalb der Schwelle, sinkt der Wert mit jedem Schwellenwert.
    // Bei genauem Erreichen des Basiswertes, gibt es keinen Bonus oder Malus.
    const combatConfig = CombatConfig(
      mainWeapon: MainWeaponSlot(kkBase: 10, kkThreshold: 3),
    );
    final positiveOne = heroWithAttributes(kk: 13, combatConfig: combatConfig);
    final positiveTwo = heroWithAttributes(kk: 16, combatConfig: combatConfig);
    final negativeOne = heroWithAttributes(kk: 7, combatConfig: combatConfig);
    final zero = heroWithAttributes(kk: 10, combatConfig: combatConfig);

    expect(preview(positiveOne).tpKk, 1);
    expect(preview(positiveTwo).tpKk, 2);
    expect(preview(negativeOne).tpKk, -1);
    expect(preview(zero).tpKk, 0);
  });

  test('INI/GE rounds towards zero for positive and negative values', () {
    // Erklärung da diese Regel etwas indirekt ist:
    // Bei einer KK-Basis von 10 berechnet sich eine GE-Basis von 16, da GE-Basis = 26 - KK-Basis.
    // Bei einer KK-Schwelle von 3 berechnet sich eine GE-Schwelle von 4, da GE-Schwelle = 7 - KK-Schwelle.
    const combatConfig = CombatConfig(
      mainWeapon: MainWeaponSlot(kkBase: 10, kkThreshold: 3),
    );
    final positiveOne = heroWithAttributes(ge: 20, combatConfig: combatConfig);
    final positiveTwo = heroWithAttributes(ge: 24, combatConfig: combatConfig);
    final negativeOne = heroWithAttributes(ge: 12, combatConfig: combatConfig);
    final zero = heroWithAttributes(ge: 16, combatConfig: combatConfig);

    expect(preview(positiveOne).iniGe, 1);
    expect(preview(positiveTwo).iniGe, 2);
    expect(preview(negativeOne).iniGe, -1);
    expect(preview(zero).iniGe, 0);
  });

  test('Ini Parade Mod is never negative', () {
    const baseCombatConfig = CombatConfig(
      mainWeapon: MainWeaponSlot(kkBase: 15, kkThreshold: 3),
    );
    final referenceSheet = heroWithAttributes(combatConfig: baseCombatConfig);
    final lowIniSheet = referenceSheet.copyWith(
      combatConfig: referenceSheet.combatConfig.copyWith(
        mainWeapon: referenceSheet.combatConfig.mainWeapon.copyWith(
          iniMod: -20,
        ),
      ),
    );
    final highIniSheet = referenceSheet.copyWith(
      combatConfig: referenceSheet.combatConfig.copyWith(
        mainWeapon: referenceSheet.combatConfig.mainWeapon.copyWith(iniMod: 21),
      ),
    );

    final referenceResult = preview(referenceSheet);
    final lowIniResult = preview(lowIniSheet);
    final highIniResult = preview(highIniSheet);

    expect(referenceResult.eigenschaftsIni, 10);
    expect(referenceResult.iniGe, 0);
    expect(referenceResult.heldenInitiative, 10);
    expect(referenceResult.kampfInitiative, 10);
    expect(lowIniResult.kampfInitiative, 0);
    expect(lowIniResult.iniParadeMod, 0);
    expect(lowIniResult.paMitIniParadeMod, lowIniResult.pa);
    expect(highIniResult.kampfInitiative, 31);
    expect(highIniResult.iniParadeMod, 2);
    expect(
      highIniResult.paMitIniParadeMod,
      highIniResult.pa + highIniResult.iniParadeMod,
    );
  });
  test('combat preview integrates Axxeleratus into melee preview values', () {
    final baseHero = hero(
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(tpFlat: 4, kkBase: 12, kkThreshold: 2),
      ),
    );
    final withAxx = baseHero;

    final baseResult = preview(baseHero);
    final axxResult = preview(withAxx, heroState: stateWithAxx);

    expect(axxResult.tpCalc, baseResult.tpCalc + 2);
    expect(axxResult.paBase, baseResult.paBase + 2);
    expect(axxResult.axxAttackDefenseHint, isNotEmpty);
  });

  test(
    'kampf initiative includes only weapon/offhand ini mods on top of helden initiative',
    () {
      final sheet = hero(
        combatConfig: const CombatConfig(
          mainWeapon: MainWeaponSlot(iniMod: 3),
          offhand: OffhandSlot(mode: OffhandMode.linkhand, iniMod: -1),
          manualMods: CombatManualMods(iniWurf: 2),
        ),
      );

      final result = preview(sheet);
      expect(
        result.kombinierteHeldenWaffenIni,
        result.heldenInitiative + 3 + result.iniGe,
      );
      expect(result.kampfInitiative, result.kombinierteHeldenWaffenIni - 1);
    },
  );

  test('kombinierte Helden+Waffen INI includes weapon ini mod and INI/GE', () {
    final hero = heroWithAttributes(
      ge: 21,
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(iniMod: 3, kkBase: 10, kkThreshold: 3),
        offhand: OffhandSlot(mode: OffhandMode.linkhand, iniMod: -1),
      ),
    );
    final result = preview(hero);

    expect(result.iniGe, 1);
    expect(result.kombinierteHeldenWaffenIni, result.heldenInitiative + 3 + 1);
    expect(result.kampfInitiative, result.kombinierteHeldenWaffenIni - 1);
  });

  test('aufmerksamkeit can apply max roll via manual ini input channel', () {
    final sheet = hero(
      combatConfig: const CombatConfig(
        specialRules: CombatSpecialRules(klingentaenzer: true),
        manualMods: CombatManualMods(iniWurf: 12),
      ),
    );

    final result = preview(sheet);
    expect(result.iniWurfEffective, 12);
  });

  test('manual ini roll input is clamped to max roll', () {
    final sheet = hero(
      combatConfig: const CombatConfig(
        specialRules: CombatSpecialRules(klingentaenzer: true),
        manualMods: CombatManualMods(iniWurf: 13),
      ),
    );

    final result = preview(sheet);
    expect(result.iniWurfEffective, 12);
  });

  test('weapon ini mod increases combined initiative linearly', () {
    final baseHero = hero(
      combatConfig: const CombatConfig(mainWeapon: MainWeaponSlot(iniMod: 0)),
    );
    final boostedHero = baseHero.copyWith(
      combatConfig: baseHero.combatConfig.copyWith(
        mainWeapon: baseHero.combatConfig.mainWeapon.copyWith(iniMod: 2),
      ),
    );

    final baseResult = preview(baseHero);
    final boostedResult = preview(boostedHero);

    expect(
      boostedResult.kombinierteHeldenWaffenIni,
      baseResult.kombinierteHeldenWaffenIni + 2,
    );
  });

  test('Flink from Vorteile adds +1 INI and +1 Ausweichen', () {
    final withoutFlink = hero();
    final withFlink = hero(vorteileText: 'Flink');

    final withoutResult = preview(withoutFlink);
    final withResult = preview(withFlink);

    expect(withResult.sfIniBonus, withoutResult.sfIniBonus + 1);
    expect(withResult.sfAusweichenBonus, withoutResult.sfAusweichenBonus + 1);
  });

  test('Behaebig from Nachteile gives -1 INI and -1 Ausweichen', () {
    final withoutBehaebig = hero();
    final withBehaebig = hero(nachteileText: 'Behaebig');

    final withoutResult = preview(withoutBehaebig);
    final withResult = preview(withBehaebig);

    expect(withResult.sfIniBonus, withoutResult.sfIniBonus - 1);
    expect(withResult.sfAusweichenBonus, withoutResult.sfAusweichenBonus - 1);
  });

  test('Flink and Behaebig from texts cancel each other', () {
    final baseline = hero();
    final withBoth = hero(vorteileText: 'Flink', nachteileText: 'Behaebig');

    final baselineResult = preview(baseline);
    final withBothResult = preview(withBoth);

    expect(withBothResult.sfIniBonus, baselineResult.sfIniBonus);
    expect(withBothResult.sfAusweichenBonus, baselineResult.sfAusweichenBonus);
  });

  test('Spezialisierung grants +1 AT and +1 PA when weapon type matches', () {
    const mainWeapon = MainWeaponSlot(
      talentId: 'tal_schwerter',
      weaponType: 'Kurzschwert',
      name: 'Kurzschwert',
      kkBase: 12,
      kkThreshold: 2,
    );

    final withSpec = hero(
      talents: const {
        'tal_schwerter': HeroTalentEntry(
          atValue: 6,
          paValue: 4,
          combatSpecializations: <String>['Kurzschwert'],
        ),
      },
      combatConfig: const CombatConfig(mainWeapon: mainWeapon),
    );
    final withoutSpec = hero(
      talents: const {'tal_schwerter': HeroTalentEntry(atValue: 6, paValue: 4)},
      combatConfig: const CombatConfig(mainWeapon: mainWeapon),
    );

    final withResult = preview(withSpec);
    final withoutResult = preview(withoutSpec);

    expect(withResult.specApplies, isTrue);
    expect(withoutResult.specApplies, isFalse);
    expect(withResult.at, withoutResult.at + 1);
    expect(withResult.pa, withoutResult.pa + 1);
  });

  test('Spezialisierung grants +2 AT and +0 PA for Fernkampf talents', () {
    const mainWeapon = MainWeaponSlot(
      talentId: 'tal_boegen',
      weaponType: 'Kurzbogen',
      name: 'Kurzbogen',
      kkBase: 12,
      kkThreshold: 2,
    );
    const catalogTalents = <TalentDef>[
      TalentDef(
        id: 'tal_boegen',
        name: 'Boegen',
        group: 'Kampftalent',
        type: 'Fernkampf',
        steigerung: 'D',
        attributes: <String>['Intuition', 'Fingerfertigkeit', 'Koerperkraft'],
      ),
    ];

    final withSpec = hero(
      talents: const {
        'tal_boegen': HeroTalentEntry(
          atValue: 6,
          paValue: 4,
          combatSpecializations: <String>['Kurzbogen'],
        ),
      },
      combatConfig: const CombatConfig(mainWeapon: mainWeapon),
    );
    final withoutSpec = hero(
      talents: const {'tal_boegen': HeroTalentEntry(atValue: 6, paValue: 4)},
      combatConfig: const CombatConfig(mainWeapon: mainWeapon),
    );

    final withResult = preview(withSpec, catalogTalents: catalogTalents);
    final withoutResult = preview(withoutSpec, catalogTalents: catalogTalents);

    expect(withResult.specApplies, isTrue);
    expect(withResult.at, withoutResult.at + 2);
    expect(withResult.pa, withoutResult.pa);
  });

  test('ranged AT uses AT value instead of talentValue', () {
    const catalogTalents = <TalentDef>[
      TalentDef(
        id: 'tal_boegen',
        name: 'Boegen',
        group: 'Kampftalent',
        type: 'Fernkampf',
        steigerung: 'D',
        attributes: <String>['Intuition', 'Fingerfertigkeit', 'Koerperkraft'],
      ),
    ];
    final sheet = hero(
      talents: const {
        'tal_boegen': HeroTalentEntry(
          talentValue: 7,
          atValue: 1,
          combatSpecializations: <String>['Kurzbogen'],
        ),
      },
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(
          name: 'Kurzbogen',
          talentId: 'tal_boegen',
          combatType: WeaponCombatType.ranged,
          weaponType: 'Kurzbogen',
          wmAt: 2,
        ),
        manualMods: CombatManualMods(atMod: 1),
      ),
    );

    final result = preview(sheet, catalogTalents: catalogTalents);

    expect(result.isRangedWeapon, isTrue);
    expect(result.at, result.rangedAtBase + 1 + 2 + result.specBonus + 1);
    expect(result.pa, 0);
  });

  test('ranged distance and projectile modify TP, AT and INI as intended', () {
    const catalogTalents = <TalentDef>[
      TalentDef(
        id: 'tal_boegen',
        name: 'Boegen',
        group: 'Kampftalent',
        type: 'Fernkampf',
        steigerung: 'D',
        attributes: <String>['Intuition', 'Fingerfertigkeit', 'Koerperkraft'],
      ),
    ];
    final base = hero(
      talents: const {'tal_boegen': HeroTalentEntry(talentValue: 6)},
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(
          name: 'Kurzbogen',
          talentId: 'tal_boegen',
          combatType: WeaponCombatType.ranged,
          weaponType: 'Kurzbogen',
          tpFlat: 4,
          rangedProfile: RangedWeaponProfile(
            distanceBands: <RangedDistanceBand>[
              RangedDistanceBand(label: 'Nah', tpMod: 0),
              RangedDistanceBand(label: 'Mittel', tpMod: 0),
              RangedDistanceBand(label: 'Weit', tpMod: 0),
              RangedDistanceBand(label: 'Sehr weit', tpMod: 0),
              RangedDistanceBand(label: 'Extrem', tpMod: 0),
            ],
          ),
        ),
      ),
    );
    final modified = base.copyWith(
      combatConfig: base.combatConfig.copyWith(
        mainWeapon: base.combatConfig.mainWeapon.copyWith(
          rangedProfile: const RangedWeaponProfile(
            distanceBands: <RangedDistanceBand>[
              RangedDistanceBand(label: 'Nah', tpMod: 2),
              RangedDistanceBand(label: 'Mittel', tpMod: 0),
              RangedDistanceBand(label: 'Weit', tpMod: 0),
              RangedDistanceBand(label: 'Sehr weit', tpMod: 0),
              RangedDistanceBand(label: 'Extrem', tpMod: 0),
            ],
            projectiles: <RangedProjectile>[
              RangedProjectile(
                name: 'Kriegspfeil',
                count: 6,
                tpMod: 1,
                iniMod: -2,
                atMod: 3,
              ),
            ],
            selectedDistanceIndex: 0,
            selectedProjectileIndex: 0,
          ),
        ),
      ),
    );

    final baseResult = preview(base, catalogTalents: catalogTalents);
    final modifiedResult = preview(modified, catalogTalents: catalogTalents);

    expect(modifiedResult.tpCalc, baseResult.tpCalc + 3);
    expect(modifiedResult.at, baseResult.at + 3);
    expect(
      modifiedResult.kombinierteHeldenWaffenIni,
      baseResult.kombinierteHeldenWaffenIni - 2,
    );
    expect(modifiedResult.pa, 0);
  });

  test(
    'Spezialisierung matching is strict and does not allow partial matches',
    () {
      const mainWeapon = MainWeaponSlot(
        talentId: 'tal_schwerter',
        weaponType: 'Kurzschwert',
        name: 'Kurzschwert',
        kkBase: 12,
        kkThreshold: 2,
      );

      final withPartialSpec = hero(
        talents: const {
          'tal_schwerter': HeroTalentEntry(
            atValue: 6,
            paValue: 4,
            combatSpecializations: <String>['Schwert'],
          ),
        },
        combatConfig: const CombatConfig(mainWeapon: mainWeapon),
      );
      final withoutSpec = hero(
        talents: const {
          'tal_schwerter': HeroTalentEntry(atValue: 6, paValue: 4),
        },
        combatConfig: const CombatConfig(mainWeapon: mainWeapon),
      );

      final partialResult = preview(withPartialSpec);
      final withoutResult = preview(withoutSpec);

      expect(partialResult.specApplies, isFalse);
      expect(partialResult.at, withoutResult.at);
      expect(partialResult.pa, withoutResult.pa);
    },
  );

  test('offhand bonuses depend on mode and not on one-handed flag', () {
    final noOffhand = hero(
      talents: const {'tal_waffe': HeroTalentEntry(atValue: 6, paValue: 6)},
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(
          talentId: 'tal_waffe',
          name: 'Waffe',
          weaponType: 'Waffe',
          isOneHanded: false,
        ),
      ),
    );
    final withOffhand = noOffhand.copyWith(
      combatConfig: noOffhand.combatConfig.copyWith(
        offhand: const OffhandSlot(
          mode: OffhandMode.linkhand,
          atMod: 2,
          paMod: 3,
        ),
      ),
    );

    final noOffhandResult = preview(noOffhand);
    final withOffhandResult = preview(withOffhand);

    expect(withOffhandResult.at, noOffhandResult.at + 2);
    expect(withOffhandResult.pa, noOffhandResult.pa + 4);
  });

  test('combat preview stays stable when no active weapon is selected', () {
    final sheet = hero(
      talents: const {'tal_waffe': HeroTalentEntry(atValue: 6, paValue: 6)},
      combatConfig: const CombatConfig(
        weapons: <MainWeaponSlot>[
          MainWeaponSlot(
            name: 'Kurzschwert',
            talentId: 'tal_waffe',
            weaponType: 'Kurzschwert',
            wmAt: 2,
            wmPa: 1,
            tpFlat: 3,
          ),
        ],
        selectedWeaponIndex: -1,
      ),
    );

    final result = preview(sheet);
    expect(result.at, greaterThanOrEqualTo(0));
    expect(result.pa, greaterThanOrEqualTo(0));
    expect(result.tpExpression, isNotEmpty);
  });

  test('eBE modifies AT and PA with excel-compatible sign behavior', () {
    final noArmor = hero(
      talents: const {'tal_waffe': HeroTalentEntry(atValue: 0, paValue: 0)},
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(
          talentId: 'tal_waffe',
          kkBase: 12,
          kkThreshold: 2,
        ),
        armor: ArmorConfig(pieces: <ArmorPiece>[]),
      ),
    );
    final withArmor = noArmor.copyWith(
      combatConfig: noArmor.combatConfig.copyWith(
        armor: const ArmorConfig(
          pieces: <ArmorPiece>[
            ArmorPiece(name: 'Ruestung', isActive: true, rs: 2, be: 3),
          ],
        ),
      ),
    );

    final noArmorResult = preview(noArmor);
    final withArmorResult = preview(withArmor);

    expect(withArmorResult.ebe, -3);
    expect(withArmorResult.at, noArmorResult.at - 1);
    expect(withArmorResult.pa, noArmorResult.pa - 2);
  });

  test('RG I is capped at 1 even with multiple active armor pieces', () {
    final sheet = hero(
      combatConfig: const CombatConfig(
        armor: ArmorConfig(
          globalArmorTrainingLevel: 1,
          pieces: <ArmorPiece>[
            ArmorPiece(name: 'Helm', isActive: true, rg1Active: true, be: 2),
            ArmorPiece(name: 'Brust', isActive: true, rg1Active: true, be: 3),
          ],
        ),
      ),
    );

    final result = preview(sheet);

    expect(result.beTotalRaw, 5);
    expect(result.rgReduction, 1);
    expect(result.beKampf, 4);
  });

  test('RG I flags are ignored when training is empty', () {
    final sheet = hero(
      combatConfig: const CombatConfig(
        armor: ArmorConfig(
          globalArmorTrainingLevel: 0,
          pieces: <ArmorPiece>[
            ArmorPiece(name: 'Helm', isActive: true, rg1Active: true, be: 2),
          ],
        ),
      ),
    );

    final result = preview(sheet);
    expect(result.rgReduction, 0);
    expect(result.beKampf, 2);
  });

  test('global RG II and III override RG I', () {
    final rg2Hero = hero(
      combatConfig: const CombatConfig(
        armor: ArmorConfig(
          globalArmorTrainingLevel: 2,
          pieces: <ArmorPiece>[
            ArmorPiece(name: 'Helm', isActive: true, rg1Active: true, be: 4),
          ],
        ),
      ),
    );
    final rg3Hero = rg2Hero.copyWith(
      combatConfig: rg2Hero.combatConfig.copyWith(
        armor: rg2Hero.combatConfig.armor.copyWith(globalArmorTrainingLevel: 3),
      ),
    );

    final rg2Result = preview(rg2Hero);
    final rg3Result = preview(rg3Hero);

    expect(rg2Result.rgReduction, 1);
    expect(rg3Result.rgReduction, 2);
  });

  test('inactive armor pieces are ignored in RS and BE sums', () {
    final sheet = hero(
      combatConfig: const CombatConfig(
        armor: ArmorConfig(
          pieces: <ArmorPiece>[
            ArmorPiece(name: 'Aktiv', isActive: true, rs: 2, be: 2),
            ArmorPiece(name: 'Inaktiv', isActive: false, rs: 9, be: 9),
          ],
        ),
      ),
    );

    final result = preview(sheet);
    expect(result.rsTotal, 2);
    expect(result.beTotalRaw, 2);
  });

  test('INI-Bonus auf Ausweichen ab Kampf-INI 21', () {
    // Held mit hohen Attributen und hohem INI-Wurf fuer hohe Initiative.
    final highIniHero = heroWithAttributes(
      mu: 18,
      inn: 18,
      ge: 18,
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(iniMod: 8, kkBase: 10, kkThreshold: 3),
        specialRules: CombatSpecialRules(kampfreflexe: true),
        manualMods: CombatManualMods(iniWurf: 6),
      ),
    );

    final result = preview(highIniHero);

    // Bei Kampf-INI >= 21 sollte es einen Bonus geben.
    if (result.kampfInitiative >= 21) {
      expect(result.iniAusweichenBonus, greaterThan(0));
      expect(
        result.iniAusweichenBonus,
        ((result.kampfInitiative - 20) / 10).ceil(),
      );
    } else {
      expect(result.iniAusweichenBonus, 0);
    }
  });

  test('INI-Bonus auf Ausweichen ist 0 bei niedriger Initiative', () {
    final lowIniHero = heroWithAttributes(
      mu: 8,
      kl: 8,
      inn: 8,
      ch: 8,
      ff: 8,
      ge: 8,
      ko: 8,
      kk: 8,
    );

    final result = preview(lowIniHero);

    expect(result.kampfInitiative, lessThan(21));
    expect(result.iniAusweichenBonus, 0);
  });
}
