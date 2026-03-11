import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/combat_helpers.dart';

/// Baut aus einer Katalogwaffe einen editierbaren Waffen-Slot.
MainWeaponSlot weaponSlotFromCatalog(
  WeaponDef weapon,
  List<TalentDef> combatTalents,
) {
  final combatType = weaponCombatTypeFromJson(weapon.type);
  final tpMatch = RegExp(r'(\d+)W6([+-]\d+)?').firstMatch(weapon.tp);
  final tpDiceCount = int.tryParse(tpMatch?.group(1) ?? '') ?? 1;
  final tpFlat = int.tryParse(tpMatch?.group(2) ?? '') ?? 0;
  final tpkkMatch = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(weapon.tpkk);
  final kkBase = int.tryParse(tpkkMatch?.group(1) ?? '') ?? 0;
  final kkThreshold = int.tryParse(tpkkMatch?.group(2) ?? '') ?? 1;
  final rangedProfile = combatType == WeaponCombatType.ranged
      ? RangedWeaponProfile(
          reloadTime: weapon.reloadTime,
          distanceBands: weapon.rangedDistanceBands,
          projectiles: weapon.rangedProjectiles,
        )
      : const RangedWeaponProfile();
  return MainWeaponSlot(
    name: weapon.name,
    talentId: findTalentIdByName(weapon.combatSkill, combatTalents),
    combatType: combatType,
    weaponType: weapon.name,
    distanceClass: weapon.reach,
    kkBase: kkBase,
    kkThreshold: kkThreshold < 1 ? 1 : kkThreshold,
    tpDiceCount: tpDiceCount < 1 ? 1 : tpDiceCount,
    tpFlat: tpFlat,
    wmAt: weapon.atMod,
    wmPa: weapon.paMod,
    iniMod: weapon.iniMod,
    rangedProfile: rangedProfile,
  );
}
