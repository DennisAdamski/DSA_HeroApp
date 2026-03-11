import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';

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

String _normalizeToken(String raw) {
  var value = raw.trim().toLowerCase();
  value = value
      .replaceAll(String.fromCharCode(228), 'ae')
      .replaceAll(String.fromCharCode(246), 'oe')
      .replaceAll(String.fromCharCode(252), 'ue')
      .replaceAll(String.fromCharCode(223), 'ss');
  return value.replaceAll(RegExp(r'[^a-z0-9]+'), '');
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
  final token = _normalizeToken(weaponType);
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
    if (_normalizeToken(weapon.name) != token) {
      continue;
    }
    final skillToken = _normalizeToken(weapon.combatSkill);
    for (final talent in filteredTalents) {
      if (_normalizeToken(talent.name) == skillToken) {
        allowedById.add(talent.id);
      }
    }
  }

  for (final talent in filteredTalents) {
    final categories = talent.weaponCategory.split(RegExp(r'[\n,;]+'));
    for (final category in categories) {
      if (_normalizeToken(category) == token) {
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
