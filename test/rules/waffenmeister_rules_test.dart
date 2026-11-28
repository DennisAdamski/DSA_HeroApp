import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config/waffenmeister_config.dart';
import 'package:dsa_heldenverwaltung/rules/derived/grossmeister_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/waffenmeister_rules.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Grundkosten
  // ---------------------------------------------------------------------------
  group('computeAutoPointCost', () {
    test('Steigerung C kostet 4 Punkte', () {
      expect(
        computeAutoPointCost(
          steigerung: 'C',
          isAttackOnly: false,
          hasAdditionalWeapons: false,
        ),
        4,
      );
    });

    test('Steigerung D kostet 2 Punkte', () {
      expect(
        computeAutoPointCost(
          steigerung: 'D',
          isAttackOnly: false,
          hasAdditionalWeapons: false,
        ),
        2,
      );
    });

    test('Steigerung E kostet 0 Punkte', () {
      expect(
        computeAutoPointCost(
          steigerung: 'E',
          isAttackOnly: false,
          hasAdditionalWeapons: false,
        ),
        0,
      );
    });

    test('Reine Angriffswaffe kostet zusaetzlich 4', () {
      expect(
        computeAutoPointCost(
          steigerung: 'E',
          isAttackOnly: true,
          hasAdditionalWeapons: false,
        ),
        4,
      );
    });

    test('Zusaetzliche Waffen kosten 2', () {
      expect(
        computeAutoPointCost(
          steigerung: 'E',
          isAttackOnly: false,
          hasAdditionalWeapons: true,
        ),
        2,
      );
    });

    test('Kombination: Steigerung D + Angriffswaffe + Mehrfachwaffe', () {
      expect(
        computeAutoPointCost(
          steigerung: 'D',
          isAttackOnly: true,
          hasAdditionalWeapons: true,
        ),
        2 + 4 + 2,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Punktekosten pro Bonus
  // ---------------------------------------------------------------------------
  group('computePointCostForBonus', () {
    test('Manoever-Reduktion: 1 Punkt pro -1', () {
      expect(
        computePointCostForBonus(
          const WaffenmeisterBonus(
            type: WaffenmeisterBonusType.maneuverReduction,
            value: 3,
          ),
        ),
        3,
      );
    });

    test('INI-Bonus: 3 Punkte pro +1', () {
      expect(
        computePointCostForBonus(
          const WaffenmeisterBonus(
            type: WaffenmeisterBonusType.iniBonus,
            value: 2,
          ),
        ),
        6,
      );
    });

    test('TP/KK: 2 Punkte', () {
      expect(
        computePointCostForBonus(
          const WaffenmeisterBonus(type: WaffenmeisterBonusType.tpKkReduction),
        ),
        2,
      );
    });

    test('AT-WM: 5 Punkte pro +1', () {
      expect(
        computePointCostForBonus(
          const WaffenmeisterBonus(
            type: WaffenmeisterBonusType.atWmBonus,
            value: 1,
          ),
        ),
        5,
      );
    });

    test('PA-WM: 5 Punkte pro +1', () {
      expect(
        computePointCostForBonus(
          const WaffenmeisterBonus(
            type: WaffenmeisterBonusType.paWmBonus,
            value: 2,
          ),
        ),
        10,
      );
    });

    test('Ausfall: 2 Punkte', () {
      expect(
        computePointCostForBonus(
          const WaffenmeisterBonus(
            type: WaffenmeisterBonusType.ausfallPenaltyRemoval,
          ),
        ),
        2,
      );
    });

    test('Zusatz-Manoever: 5 Punkte', () {
      expect(
        computePointCostForBonus(
          const WaffenmeisterBonus(
            type: WaffenmeisterBonusType.additionalManeuver,
          ),
        ),
        5,
      );
    });

    test('Reichweite: 1 Punkt pro +10%', () {
      expect(
        computePointCostForBonus(
          const WaffenmeisterBonus(
            type: WaffenmeisterBonusType.rangeIncrease,
            value: 2,
          ),
        ),
        2,
      );
    });

    test('Gezielter Schuss: 2 Punkte', () {
      expect(
        computePointCostForBonus(
          const WaffenmeisterBonus(
            type: WaffenmeisterBonusType.gezielterSchussReduction,
          ),
        ),
        2,
      );
    });

    test('Ladezeit: 5 Punkte', () {
      expect(
        computePointCostForBonus(
          const WaffenmeisterBonus(
            type: WaffenmeisterBonusType.reloadTimeHalved,
          ),
        ),
        5,
      );
    });

    test('Custom: customPointCost geclampt 2-5', () {
      expect(
        computePointCostForBonus(
          const WaffenmeisterBonus(
            type: WaffenmeisterBonusType.customAdvantage,
            customPointCost: 1,
          ),
        ),
        2,
      );
      expect(
        computePointCostForBonus(
          const WaffenmeisterBonus(
            type: WaffenmeisterBonusType.customAdvantage,
            customPointCost: 7,
          ),
        ),
        5,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Gesamtallokation
  // ---------------------------------------------------------------------------
  group('computeTotalAllocated', () {
    test('Summiert alle Boni korrekt', () {
      final bonuses = [
        const WaffenmeisterBonus(
          type: WaffenmeisterBonusType.iniBonus,
          value: 1,
        ), // 3
        const WaffenmeisterBonus(
          type: WaffenmeisterBonusType.maneuverReduction,
          value: 2,
          targetManeuver: 'Finte',
        ), // 2
        const WaffenmeisterBonus(
          type: WaffenmeisterBonusType.ausfallPenaltyRemoval,
        ), // 2
      ];
      expect(computeTotalAllocated(bonuses), 7);
    });

    test('Leere Liste ergibt 0', () {
      expect(computeTotalAllocated(const []), 0);
    });
  });

  // ---------------------------------------------------------------------------
  // Validierung
  // ---------------------------------------------------------------------------
  group('validateBonusAllocation', () {
    test('Gueltige Konfiguration wird akzeptiert', () {
      final config = WaffenmeisterConfig(
        talentId: 'tal_schwerter',
        weaponType: 'Langschwert',
        bonuses: const [
          WaffenmeisterBonus(type: WaffenmeisterBonusType.iniBonus, value: 1),
          WaffenmeisterBonus(
            type: WaffenmeisterBonusType.maneuverReduction,
            value: 2,
            targetManeuver: 'Finte',
          ),
          WaffenmeisterBonus(
            type: WaffenmeisterBonusType.ausfallPenaltyRemoval,
          ),
        ],
      );
      final result = validateBonusAllocation(
        config: config,
        autoPointCost: 0,
        talentType: 'Nahkampf',
        talentId: 'tal_schwerter',
      );
      expect(result.isValid, isTrue);
    });

    test('Budget ueberschritten wird erkannt', () {
      final config = WaffenmeisterConfig(
        talentId: 'tal_schwerter',
        weaponType: 'Langschwert',
        bonuses: const [
          WaffenmeisterBonus(
            type: WaffenmeisterBonusType.atWmBonus,
            value: 2,
          ), // 10
          WaffenmeisterBonus(
            type: WaffenmeisterBonusType.paWmBonus,
            value: 2,
          ), // 10
        ],
      );
      final result = validateBonusAllocation(
        config: config,
        autoPointCost: 0,
        talentType: 'Nahkampf',
        talentId: 'tal_schwerter',
      );
      expect(result.isValid, isFalse);
      expect(result.errors, contains(contains('Budget')));
    });

    test('INI ueber +2 wird erkannt', () {
      final config = WaffenmeisterConfig(
        talentId: 'tal_schwerter',
        weaponType: 'Langschwert',
        bonuses: const [
          WaffenmeisterBonus(type: WaffenmeisterBonusType.iniBonus, value: 2),
          WaffenmeisterBonus(type: WaffenmeisterBonusType.iniBonus, value: 1),
        ],
      );
      final result = validateBonusAllocation(
        config: config,
        autoPointCost: 0,
        talentType: 'Nahkampf',
        talentId: 'tal_schwerter',
      );
      expect(result.isValid, isFalse);
      expect(result.errors, contains(contains('INI')));
    });

    test('TP/KK bei Nicht-Dolch/Fechtwaffe wird abgelehnt', () {
      final config = WaffenmeisterConfig(
        talentId: 'tal_schwerter',
        weaponType: 'Langschwert',
        bonuses: const [
          WaffenmeisterBonus(type: WaffenmeisterBonusType.tpKkReduction),
        ],
      );
      final result = validateBonusAllocation(
        config: config,
        autoPointCost: 0,
        talentType: 'Nahkampf',
        talentId: 'tal_schwerter',
      );
      expect(result.isValid, isFalse);
      expect(result.errors, contains(contains('TP/KK')));
    });

    test('TP/KK bei Dolchen wird akzeptiert', () {
      final config = WaffenmeisterConfig(
        talentId: 'tal_dolche',
        weaponType: 'Langdolch',
        bonuses: const [
          WaffenmeisterBonus(type: WaffenmeisterBonusType.tpKkReduction),
        ],
      );
      final result = validateBonusAllocation(
        config: config,
        autoPointCost: 0,
        talentType: 'Nahkampf',
        talentId: 'tal_dolche',
      );
      expect(result.isValid, isTrue);
    });

    test('Ladezeit bei Nicht-Armbrust wird abgelehnt', () {
      final config = WaffenmeisterConfig(
        talentId: 'tal_bogen',
        weaponType: 'Langbogen',
        bonuses: const [
          WaffenmeisterBonus(type: WaffenmeisterBonusType.reloadTimeHalved),
        ],
      );
      final result = validateBonusAllocation(
        config: config,
        autoPointCost: 0,
        talentType: 'Fernkampf',
        talentId: 'tal_bogen',
      );
      expect(result.isValid, isFalse);
      expect(result.errors, contains(contains('Ladezeit')));
    });

    test('Zwei Manoever mit >2 Reduktion wird abgelehnt', () {
      final config = WaffenmeisterConfig(
        talentId: 'tal_schwerter',
        weaponType: 'Langschwert',
        bonuses: const [
          WaffenmeisterBonus(
            type: WaffenmeisterBonusType.maneuverReduction,
            value: 4,
            targetManeuver: 'Finte',
          ),
          WaffenmeisterBonus(
            type: WaffenmeisterBonusType.maneuverReduction,
            value: 3,
            targetManeuver: 'Entwaffnen',
          ),
        ],
      );
      final result = validateBonusAllocation(
        config: config,
        autoPointCost: 0,
        talentType: 'Nahkampf',
        talentId: 'tal_schwerter',
      );
      expect(result.isValid, isFalse);
      expect(result.errors, contains(contains('Manöver')));
    });
  });

  // ---------------------------------------------------------------------------
  // Effekt-Extraktion
  // ---------------------------------------------------------------------------
  group('computeWaffenmeisterEffects', () {
    final config = WaffenmeisterConfig(
      talentId: 'tal_schwerter',
      weaponType: 'Langschwert',
      bonuses: const [
        WaffenmeisterBonus(type: WaffenmeisterBonusType.iniBonus, value: 1),
        WaffenmeisterBonus(type: WaffenmeisterBonusType.atWmBonus, value: 1),
        WaffenmeisterBonus(
          type: WaffenmeisterBonusType.maneuverReduction,
          value: 2,
          targetManeuver: 'Finte',
        ),
        WaffenmeisterBonus(type: WaffenmeisterBonusType.ausfallPenaltyRemoval),
      ],
    );

    test('Passende Waffe gibt Effekte zurueck', () {
      final effects = computeWaffenmeisterEffects(
        waffenmeisterschaften: [config],
        activeWeaponType: 'Langschwert',
        activeTalentId: 'tal_schwerter',
      );
      expect(effects.isActive, isTrue);
      expect(effects.iniBonus, 1);
      expect(effects.atWmBonus, 1);
      expect(effects.maneuverReductions['man_finte'], 2);
      expect(effects.ausfallPenaltyRemoved, isTrue);
    });

    test('Nicht passendes Talent gibt keine Effekte', () {
      final effects = computeWaffenmeisterEffects(
        waffenmeisterschaften: [config],
        activeWeaponType: 'Langschwert',
        activeTalentId: 'tal_dolche',
      );
      expect(effects.isActive, isFalse);
    });

    test('Nicht passende Waffenart gibt keine Effekte', () {
      final effects = computeWaffenmeisterEffects(
        waffenmeisterschaften: [config],
        activeWeaponType: 'Breitschwert',
        activeTalentId: 'tal_schwerter',
      );
      expect(effects.isActive, isFalse);
    });

    test('Zusaetzliche Waffenart wird erkannt', () {
      final configMitExtra = config.copyWith(
        additionalWeaponTypes: ['Breitschwert'],
      );
      final effects = computeWaffenmeisterEffects(
        waffenmeisterschaften: [configMitExtra],
        activeWeaponType: 'Breitschwert',
        activeTalentId: 'tal_schwerter',
      );
      expect(effects.isActive, isTrue);
      expect(effects.iniBonus, 1);
    });

    test('Leere Liste gibt none zurueck', () {
      final effects = computeWaffenmeisterEffects(
        waffenmeisterschaften: const [],
        activeWeaponType: 'Langschwert',
        activeTalentId: 'tal_schwerter',
      );
      expect(effects.isActive, isFalse);
    });

    test('Leerer Waffenname gibt none zurueck', () {
      final effects = computeWaffenmeisterEffects(
        waffenmeisterschaften: [config],
        activeWeaponType: '',
        activeTalentId: 'tal_schwerter',
      );
      expect(effects.isActive, isFalse);
    });

    test('Zusatz-Manoever werden als stabile Manoever-IDs normalisiert', () {
      final effects = computeWaffenmeisterEffects(
        waffenmeisterschaften: [
          config.copyWith(
            bonuses: const [
              WaffenmeisterBonus(
                type: WaffenmeisterBonusType.additionalManeuver,
                targetManeuver: 'Finte',
                value: 1,
              ),
            ],
          ),
        ],
        activeWeaponType: 'Langschwert',
        activeTalentId: 'tal_schwerter',
      );

      expect(effects.additionalManeuvers, contains('man_finte'));
    });
  });
  group('Waffen-Großmeister (Epische Stufen S. 14–20)', () {
    test('per Waffenmeister erlaubte Manöver werden stattdessen um 4 '
        'erleichtert', () {
      final effects = computeWaffenmeisterEffects(
        waffenmeisterschaften: const [
          WaffenmeisterConfig(
            talentId: 'tal_saebel',
            weaponType: 'Khunchomer',
            bonuses: [
              WaffenmeisterBonus(
                type: WaffenmeisterBonusType.additionalManeuver,
                targetManeuver: 'Hammerschlag',
              ),
            ],
          ),
        ],
        activeWeaponType: 'Khunchomer',
        activeTalentId: 'tal_saebel',
        aktiveKampfSfIds: const ['esf_grossmeister_saebel'],
      );
      expect(effects.maneuverReductions['man_hammerschlag'], 4);
      expect(effects.additionalManeuvers, contains('man_schildspalter'));
      expect(effects.tpKkBaseReduction, 1);
      expect(effects.tpKkThresholdReduction, -1);
      expect(effects.waffenmeisterGefunden, isTrue);
    });

    test('Großmeister wirkt ohne passende Waffenmeisterschaft der Waffe', () {
      final effects = computeWaffenmeisterEffects(
        waffenmeisterschaften: const [],
        activeWeaponType: 'Langbogen',
        activeTalentId: 'tal_bogen',
        aktiveKampfSfIds: const ['esf_grossmeister_bogen'],
      );
      expect(effects.isActive, isTrue);
      expect(effects.waffenmeisterGefunden, isFalse);
      expect(effects.grossmeister.ladezeit, -1);
    });

    test('Ringen-Großmeister mit Bornländisch: AT und PA +1', () {
      final effects = computeWaffenmeisterEffects(
        waffenmeisterschaften: const [],
        activeWeaponType: 'Ringen',
        activeTalentId: 'tal_ringen',
        aktiveKampfSfIds: const [
          'esf_grossmeister_ringen',
          'ksf_bornlaendisch',
        ],
      );
      expect(effects.atWmBonus, 1);
      expect(effects.paWmBonus, 1);
    });

    test('Schleuder erhält festen TP/KK-Schlüssel, Lasso nicht', () {
      GrossmeisterEffekte gm(String waffe) => computeGrossmeisterEffekte(
        aktiveKampfSfIds: const ['esf_grossmeister_schleuder'],
        talentId: 'tal_schleuder',
        waffenTyp: waffe,
      );
      expect(gm('Schleuder').tpKkFestBasis, 12);
      expect(gm('Schleuder').tpKkFestSchwelle, 3);
      expect(gm('Lasso').tpKkFestBasis, isNull);
    });

    test('ohne erworbene SF kein Effekt', () {
      final effects = computeWaffenmeisterEffects(
        waffenmeisterschaften: const [],
        activeWeaponType: 'Rapier',
        activeTalentId: 'tal_fechtwaffen',
      );
      expect(effects.isActive, isFalse);
    });
  });
}
