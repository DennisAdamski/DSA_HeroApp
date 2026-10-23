part of 'combat_rules_test.dart';

void _combatBasis() {
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

  test('TP/KK 0/0 disables TP/KK and INI/GE calculations', () {
    const combatConfig = CombatConfig(
      mainWeapon: MainWeaponSlot(
        name: 'Testwaffe',
        kkBase: 0,
        kkThreshold: 0,
        iniMod: 3,
      ),
    );
    final sheet = heroWithAttributes(
      kk: 18,
      ge: 18,
      combatConfig: combatConfig,
    );

    final result = preview(sheet);

    expect(result.usesTpKkThreshold, isFalse);
    expect(result.tpKk, 0);
    expect(result.geBase, 0);
    expect(result.geThreshold, 0);
    expect(result.iniGe, 0);
    expect(result.kombinierteHeldenWaffenIni, result.heldenInitiative + 3);
  });

  test('Ini Parade Mod is never negative', () {
    const baseCombatConfig = CombatConfig(
      mainWeapon: MainWeaponSlot(name: 'Testwaffe', kkBase: 15, kkThreshold: 3),
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
    expect(referenceResult.iniBasis, 10);
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

  test('kampf initiative includes only weapon/offhand ini mods on top of helden initiative', () {
    final sheet = hero(
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(iniMod: 3),
        offhandAssignment: OffhandAssignment(equipmentIndex: 0),
        offhandEquipment: <OffhandEquipmentEntry>[
          OffhandEquipmentEntry(type: OffhandEquipmentType.shield, iniMod: -1),
        ],
        manualMods: CombatManualMods(iniWurf: 2),
      ),
    );

    final result = preview(sheet);
    expect(
      result.kombinierteHeldenWaffenIni,
      result.heldenInitiative + 3 + result.iniGe,
    );
    expect(result.kampfInitiative, result.kombinierteHeldenWaffenIni - 1);
  });

  test('kampf initiative uses the higher value of main and offhand weapon', () {
    final sheet = hero(
      combatConfig: const CombatConfig(
        weapons: <MainWeaponSlot>[
          MainWeaponSlot(
            name: 'Kurzschwert',
            iniMod: 1,
            kkBase: 12,
            kkThreshold: 2,
          ),
          MainWeaponSlot(name: 'Dolch', iniMod: 4, kkBase: 14, kkThreshold: 1),
        ],
        selectedWeaponIndex: 0,
        offhandAssignment: OffhandAssignment(weaponIndex: 1),
      ),
    );

    final result = preview(sheet);

    expect(result.kombinierteHeldenWaffenIni, result.heldenInitiative + 1);
    expect(result.offhandWeaponInitiative, result.heldenInitiative + 4);
    expect(result.kampfInitiative, result.offhandWeaponInitiative);
  });

  test('kombinierte Helden+Waffen INI includes weapon ini mod and INI/GE', () {
    final hero = heroWithAttributes(
      ge: 21,
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(iniMod: 3, kkBase: 10, kkThreshold: 3),
        offhandAssignment: OffhandAssignment(equipmentIndex: 0),
        offhandEquipment: <OffhandEquipmentEntry>[
          OffhandEquipmentEntry(type: OffhandEquipmentType.shield, iniMod: -1),
        ],
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
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(name: 'Testwaffe', iniMod: 0),
      ),
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

  test('Flink from Vorteile adds +1 GS and +1 Ausweichen, but no INI', () {
    final withoutFlink = hero();
    final withFlink = hero(vorteileText: 'Flink');

    final withoutResult = preview(withoutFlink);
    final withResult = preview(withFlink);
    final withoutDerived = computeDerivedStats(withoutFlink, state);
    final withDerived = computeDerivedStats(withFlink, state);

    expect(withResult.sfIniBonus, withoutResult.sfIniBonus);
    expect(withResult.heldenInitiative, withoutResult.heldenInitiative);
    expect(withResult.sfAusweichenBonus, withoutResult.sfAusweichenBonus);
    expect(withResult.ausweichenMod, withoutResult.ausweichenMod + 1);
    expect(withResult.ausweichen, withoutResult.ausweichen + 1);
    expect(withDerived.gs, withoutDerived.gs + 1);
  });

  test('Behaebig from Nachteile gives -1 GS and -1 Ausweichen, but no INI', () {
    final withoutBehaebig = hero();
    final withBehaebig = hero(nachteileText: 'Behaebig');

    final withoutResult = preview(withoutBehaebig);
    final withResult = preview(withBehaebig);
    final withoutDerived = computeDerivedStats(withoutBehaebig, state);
    final withDerived = computeDerivedStats(withBehaebig, state);

    expect(withResult.sfIniBonus, withoutResult.sfIniBonus);
    expect(withResult.heldenInitiative, withoutResult.heldenInitiative);
    expect(withResult.sfAusweichenBonus, withoutResult.sfAusweichenBonus);
    expect(withResult.ausweichenMod, withoutResult.ausweichenMod - 1);
    expect(withResult.ausweichen, withoutResult.ausweichen - 1);
    expect(withDerived.gs, withoutDerived.gs - 1);
  });

  test('Flink and Behaebig from texts cancel each other', () {
    final baseline = hero();
    final withBoth = hero(vorteileText: 'Flink', nachteileText: 'Behaebig');

    final baselineResult = preview(baseline);
    final withBothResult = preview(withBoth);
    final baselineDerived = computeDerivedStats(baseline, state);
    final withBothDerived = computeDerivedStats(withBoth, state);

    expect(withBothResult.sfIniBonus, baselineResult.sfIniBonus);
    expect(withBothResult.heldenInitiative, baselineResult.heldenInitiative);
    expect(withBothResult.sfAusweichenBonus, baselineResult.sfAusweichenBonus);
    expect(withBothResult.ausweichenMod, baselineResult.ausweichenMod);
    expect(withBothResult.ausweichen, baselineResult.ausweichen);
    expect(withBothDerived.gs, baselineDerived.gs);
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

  test('bogen reload time uses Schnellladen and Axxeleratus correctly', () {
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
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(
          name: 'Elfenbogen',
          talentId: 'tal_boegen',
          combatType: WeaponCombatType.ranged,
          weaponType: 'Elfenbogen',
          rangedProfile: RangedWeaponProfile(reloadTime: 3),
        ),
      ),
    );
    final withOwnedAbility = base.copyWith(
      combatConfig: base.combatConfig.copyWith(
        specialRules: const CombatSpecialRules(
          activeManeuvers: ['man_schnellladen_bogen'],
        ),
      ),
    );

    expect(preview(base, catalogTalents: catalogTalents).reloadTime, 3);
    expect(
      preview(withOwnedAbility, catalogTalents: catalogTalents).reloadTime,
      2,
    );
    expect(
      preview(
        base,
        catalogTalents: catalogTalents,
        heroState: stateWithAxx,
      ).reloadTime,
      2,
    );
    expect(
      preview(
        withOwnedAbility,
        catalogTalents: catalogTalents,
        heroState: stateWithAxx,
      ).reloadTime,
      1,
    );
  });

  test('armbrust reload time uses rounded Schnellladen and Axxeleratus', () {
    const catalogTalents = <TalentDef>[
      TalentDef(
        id: 'tal_armbrust',
        name: 'Armbrust',
        group: 'Kampftalent',
        type: 'Fernkampf',
        steigerung: 'D',
        attributes: <String>['Intuition', 'Fingerfertigkeit', 'Koerperkraft'],
      ),
    ];
    final base = hero(
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(
          name: 'Schwere Armbrust',
          talentId: 'tal_armbrust',
          combatType: WeaponCombatType.ranged,
          weaponType: 'Schwere Armbrust',
          rangedProfile: RangedWeaponProfile(reloadTime: 4),
        ),
      ),
    );
    final withOwnedAbility = base.copyWith(
      combatConfig: base.combatConfig.copyWith(
        specialRules: const CombatSpecialRules(
          activeManeuvers: ['man_schnellladen_armbrust'],
        ),
      ),
    );

    expect(preview(base, catalogTalents: catalogTalents).reloadTime, 4);
    expect(
      preview(withOwnedAbility, catalogTalents: catalogTalents).reloadTime,
      3,
    );
    expect(
      preview(
        base,
        catalogTalents: catalogTalents,
        heroState: stateWithAxx,
      ).reloadTime,
      3,
    );
    expect(
      preview(
        withOwnedAbility,
        catalogTalents: catalogTalents,
        heroState: stateWithAxx,
      ).reloadTime,
      2,
    );
  });

  test('reload time display uses Aktionen label', () {
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
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(
          name: 'Kurzbogen',
          talentId: 'tal_boegen',
          combatType: WeaponCombatType.ranged,
          weaponType: 'Kurzbogen',
          rangedProfile: RangedWeaponProfile(reloadTime: 2),
        ),
      ),
    );
    final reduced = base.copyWith(
      combatConfig: base.combatConfig.copyWith(
        specialRules: const CombatSpecialRules(
          activeManeuvers: ['man_schnellladen_bogen'],
        ),
      ),
    );

    expect(
      preview(base, catalogTalents: catalogTalents).reloadTimeDisplay,
      '2 Aktionen',
    );
    expect(
      preview(reduced, catalogTalents: catalogTalents).reloadTimeDisplay,
      '1 Aktion',
    );
  });

  test('ranged AT uses full eBE instead of split AT share', () {
    const catalogTalents = <TalentDef>[
      TalentDef(
        id: 'tal_boegen',
        name: 'Boegen',
        group: 'Kampftalent',
        type: 'Fernkampf',
        steigerung: 'D',
        attributes: <String>['Intuition', 'Fingerfertigkeit', 'Koerperkraft'],
        be: '0',
      ),
    ];
    final sheet = hero(
      talents: const {
        'tal_boegen': HeroTalentEntry(talentValue: 8, atValue: 8),
      },
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(
          name: 'Kurzbogen',
          talentId: 'tal_boegen',
          combatType: WeaponCombatType.ranged,
          weaponType: 'Kurzbogen',
        ),
        armor: ArmorConfig(
          pieces: <ArmorPiece>[
            ArmorPiece(name: 'Kettenhemd', isActive: true, rs: 3, be: 3),
          ],
        ),
      ),
    );

    final result = preview(sheet, catalogTalents: catalogTalents);

    expect(result.ebe, -3);
    expect(result.at, result.rangedAtBase + 8 - 3);
  });
}
