import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampf_herleitung_rules.dart';

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
    this.schildarmWundMalus = 0,
    this.parierwaffeWm = 0,
    this.parierwaffeSf = 0,
    this.parierwaffeSfName,
    this.schildPaHerleitung,
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

  /// Wundabzug des Schildarms, der in [shieldPa] eingerechnet wurde.
  final int schildarmWundMalus;

  /// PA-WM der Parierwaffe; zusammen mit [parierwaffeSf] ist das
  /// [mainPaMod].
  final int parierwaffeWm;

  /// SF-Anteil der Parierwaffe (-4 ohne, -1 mit Parierwaffen I, +2 mit II).
  final int parierwaffeSf;

  /// Name der wirkenden Parierwaffen-SF; `null` ohne SF.
  final String? parierwaffeSfName;

  /// Herleitung der Schild-Parade (ARCH-04); [shieldPa] ist ihr Wert.
  final Herleitung? schildPaHerleitung;
}

/// Berechnet die Modifikatoren eines Schilds oder einer Parierwaffe.
///
/// [schildarmWundMalus] (≤ 0) sind die Armwunden des Schildarms; sie senken
/// die Schild-Parade (WdS S. 109: „wenn er diesen Arm benutzt“). Eine
/// Parierwaffe hat keinen eigenen PA-Wert und bleibt davon unberührt.
OffhandModifierSnapshot computeOffhandModifierSnapshot({
  required OffhandEquipmentEntry? equipment,
  required CombatSpecialRules specialRules,
  required int paBasis,
  int axxeleratusPa = 0,
  int schildarmWundMalus = 0,
  int paradeBehinderung = 0,
  int ebe = 0,
}) {
  if (equipment == null) {
    return const OffhandModifierSnapshot();
  }
  if (equipment.isShield) {
    final shieldSfBonus = computeShieldSfBonus(specialRules);
    final herleitung = herleiteSchildPa(
      paBasis: paBasis,
      axxeleratus: axxeleratusPa,
      schildWm: equipment.paMod,
      schildName: equipment.name,
      sfBonus: shieldSfBonus,
      sfName: schildSfName(specialRules),
      ebe: ebe,
      ebeAnteil: paradeBehinderung,
      armWunden: schildarmWundMalus,
    );
    return OffhandModifierSnapshot(
      atMod: equipment.atMod,
      iniMod: equipment.iniMod,
      shieldPa: herleitung.wert,
      schildPaHerleitung: herleitung,
      shieldPaBonus: equipment.paMod + shieldSfBonus,
      isShield: true,
      displayName: equipment.name,
      schildarmWundMalus: schildarmWundMalus,
    );
  }
  final hasLinkhand = specialRules.linkhandActive;
  if (!hasLinkhand) {
    return OffhandModifierSnapshot(
      atMod: 0,
      iniMod: equipment.iniMod,
      isParryWeapon: true,
      requiresLinkhandViolation: true,
      displayName: equipment.name,
    );
  }
  final sf = computeParryWeaponSfBonus(specialRules);
  return OffhandModifierSnapshot(
    atMod: 0,
    iniMod: equipment.iniMod,
    mainPaMod: equipment.paMod + sf,
    parierwaffeWm: equipment.paMod,
    parierwaffeSf: sf,
    parierwaffeSfName: parierwaffenSfName(specialRules),
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

/// Name der Sonderfertigkeit, die den Schildbonus liefert; `null` ohne.
String? schildSfName(CombatSpecialRules specialRules) {
  if (specialRules.schildkampfII) return 'Schildkampf II';
  if (specialRules.schildkampfI) return 'Schildkampf I';
  if (specialRules.linkhandActive) return 'Linkhand';
  return null;
}

/// Name der Sonderfertigkeit, die den Parierwaffenbonus liefert; `null`
/// ohne Parierwaffen-SF.
String? parierwaffenSfName(CombatSpecialRules specialRules) {
  if (specialRules.parierwaffenII) return 'Parierwaffen II';
  if (specialRules.parierwaffenI) return 'Parierwaffen I';
  return null;
}
