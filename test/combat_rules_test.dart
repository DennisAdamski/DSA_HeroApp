import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';

void main() {
  const state = HeroState(
    currentLep: 0,
    currentAsp: 0,
    currentKap: 0,
    currentAu: 0,
  );

  HeroSheet buildHero({
    int level = 10,
    Attributes attributes = const Attributes(
      mu: 12,
      kl: 12,
      inn: 12,
      ch: 12,
      ff: 12,
      ge: 12,
      ko: 12,
      kk: 12,
    ),
    Map<String, HeroTalentEntry> talents = const <String, HeroTalentEntry>{},
    CombatConfig combatConfig = const CombatConfig(),
  }) {
    return HeroSheet(
      id: 'h',
      name: 'Testheld',
      level: level,
      attributes: attributes,
      talents: talents,
      combatConfig: combatConfig,
    );
  }

  test('TP/KK rounds towards zero for positive and negative values', () {
    final positive = buildHero(
      attributes: const Attributes(
        mu: 12,
        kl: 12,
        inn: 12,
        ch: 12,
        ff: 12,
        ge: 12,
        ko: 12,
        kk: 14,
      ),
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(kkBase: 10, kkThreshold: 3),
      ),
    );
    final negative = buildHero(
      attributes: const Attributes(
        mu: 12,
        kl: 12,
        inn: 12,
        ch: 12,
        ff: 12,
        ge: 12,
        ko: 12,
        kk: 6,
      ),
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(kkBase: 10, kkThreshold: 3),
      ),
    );

    expect(computeCombatPreviewStats(positive, state).tpKk, 1);
    expect(computeCombatPreviewStats(negative, state).tpKk, -1);
  });

  test('INI/GE rounds towards zero for positive and negative values', () {
    final positive = buildHero(
      attributes: const Attributes(
        mu: 12,
        kl: 12,
        inn: 12,
        ch: 12,
        ff: 12,
        ge: 21,
        ko: 12,
        kk: 12,
      ),
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(kkBase: 10, kkThreshold: 3),
      ),
    );
    final negative = buildHero(
      attributes: const Attributes(
        mu: 12,
        kl: 12,
        inn: 12,
        ch: 12,
        ff: 12,
        ge: 11,
        ko: 12,
        kk: 12,
      ),
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(kkBase: 10, kkThreshold: 3),
      ),
    );

    expect(computeCombatPreviewStats(positive, state).iniGe, 1);
    expect(computeCombatPreviewStats(negative, state).iniGe, -1);
  });

  test('Ini Parade Mod is never negative', () {
    final lowIni = buildHero(
      attributes: const Attributes(
        mu: 8,
        kl: 8,
        inn: 8,
        ch: 8,
        ff: 8,
        ge: 8,
        ko: 8,
        kk: 8,
      ),
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(kkBase: 15, kkThreshold: 3),
      ),
    );
    final highIni = buildHero(
      attributes: const Attributes(
        mu: 18,
        kl: 12,
        inn: 18,
        ch: 12,
        ff: 12,
        ge: 18,
        ko: 12,
        kk: 12,
      ),
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(iniMod: 8, kkBase: 10, kkThreshold: 3),
      ),
    );

    expect(computeCombatPreviewStats(lowIni, state).iniParadeMod, 0);
    expect(
      computeCombatPreviewStats(highIni, state).iniParadeMod,
      greaterThan(0),
    );
  });

  test('TK-Kalk includes Axxeleratus bonus', () {
    final baseHero = buildHero(
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(tpFlat: 4, kkBase: 12, kkThreshold: 2),
      ),
    );
    final withAxxeleratus = baseHero.copyWith(
      combatConfig: baseHero.combatConfig.copyWith(
        specialRules: baseHero.combatConfig.specialRules.copyWith(
          axxeleratusActive: true,
        ),
      ),
    );

    final withoutResult = computeCombatPreviewStats(baseHero, state);
    final withResult = computeCombatPreviewStats(withAxxeleratus, state);

    expect(withoutResult.tpCalc, 4);
    expect(withResult.tpCalc, 6);
  });

  test('Spezialisierung grants +1 AT and +1 PA when weapon type matches', () {
    const mainWeapon = MainWeaponSlot(
      talentId: 'tal_schwerter',
      weaponType: 'Kurzschwert',
      name: 'Kurzschwert',
      kkBase: 12,
      kkThreshold: 2,
    );

    final withSpec = buildHero(
      talents: const {
        'tal_schwerter': HeroTalentEntry(
          atValue: 6,
          paValue: 4,
          combatSpecializations: <String>['Kurzschwert'],
        ),
      },
      combatConfig: const CombatConfig(mainWeapon: mainWeapon),
    );
    final withoutSpec = buildHero(
      talents: const {'tal_schwerter': HeroTalentEntry(atValue: 6, paValue: 4)},
      combatConfig: const CombatConfig(mainWeapon: mainWeapon),
    );

    final withResult = computeCombatPreviewStats(withSpec, state);
    final withoutResult = computeCombatPreviewStats(withoutSpec, state);

    expect(withResult.specApplies, isTrue);
    expect(withoutResult.specApplies, isFalse);
    expect(withResult.at, withoutResult.at + 1);
    expect(withResult.pa, withoutResult.pa + 1);
  });

  test('eBE modifies AT and PA with excel-compatible sign behavior', () {
    final noArmor = buildHero(
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

    final noArmorResult = computeCombatPreviewStats(noArmor, state);
    final withArmorResult = computeCombatPreviewStats(withArmor, state);

    expect(withArmorResult.ebe, -3);
    expect(withArmorResult.at, noArmorResult.at - 1);
    expect(withArmorResult.pa, noArmorResult.pa - 2);
  });

  test('RG I is capped at 1 even with multiple active armor pieces', () {
    final hero = buildHero(
      combatConfig: const CombatConfig(
        armor: ArmorConfig(
          globalArmorTrainingLevel: 0,
          pieces: <ArmorPiece>[
            ArmorPiece(name: 'Helm', isActive: true, rg1Active: true, be: 2),
            ArmorPiece(name: 'Brust', isActive: true, rg1Active: true, be: 3),
          ],
        ),
      ),
    );

    final result = computeCombatPreviewStats(hero, state);

    expect(result.beTotalRaw, 5);
    expect(result.rgReduction, 1);
    expect(result.beKampf, 4);
  });

  test('global RG II and III override RG I', () {
    final rg2Hero = buildHero(
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

    final rg2Result = computeCombatPreviewStats(rg2Hero, state);
    final rg3Result = computeCombatPreviewStats(rg3Hero, state);

    expect(rg2Result.rgReduction, 1);
    expect(rg3Result.rgReduction, 2);
  });

  test('inactive armor pieces are ignored in RS and BE sums', () {
    final hero = buildHero(
      combatConfig: const CombatConfig(
        armor: ArmorConfig(
          pieces: <ArmorPiece>[
            ArmorPiece(name: 'Aktiv', isActive: true, rs: 2, be: 2),
            ArmorPiece(name: 'Inaktiv', isActive: false, rs: 9, be: 9),
          ],
        ),
      ),
    );

    final result = computeCombatPreviewStats(hero, state);
    expect(result.rsTotal, 2);
    expect(result.beTotalRaw, 2);
  });
}
