import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/helpers_catalog_slot.dart';

void main() {
  test(
    'weaponSlotFromCatalog maps arsenal melee fields including negative BF',
    () {
      const weapon = WeaponDef(
        id: 'wpn_hakendolch',
        name: 'Hakendolch',
        type: 'Nahkampf',
        combatSkill: 'Dolche',
        tp: '1W6+1',
        tpkk: '12/4',
        atMod: 0,
        paMod: 1,
        iniMod: 0,
        breakFactor: '-2',
        reach: 'HN',
      );
      const talents = <TalentDef>[
        TalentDef(
          id: 'tal_dolche',
          name: 'Dolche',
          group: 'Kampftalent',
          steigerung: 'D',
          attributes: <String>[],
          type: 'Nahkampf',
        ),
      ];

      final slot = weaponSlotFromCatalog(weapon, talents);

      expect(slot.combatType, WeaponCombatType.melee);
      expect(slot.talentId, 'tal_dolche');
      expect(slot.breakFactor, -2);
      expect(slot.distanceClass, 'HN');
      expect(slot.kkBase, 12);
      expect(slot.kkThreshold, 4);
      expect(slot.tpDiceCount, 1);
      expect(slot.tpFlat, 1);
      expect(slot.wmAt, 0);
      expect(slot.wmPa, 1);
    },
  );

  test(
    'weaponSlotFromCatalog maps ranged profile and break factor defaults',
    () {
      const weapon = WeaponDef(
        id: 'wpn_kurzbogen',
        name: 'Kurzbogen',
        type: 'Fernkampf',
        combatSkill: 'Bogen',
        tp: '1W6+4*',
        atMod: 0,
        reloadTime: 2,
        rangedDistanceBands: <RangedDistanceBand>[
          RangedDistanceBand(label: '5', tpMod: 1),
          RangedDistanceBand(label: '15', tpMod: 1),
          RangedDistanceBand(label: '25', tpMod: 0),
          RangedDistanceBand(label: '40', tpMod: 0),
          RangedDistanceBand(label: '60', tpMod: -1),
        ],
      );
      const talents = <TalentDef>[
        TalentDef(
          id: 'tal_bogen',
          name: 'Bogen',
          group: 'Kampftalent',
          steigerung: 'E',
          attributes: <String>[],
          type: 'Fernkampf',
        ),
      ];

      final slot = weaponSlotFromCatalog(weapon, talents);

      expect(slot.combatType, WeaponCombatType.ranged);
      expect(slot.talentId, 'tal_bogen');
      expect(slot.breakFactor, 0);
      expect(slot.rangedProfile.reloadTime, 2);
      expect(slot.rangedProfile.distanceBands.length, 5);
      expect(slot.rangedProfile.distanceBands[0].label, '5');
      expect(slot.rangedProfile.distanceBands[4].tpMod, -1);
    },
  );
}
