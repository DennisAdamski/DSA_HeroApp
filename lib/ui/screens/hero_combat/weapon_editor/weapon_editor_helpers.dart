import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/rules/derived/string_normalize.dart';

/// Normalisiert Legacy-Fernkampfwaffen auf das aktuelle Distanzschema.
MainWeaponSlot normalizeWeaponEditorSlot(MainWeaponSlot slot) {
  if (!slot.isRanged) {
    return slot;
  }
  return slot.copyWith(rangedProfile: slot.rangedProfile.copyWith());
}

/// Leitet den Kampftyp aus dem Talent ab.
WeaponCombatType combatTypeForTalent(TalentDef talent) {
  return talent.type.trim().toLowerCase() == 'fernkampf'
      ? WeaponCombatType.ranged
      : WeaponCombatType.melee;
}

/// Ermittelt den Kampftyp aus einer Katalogwaffe.
WeaponCombatType combatTypeForCatalogWeapon(WeaponDef weapon) {
  return weaponCombatTypeFromJson(weapon.type);
}

/// Liefert alle Talente fuer den gewaehlten Kampftyp.
List<TalentDef> combatTypeTalents(
  List<TalentDef> combatTalents,
  WeaponCombatType combatType,
) {
  return combatTalents
      .where((talent) => combatTypeForTalent(talent) == combatType)
      .toList(growable: false)
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

/// Liefert die verfuegbaren Waffenarten fuer den aktuellen Kampftyp.
List<String> weaponTypeOptionsForCatalogWeapons(
  List<WeaponDef> catalogWeapons,
  MainWeaponSlot draftWeapon,
) {
  final seen = <String>{};
  final options = <String>[];
  for (final weapon in catalogWeapons) {
    if (combatTypeForCatalogWeapon(weapon) != draftWeapon.combatType) {
      continue;
    }
    final name = weapon.name.trim();
    if (name.isEmpty || !seen.add(name)) {
      continue;
    }
    options.add(name);
  }
  final current = draftWeapon.weaponType.trim();
  if (current.isNotEmpty && seen.add(current)) {
    options.add(current);
  }
  options.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return options;
}

/// Filtert Talente passend zur Waffenart.
List<TalentDef> talentOptionsForWeaponType({
  required String weaponType,
  required MainWeaponSlot draftWeapon,
  required List<TalentDef> combatTalents,
  required List<WeaponDef> catalogWeapons,
}) {
  final token = normalizeCombatToken(weaponType);
  final filteredTalents = combatTypeTalents(
    combatTalents,
    draftWeapon.combatType,
  );
  if (token.isEmpty) {
    return filteredTalents;
  }

  final allowedById = <String>{};
  for (final weapon in catalogWeapons) {
    if (combatTypeForCatalogWeapon(weapon) != draftWeapon.combatType) {
      continue;
    }
    if (normalizeCombatToken(weapon.name) != token) {
      continue;
    }
    final skillToken = normalizeCombatToken(weapon.combatSkill);
    for (final talent in filteredTalents) {
      if (normalizeCombatToken(talent.name) == skillToken) {
        allowedById.add(talent.id);
      }
    }
  }

  for (final talent in filteredTalents) {
    final categories = talent.weaponCategory.split(RegExp(r'[\n,;]+'));
    for (final category in categories) {
      if (normalizeCombatToken(category) == token) {
        allowedById.add(talent.id);
        break;
      }
    }
  }

  return filteredTalents
      .where((talent) => allowedById.contains(talent.id))
      .toList(growable: false)
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

/// Prueft, ob ein Talent zur aktuellen Waffenart passt.
bool isTalentValidForWeaponType({
  required String talentId,
  required String weaponType,
  required MainWeaponSlot draftWeapon,
  required List<TalentDef> combatTalents,
  required List<WeaponDef> catalogWeapons,
}) {
  if (talentId.trim().isEmpty) {
    return true;
  }
  return talentOptionsForWeaponType(
    weaponType: weaponType,
    draftWeapon: draftWeapon,
    combatTalents: combatTalents,
    catalogWeapons: catalogWeapons,
  ).any((talent) => talent.id == talentId.trim());
}
