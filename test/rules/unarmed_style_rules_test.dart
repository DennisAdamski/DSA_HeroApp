import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/unarmed_style_rules.dart';

void main() {
  const maneuvers = <ManeuverDef>[
    ManeuverDef(id: 'man_griff', name: 'Griff', gruppe: 'waffenlos'),
    ManeuverDef(id: 'man_wurf', name: 'Wurf', gruppe: 'waffenlos'),
    ManeuverDef(id: 'man_tritt', name: 'Tritt', gruppe: 'waffenlos'),
  ];

  const bornlaendisch = CombatSpecialAbilityDef(
    id: 'ksf_bornlaendisch',
    name: 'Bornländisch',
    stilTyp: 'waffenloser_kampfstil',
    aktiviertManoeverIds: <String>['man_griff', 'man_wurf'],
    kampfwertBoni: <CombatSpecialAbilityBonusDef>[
      CombatSpecialAbilityBonusDef(
        giltFuerTalent: 'ringen',
        atBonus: 1,
        paBonus: 1,
      ),
    ],
  );

  const gladiatorenstil = CombatSpecialAbilityDef(
    id: 'ksf_gladiatorenstil',
    name: 'Gladiatorenstil',
    stilTyp: 'waffenloser_kampfstil',
    aktiviertManoeverIds: <String>['man_tritt'],
    kampfwertBoni: <CombatSpecialAbilityBonusDef>[
      CombatSpecialAbilityBonusDef(
        giltFuerTalent: 'wahl',
        atBonus: 1,
        paBonus: 1,
      ),
    ],
  );

  const hammerfaust = CombatSpecialAbilityDef(
    id: 'ksf_hammerfaust',
    name: 'Hammerfaust',
    stilTyp: 'waffenloser_kampfstil',
    aktiviertManoeverIds: <String>['man_tritt'],
    kampfwertBoni: <CombatSpecialAbilityBonusDef>[
      CombatSpecialAbilityBonusDef(
        giltFuerTalent: 'raufen',
        atBonus: 1,
        paBonus: 1,
      ),
    ],
  );

  test('Bornländisch grants +1/+1 only for Ringen and activates maneuvers', () {
    const rules = CombatSpecialRules(
      activeCombatSpecialAbilityIds: <String>['ksf_bornlaendisch'],
    );

    final ringenEffects = computeActiveUnarmedStyleEffects(
      specialRules: rules,
      catalogCombatSpecialAbilities: const <CombatSpecialAbilityDef>[
        bornlaendisch,
      ],
      catalogManeuvers: maneuvers,
      activeTalentName: 'Ringen',
    );
    final raufenEffects = computeActiveUnarmedStyleEffects(
      specialRules: rules,
      catalogCombatSpecialAbilities: const <CombatSpecialAbilityDef>[
        bornlaendisch,
      ],
      catalogManeuvers: maneuvers,
      activeTalentName: 'Raufen',
    );

    expect(ringenEffects.atBonus, 1);
    expect(ringenEffects.paBonus, 1);
    expect(
      ringenEffects.activatedManeuverIds,
      containsAll(<String>['man_griff', 'man_wurf']),
    );
    expect(raufenEffects.atBonus, 0);
    expect(raufenEffects.paBonus, 0);
  });

  test('Gladiatorenstil applies only to the chosen talent', () {
    const rules = CombatSpecialRules(
      activeCombatSpecialAbilityIds: <String>['ksf_gladiatorenstil'],
      gladiatorStyleTalent: 'raufen',
    );

    final raufenEffects = computeActiveUnarmedStyleEffects(
      specialRules: rules,
      catalogCombatSpecialAbilities: const <CombatSpecialAbilityDef>[
        gladiatorenstil,
      ],
      catalogManeuvers: maneuvers,
      activeTalentName: 'Raufen',
    );
    final ringenEffects = computeActiveUnarmedStyleEffects(
      specialRules: rules,
      catalogCombatSpecialAbilities: const <CombatSpecialAbilityDef>[
        gladiatorenstil,
      ],
      catalogManeuvers: maneuvers,
      activeTalentName: 'Ringen',
    );

    expect(raufenEffects.atBonus, 1);
    expect(raufenEffects.paBonus, 1);
    expect(ringenEffects.atBonus, 0);
    expect(ringenEffects.paBonus, 0);
  });

  test('multiple active styles cap combined AT/PA bonus at +2/+2', () {
    const rules = CombatSpecialRules(
      activeCombatSpecialAbilityIds: <String>[
        'ksf_hammerfaust',
        'ksf_gladiatorenstil',
        'ksf_bornlaendisch',
      ],
      gladiatorStyleTalent: 'raufen',
    );

    final effects = computeActiveUnarmedStyleEffects(
      specialRules: rules,
      catalogCombatSpecialAbilities: const <CombatSpecialAbilityDef>[
        bornlaendisch,
        gladiatorenstil,
        hammerfaust,
      ],
      catalogManeuvers: maneuvers,
      activeTalentName: 'Raufen',
    );

    expect(effects.atBonus, 2);
    expect(effects.paBonus, 2);
  });

  test(
    'combat preview applies active unarmed style bonuses for matching talent',
    () {
      const sheet = HeroSheet(
        id: 'h',
        name: 'Unbewaffnet',
        level: 10,
        attributes: Attributes(
          mu: 12,
          kl: 12,
          inn: 12,
          ch: 12,
          ff: 12,
          ge: 12,
          ko: 12,
          kk: 12,
        ),
        talents: <String, HeroTalentEntry>{
          'tal_raufen': HeroTalentEntry(
            talentValue: 10,
            atValue: 8,
            paValue: 7,
          ),
        },
        combatConfig: CombatConfig(
          mainWeapon: MainWeaponSlot(name: 'Fäuste', talentId: 'tal_raufen'),
          specialRules: CombatSpecialRules(
            activeCombatSpecialAbilityIds: <String>['ksf_hammerfaust'],
          ),
        ),
        vorteileText: '',
        nachteileText: '',
      );

      final preview = computeCombatPreviewStats(
        sheet,
        const HeroState(
          currentLep: 0,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 0,
        ),
        catalogTalents: const <TalentDef>[
          TalentDef(
            id: 'tal_raufen',
            name: 'Raufen',
            group: 'Kampftalent',
            steigerung: 'D',
            attributes: <String>['MU', 'GE', 'KK'],
            type: 'Nahkampf',
          ),
        ],
        catalogManeuvers: maneuvers,
        catalogCombatSpecialAbilities: const <CombatSpecialAbilityDef>[
          hammerfaust,
        ],
      );

      expect(preview.at, 16);
      expect(preview.pa, 15);
    },
  );
}
