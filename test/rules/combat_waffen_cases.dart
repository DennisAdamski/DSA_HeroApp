part of 'combat_rules_test.dart';

void _combatWaffen() {
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

  test('parry weapon changes parade but keeps main-hand attack unchanged', () {
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
        offhandAssignment: const OffhandAssignment(equipmentIndex: 0),
        offhandEquipment: const <OffhandEquipmentEntry>[
          OffhandEquipmentEntry(
            type: OffhandEquipmentType.parryWeapon,
            atMod: 2,
            paMod: 3,
          ),
        ],
        specialRules: const CombatSpecialRules(linkhandActive: true),
      ),
    );

    final noOffhandResult = preview(noOffhand);
    final withOffhandResult = preview(withOffhand);

    // WdS 71: Der AT-WM der Parierwaffe gilt für ihren eigenen Angriff.
    expect(withOffhandResult.at, noOffhandResult.at);
    expect(withOffhandResult.pa, noOffhandResult.pa - 1);
  });

  test('parry weapon requires Linkhand and scales with parry abilities', () {
    final baseHero = hero(
      talents: const {'tal_waffe': HeroTalentEntry(atValue: 6, paValue: 6)},
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(
          talentId: 'tal_waffe',
          name: 'Waffe',
          weaponType: 'Waffe',
        ),
        offhandAssignment: OffhandAssignment(equipmentIndex: 0),
        offhandEquipment: <OffhandEquipmentEntry>[
          OffhandEquipmentEntry(
            name: 'Parierdolch',
            type: OffhandEquipmentType.parryWeapon,
            paMod: 2,
          ),
        ],
      ),
    );

    final withoutLinkhand = preview(baseHero);
    final withLinkhand = preview(
      baseHero.copyWith(
        combatConfig: baseHero.combatConfig.copyWith(
          specialRules: const CombatSpecialRules(linkhandActive: true),
        ),
      ),
    );
    final withPw1 = preview(
      baseHero.copyWith(
        combatConfig: baseHero.combatConfig.copyWith(
          specialRules: const CombatSpecialRules(
            linkhandActive: true,
            parierwaffenI: true,
          ),
        ),
      ),
    );
    final withPw2 = preview(
      baseHero.copyWith(
        combatConfig: baseHero.combatConfig.copyWith(
          specialRules: const CombatSpecialRules(
            linkhandActive: true,
            parierwaffenII: true,
          ),
        ),
      ),
    );

    expect(withoutLinkhand.offhandRequiresLinkhand, isTrue);
    expect(withLinkhand.offhandPaBonus, -2);
    expect(withPw1.offhandPaBonus, 1);
    expect(withPw2.offhandPaBonus, 4);
  });

  test(
    'offhand weapon applies false hand penalties based on active abilities',
    () {
      final baseHero = hero(
        talents: const {
          'tal_schwert': HeroTalentEntry(atValue: 8, paValue: 7),
          'tal_dolch': HeroTalentEntry(atValue: 8, paValue: 7),
        },
        combatConfig: const CombatConfig(
          weapons: <MainWeaponSlot>[
            MainWeaponSlot(
              name: 'Kurzschwert',
              talentId: 'tal_schwert',
              weaponType: 'Kurzschwert',
            ),
            MainWeaponSlot(
              name: 'Dolch',
              talentId: 'tal_dolch',
              weaponType: 'Dolch',
            ),
          ],
          selectedWeaponIndex: 0,
          offhandAssignment: OffhandAssignment(weaponIndex: 1),
        ),
      );

      final noSf = preview(baseHero);
      final withLinkhand = preview(
        baseHero.copyWith(
          combatConfig: baseHero.combatConfig.copyWith(
            specialRules: const CombatSpecialRules(linkhandActive: true),
          ),
        ),
      );
      final withBhk1 = preview(
        baseHero.copyWith(
          combatConfig: baseHero.combatConfig.copyWith(
            specialRules: const CombatSpecialRules(
              linkhandActive: true,
              activeCombatSpecialAbilityIds: <String>[
                'ksf_beidhaendiger_kampf_i',
              ],
            ),
          ),
        ),
      );
      final withBhk2 = preview(
        baseHero.copyWith(
          combatConfig: baseHero.combatConfig.copyWith(
            specialRules: const CombatSpecialRules(
              linkhandActive: true,
              activeCombatSpecialAbilityIds: <String>[
                'ksf_beidhaendiger_kampf_ii',
              ],
            ),
          ),
        ),
      );

      expect(noSf.offhandPreview, isNotNull);
      expect(noSf.offhandPreview!.falseHandAtMod, -9);
      expect(noSf.offhandPreview!.falseHandPaMod, -9);
      expect(withLinkhand.offhandPreview!.falseHandAtMod, -6);
      expect(withBhk1.offhandPreview!.falseHandAtMod, -3);
      expect(withBhk2.offhandPreview!.falseHandAtMod, 0);
      expect(withLinkhand.offhandPreview!.at, noSf.offhandPreview!.at! + 3);
      expect(withBhk1.offhandPreview!.at, noSf.offhandPreview!.at! + 6);
      expect(withBhk2.offhandPreview!.at, noSf.offhandPreview!.at! + 9);
      expect(withLinkhand.offhandPreview!.pa, noSf.offhandPreview!.pa! + 3);
      expect(withBhk1.offhandPreview!.pa, noSf.offhandPreview!.pa! + 6);
      expect(withBhk2.offhandPreview!.pa, noSf.offhandPreview!.pa! + 9);
    },
  );

  test(
    'two weapon snapshot exposes doppelangriff values for a weapon pair',
    () {
      final sheet = hero(
        talents: const {
          'tal_schwert': HeroTalentEntry(atValue: 8, paValue: 7),
          'tal_dolch': HeroTalentEntry(atValue: 8, paValue: 7),
        },
        combatConfig: const CombatConfig(
          weapons: <MainWeaponSlot>[
            MainWeaponSlot(
              name: 'Kurzschwert',
              talentId: 'tal_schwert',
              weaponType: 'Kurzschwert',
              distanceClass: 'N',
            ),
            MainWeaponSlot(
              name: 'Dolch',
              talentId: 'tal_dolch',
              weaponType: 'Dolch',
              distanceClass: 'N',
            ),
          ],
          selectedWeaponIndex: 0,
          offhandAssignment: OffhandAssignment(weaponIndex: 1),
          specialRules: CombatSpecialRules(
            linkhandActive: true,
            activeCombatSpecialAbilityIds: <String>[
              'ksf_beidhaendiger_kampf_i',
            ],
            activeManeuvers: <String>['man_doppelangriff'],
          ),
        ),
      );

      final result = preview(sheet);
      final snapshot = result.twoWeaponCombat;
      final option = snapshot?.optionFor(TwoWeaponActionType.doubleAttack);

      expect(snapshot, isNotNull);
      expect(snapshot!.attackCapablePair, isTrue);
      expect(option, isNotNull);
      expect(option!.isAvailable, isTrue);
      expect(option.mainAttackTarget, result.at - 2);
      expect(option.offhandAttackTarget, result.offhandPreview!.at! - 6);
    },
  );

  test('two weapon snapshot exposes extra parry from parierwaffen ii', () {
    final sheet = hero(
      talents: const {'tal_waffe': HeroTalentEntry(atValue: 6, paValue: 6)},
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(
          talentId: 'tal_waffe',
          name: 'Waffe',
          weaponType: 'Waffe',
        ),
        offhandAssignment: OffhandAssignment(equipmentIndex: 0),
        offhandEquipment: <OffhandEquipmentEntry>[
          OffhandEquipmentEntry(
            name: 'Parierdolch',
            type: OffhandEquipmentType.parryWeapon,
            paMod: 2,
          ),
        ],
        specialRules: CombatSpecialRules(
          linkhandActive: true,
          parierwaffenII: true,
        ),
      ),
    );

    final result = preview(sheet);
    final option = result.twoWeaponCombat?.optionFor(
      TwoWeaponActionType.extraOffhandParry,
    );

    expect(option, isNotNull);
    expect(option!.isAvailable, isTrue);
    expect(option.offhandParryTarget, result.paMitIniParadeMod);
  });

  test('shield creates its own shield parade and does not change main PA', () {
    final baseHero = hero(
      talents: const {'tal_waffe': HeroTalentEntry(atValue: 6, paValue: 6)},
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(
          talentId: 'tal_waffe',
          name: 'Waffe',
          weaponType: 'Waffe',
        ),
        offhandAssignment: OffhandAssignment(equipmentIndex: 0),
        offhandEquipment: <OffhandEquipmentEntry>[
          OffhandEquipmentEntry(
            name: 'Turmschild',
            type: OffhandEquipmentType.shield,
            paMod: 2,
            atMod: -1,
            iniMod: -2,
          ),
        ],
      ),
    );

    final noSf = preview(baseHero);
    final withShield2 = preview(
      baseHero.copyWith(
        combatConfig: baseHero.combatConfig.copyWith(
          specialRules: const CombatSpecialRules(
            linkhandActive: true,
            schildkampfII: true,
          ),
        ),
      ),
    );

    expect(noSf.offhandIsShield, isTrue);
    expect(noSf.shieldPa, noSf.paBase + 2);
    expect(withShield2.shieldPa, withShield2.paBase + 7);
    expect(withShield2.offhandPaBonus, 0);
    expect(withShield2.offhandAtMod, -1);
    expect(withShield2.offhandIniMod, -2);
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

  test(
    'combat preview exposes active waffenmeister contributions explicitly',
    () {
      final sheet = hero(
        talents: const {
          'tal_dolche': HeroTalentEntry(
            atValue: 6,
            paValue: 5,
            combatSpecializations: <String>['Dolch'],
          ),
        },
        combatConfig: const CombatConfig(
          mainWeapon: MainWeaponSlot(
            name: 'Dolch',
            talentId: 'tal_dolche',
            weaponType: 'Dolch',
            kkBase: 12,
            kkThreshold: 2,
          ),
          waffenmeisterschaften: <WaffenmeisterConfig>[
            WaffenmeisterConfig(
              talentId: 'tal_dolche',
              weaponType: 'Dolch',
              bonuses: <WaffenmeisterBonus>[
                WaffenmeisterBonus(
                  type: WaffenmeisterBonusType.atWmBonus,
                  value: 1,
                ),
                WaffenmeisterBonus(
                  type: WaffenmeisterBonusType.paWmBonus,
                  value: 1,
                ),
                WaffenmeisterBonus(
                  type: WaffenmeisterBonusType.iniBonus,
                  value: 1,
                ),
                WaffenmeisterBonus(type: WaffenmeisterBonusType.tpKkReduction),
                WaffenmeisterBonus(
                  type: WaffenmeisterBonusType.maneuverReduction,
                  value: 2,
                  targetManeuver: 'Finte',
                ),
                WaffenmeisterBonus(
                  type: WaffenmeisterBonusType.additionalManeuver,
                  targetManeuver: 'Wuchtschlag',
                  value: 1,
                ),
              ],
            ),
          ],
        ),
      );

      final result = preview(sheet);

      expect(result.waffenmeisterActive, isTrue);
      expect(result.waffenmeisterAtBonus, 1);
      expect(result.waffenmeisterPaBonus, 1);
      expect(result.waffenmeisterIniBonus, 1);
      expect(result.waffenmeisterTpKkBaseReduction, -1);
      expect(result.waffenmeisterTpKkThresholdReduction, -1);
      expect(result.waffenmeisterManeuverReductions['man_finte'], 2);
      expect(
        result.waffenmeisterAdditionalManeuvers,
        contains('man_wuchtschlag'),
      );
    },
  );

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

  test('GS is reduced directly by BE after Ruestungsgewoehnung', () {
    final sheet = heroWithAttributes(
      ge: 16,
      combatConfig: const CombatConfig(
        armor: ArmorConfig(
          globalArmorTrainingLevel: 1,
          pieces: <ArmorPiece>[
            ArmorPiece(
              name: 'Kettenhemd',
              isActive: true,
              be: 2,
              rg1Active: true,
            ),
          ],
        ),
      ),
    );

    final result = computeDerivedStats(sheet, state);

    expect(result.gs, 8);
  });

  test('Flink and Behaebig adjust GS directly', () {
    final baseline = computeDerivedStats(hero(), state);
    final flink = computeDerivedStats(hero(vorteileText: 'Flink'), state);
    final behaebig = computeDerivedStats(
      hero(nachteileText: 'Behaebig'),
      state,
    );

    expect(flink.gs, baseline.gs + 1);
    expect(behaebig.gs, baseline.gs - 1);
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
