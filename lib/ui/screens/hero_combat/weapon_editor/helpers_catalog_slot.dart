import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/rules/derived/waffen_katalog_abgleich_rules.dart';
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
  final tpkk = leseKatalogTpKk(weapon.tpkk);
  final kkBase = tpkk?.basis ?? 0;
  final kkThreshold = tpkk?.schwelle ?? 1;
  final breakFactorMatch = RegExp(r'-?\d+').firstMatch(weapon.breakFactor);
  final breakFactor = int.tryParse(breakFactorMatch?.group(0) ?? '') ?? 0;
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
    kkThreshold: kkThreshold,
    breakFactor: breakFactor,
    tpDiceCount: tpDiceCount < 1 ? 1 : tpDiceCount,
    tpFlat: tpFlat,
    wmAt: weapon.atMod,
    wmPa: weapon.paMod,
    iniMod: weapon.iniMod,
    rangedProfile: rangedProfile,
  );
}
