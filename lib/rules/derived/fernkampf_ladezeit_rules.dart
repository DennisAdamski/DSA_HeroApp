import 'package:dsa_heldenverwaltung/domain/combat_config/combat_special_rules.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/main_weapon_slot.dart';
import 'package:dsa_heldenverwaltung/rules/derived/excel_rounding.dart';
import 'package:dsa_heldenverwaltung/rules/derived/string_normalize.dart';

/// Abgeleiteter Aktivstatus einer Kampf-Sonderfertigkeit.
class CombatSpecialAbilityStatus {
  /// Beschreibt, ob eine SF besessen, aktiv und temporaer aktiv ist.
  const CombatSpecialAbilityStatus({
    required this.isOwned,
    required this.isActive,
    required this.isTemporary,
  });

  /// Die SF ist dauerhaft auf dem Helden gespeichert.
  final bool isOwned;

  /// Die SF wirkt aktuell in der Berechnung oder Anzeige.
  final bool isActive;

  /// Die aktuelle Wirkung stammt nur aus einem temporären Effekt.
  final bool isTemporary;
}

/// Ergebnis der abgeleiteten Fernkampf-Ladezeit.
class RangedReloadTimeResult {
  /// Kapselt effektive Ladezeit und die relevanten SF-Aktivierungen.
  const RangedReloadTimeResult({
    required this.baseReloadTime,
    required this.effectiveReloadTime,
    required this.displayLabel,
    required this.schnellziehen,
    required this.schnellladenBogen,
    required this.schnellladenArmbrust,
  });

  /// Urspruengliche Ladezeit der Waffe.
  final int baseReloadTime;

  /// Effektive Ladezeit in Aktionen.
  final int effectiveReloadTime;

  /// Lesbare Ausgabe fuer die UI.
  final String displayLabel;

  /// Abgeleiteter Aktivstatus fuer Schnellziehen.
  final CombatSpecialAbilityStatus schnellziehen;

  /// Abgeleiteter Aktivstatus fuer Schnellladen (Bogen).
  final CombatSpecialAbilityStatus schnellladenBogen;

  /// Abgeleiteter Aktivstatus fuer Schnellladen (Armbrust).
  final CombatSpecialAbilityStatus schnellladenArmbrust;
}

/// Berechnet die effektive Ladezeit einer Fernkampfwaffe.
RangedReloadTimeResult computeRangedReloadTime({
  required MainWeaponSlot weapon,
  required CombatSpecialRules specialRules,
  required bool axxeleratusActive,
  required String? talentName,
  int reloadModifier = 0,
  int reloadDivisor = 1,
}) {
  final baseReloadTime = weapon.rangedProfile.reloadTime;
  final weaponKind = _resolveWeaponReloadKind(
    weapon: weapon,
    talentName: talentName,
  );
  final schnellziehen = CombatSpecialAbilityStatus(
    isOwned: specialRules.schnellziehen,
    isActive: specialRules.schnellziehen || axxeleratusActive,
    isTemporary: axxeleratusActive && !specialRules.schnellziehen,
  );
  final ownsBogen = specialRules.activeManeuvers.contains(
    'man_schnellladen_bogen',
  );
  final ownsArmbrust = specialRules.activeManeuvers.contains(
    'man_schnellladen_armbrust',
  );
  final schnellladenBogen = CombatSpecialAbilityStatus(
    isOwned: ownsBogen,
    isActive: ownsBogen || axxeleratusActive,
    isTemporary: axxeleratusActive && !ownsBogen,
  );
  final schnellladenArmbrust = CombatSpecialAbilityStatus(
    isOwned: ownsArmbrust,
    isActive: ownsArmbrust || axxeleratusActive,
    isTemporary: axxeleratusActive && !ownsArmbrust,
  );

  var effectiveReloadTime = switch (weaponKind) {
    _RangedReloadKind.bogen => _computeBogenReloadTime(
      baseReloadTime: baseReloadTime,
      hasOwnedAbility: ownsBogen,
      hasActiveAbility: schnellladenBogen.isActive,
      axxeleratusActive: axxeleratusActive,
    ),
    _RangedReloadKind.armbrust => _computeArmbrustReloadTime(
      baseReloadTime: baseReloadTime,
      hasOwnedAbility: ownsArmbrust,
      hasActiveAbility: schnellladenArmbrust.isActive,
      axxeleratusActive: axxeleratusActive,
    ),
    _RangedReloadKind.none => clampNonNegative(baseReloadTime),
  };
  final normalizedReloadDivisor = reloadDivisor < 1 ? 1 : reloadDivisor;
  if (normalizedReloadDivisor > 1) {
    effectiveReloadTime = excelRound(
      effectiveReloadTime / normalizedReloadDivisor,
    );
  }
  effectiveReloadTime = clampNonNegative(effectiveReloadTime + reloadModifier);
  if (baseReloadTime > 0 && effectiveReloadTime < 1) {
    effectiveReloadTime = 1;
  }

  return RangedReloadTimeResult(
    baseReloadTime: clampNonNegative(baseReloadTime),
    effectiveReloadTime: effectiveReloadTime,
    displayLabel: formatReloadTimeActions(effectiveReloadTime),
    schnellziehen: schnellziehen,
    schnellladenBogen: schnellladenBogen,
    schnellladenArmbrust: schnellladenArmbrust,
  );
}

/// Formatiert eine Ladezeit als Aktions-Text.
String formatReloadTimeActions(int value) {
  final normalized = clampNonNegative(value);
  if (normalized == 1) {
    return '1 Aktion';
  }
  return '$normalized Aktionen';
}

int _computeBogenReloadTime({
  required int baseReloadTime,
  required bool hasOwnedAbility,
  required bool hasActiveAbility,
  required bool axxeleratusActive,
}) {
  var result = clampNonNegative(baseReloadTime);
  if (hasActiveAbility) {
    result -= 1;
  }
  if (hasOwnedAbility && axxeleratusActive) {
    result -= 1;
  }
  return result < 1 ? 1 : result;
}

int _computeArmbrustReloadTime({
  required int baseReloadTime,
  required bool hasOwnedAbility,
  required bool hasActiveAbility,
  required bool axxeleratusActive,
}) {
  var result = clampNonNegative(baseReloadTime);
  if (hasActiveAbility) {
    final reduction = excelRound(baseReloadTime * 3 / 4);
    result -= reduction;
  }
  if (hasOwnedAbility && axxeleratusActive) {
    result -= 1;
  }
  return result < 1 ? 1 : result;
}

_RangedReloadKind _resolveWeaponReloadKind({
  required MainWeaponSlot weapon,
  required String? talentName,
}) {
  final normalizedTalent = normalizeCombatToken(talentName ?? '');
  if (normalizedTalent == 'boegen' || normalizedTalent == 'bogen') {
    return _RangedReloadKind.bogen;
  }
  if (normalizedTalent == 'armbrust' || normalizedTalent == 'armbrueste') {
    return _RangedReloadKind.armbrust;
  }
  final normalizedWeaponType = normalizeCombatToken(weapon.weaponType);
  if (normalizedWeaponType.contains('armbrust') ||
      normalizedWeaponType.contains('balestra') ||
      normalizedWeaponType.contains('arbal')) {
    return _RangedReloadKind.armbrust;
  }
  if (normalizedWeaponType.contains('bogen')) {
    return _RangedReloadKind.bogen;
  }
  return _RangedReloadKind.none;
}

enum _RangedReloadKind { none, bogen, armbrust }
