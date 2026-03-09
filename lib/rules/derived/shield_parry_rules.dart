import 'package:dsa_heldenverwaltung/domain/combat_config.dart';

/// Beschreibt die aus einem Nebenhand-Eintrag abgeleiteten Kampfmodifikatoren.
class OffhandModifierSnapshot {
  const OffhandModifierSnapshot({
    this.atMod = 0,
    this.iniMod = 0,
    this.mainPaMod = 0,
    this.shieldPa = 0,
    this.shieldPaBonus = 0,
    this.isShield = false,
    this.isParryWeapon = false,
    this.requiresLinkhandViolation = false,
    this.displayName = '',
  });

  /// AT-Modifikator auf die Hauptwaffe.
  final int atMod;

  /// INI-Modifikator auf die Hauptwaffe.
  final int iniMod;

  /// PA-Modifikator auf die Hauptwaffe.
  final int mainPaMod;

  /// Eigenstaendige Schild-Parade.
  final int shieldPa;

  /// Gesamtbonus, der in die Schild-Parade eingerechnet wurde.
  final int shieldPaBonus;

  /// Kennzeichnet ein Schild.
  final bool isShield;

  /// Kennzeichnet eine Parierwaffe.
  final bool isParryWeapon;

  /// Markiert unzulaessige Parierwaffen ohne Linkhand-SF.
  final bool requiresLinkhandViolation;

  /// Anzeigename des aktiven Nebenhand-Eintrags.
  final String displayName;
}

/// Berechnet die Modifikatoren eines Schilds oder einer Parierwaffe.
OffhandModifierSnapshot computeOffhandModifierSnapshot({
  required OffhandEquipmentEntry? equipment,
  required CombatSpecialRules specialRules,
  required int paBase,
}) {
  if (equipment == null) {
    return const OffhandModifierSnapshot();
  }
  if (equipment.isShield) {
    final shieldSfBonus = computeShieldSfBonus(specialRules);
    return OffhandModifierSnapshot(
      atMod: equipment.atMod,
      iniMod: equipment.iniMod,
      shieldPa: paBase + equipment.paMod + shieldSfBonus,
      shieldPaBonus: equipment.paMod + shieldSfBonus,
      isShield: true,
      displayName: equipment.name,
    );
  }
  final hasLinkhand = specialRules.linkhandActive;
  if (!hasLinkhand) {
    return OffhandModifierSnapshot(
      atMod: equipment.atMod,
      iniMod: equipment.iniMod,
      isParryWeapon: true,
      requiresLinkhandViolation: true,
      displayName: equipment.name,
    );
  }
  return OffhandModifierSnapshot(
    atMod: equipment.atMod,
    iniMod: equipment.iniMod,
    mainPaMod: equipment.paMod + computeParryWeaponSfBonus(specialRules),
    isParryWeapon: true,
    displayName: equipment.name,
  );
}

/// Berechnet den SF-Bonus einer Parierwaffe.
int computeParryWeaponSfBonus(CombatSpecialRules specialRules) {
  if (specialRules.parierwaffenII) {
    return 2;
  }
  if (specialRules.parierwaffenI) {
    return -1;
  }
  return -4;
}

/// Berechnet den SF-Bonus eines Schilds.
int computeShieldSfBonus(CombatSpecialRules specialRules) {
  if (specialRules.schildkampfII) {
    return 5;
  }
  if (specialRules.schildkampfI) {
    return 3;
  }
  if (specialRules.linkhandActive) {
    return 1;
  }
  return 0;
}
