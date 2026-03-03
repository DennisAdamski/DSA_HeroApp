import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/excel_rounding.dart';

// INI-Basiswert aus Eigenschaften: round((MU+MU+IN+GE)/5) + Mod.
int computeIniBase(HeroSheet sheet, StatModifiers mods) {
  final mu = sheet.attributes.mu;
  final inn = sheet.attributes.inn;
  final ge = sheet.attributes.ge;
  return excelRound((mu + mu + inn + ge) / 5) + mods.iniBase;
}

// Sonderfertigkeit-Bonus auf Initiative (Kampfreflexe, Kampfgespuer, Flink, Behaebig).
int computeSfIniBonus(
  CombatSpecialRules special, {
  required bool hasFlinkFromVorteile,
  required bool hasBehaebigFromNachteile,
}) {
  var total = 0;
  if (special.kampfreflexe) {
    total += 4;
  }
  if (special.kampfgespuer) {
    total += 2;
  }
  if (hasFlinkFromVorteile) {
    total += 1;
  }
  if (hasBehaebigFromNachteile) {
    total -= 1;
  }
  return total;
}

// GE-basierter Waffenkomponent der Initiative.
int computeIniGe({
  required int ge,
  required int kkBase,
  required int kkThreshold,
}) {
  final normalizedThreshold = kkThreshold < 1 ? 1 : kkThreshold;
  final geBase = 26 - kkBase;
  final geThreshold = 7 - normalizedThreshold;
  if (geThreshold == 0) {
    return 0;
  }
  return roundDownTowardsZero((ge - geBase) / geThreshold);
}

// Anzahl Ini-Wuerfel: 1 normal, 2 bei Klingentaenzer.
int computeIniDiceCount(CombatSpecialRules special) {
  return special.klingentaenzer ? 2 : 1;
}

// Ini-Parade-Mod: max(0, truncate((kampfInitiative - 11) / 10)).
int computeIniParadeMod(int kampfInitiative) {
  final raw = roundDownTowardsZero((kampfInitiative - 11) / 10);
  return raw > 0 ? raw : 0;
}
