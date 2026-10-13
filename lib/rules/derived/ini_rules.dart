import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/excel_rounding.dart';

/// INI-Grundwert aus Eigenschaften: round((MU+MU+IN+GE)/5).
int grundwertIni(Attributes a) => excelRound((a.mu + a.mu + a.inn + a.ge) / 5);

/// INI-Basisbonus der Sonderfertigkeit Kampfreflexe.
const int kKampfreflexeIniBonus = 4;

/// INI-Basisbonus der Sonderfertigkeit Kampfgespür.
const int kKampfgespuerIniBonus = 2;

// INI-Basiswert aus Eigenschaften: round((MU+MU+IN+GE)/5) + Mod.
int computeIniBase(HeroSheet sheet, StatModifiers mods) {
  return grundwertIni(sheet.attributes) + mods.iniBase;
}

// INI-Basis-Modifikatoren aus Kampfsonderfertigkeiten.
int computeIniBaseBonus(CombatSpecialRules special) {
  var total = 0;
  if (special.kampfreflexe) {
    total += kKampfreflexeIniBonus;
  }
  if (special.kampfgespuer) {
    total += kKampfgespuerIniBonus;
  }
  return total;
}

// Zusätzlicher SF-Bonus auf Initiative oberhalb der Basis.
int computeSfIniBonus(
  CombatSpecialRules special, {
  required bool hasFlinkFromVorteile,
  required bool hasBehaebigFromNachteile,
}) {
  return 0;
}

// GE-basierter Waffenkomponent der Initiative.
//
// Waffen definieren ihre TP-Staerke ueber einen KK-Bereich ([kkBase], [kkThreshold]).
// Analog dazu gibt es einen GE-Anteil fuer die Initiative: leichte, kurze
// Waffen bevorzugen GE, schwere Kriegswaffen KK.
// Die Konstante 26 ist die Spiegelkonstante zur KK-Basis aus der Waffentabelle:
//   geBase = 26 - kkBase  →  die GE-Skala beginnt am entgegengesetzten Ende.
// Die Konstante 7 ist die Spiegelkonstante zum KK-Schwellenwert:
//   geThreshold = 7 - kkThreshold  →  GE-Aequivalent des KK-Stufensprungs.
// Ist geThreshold == 0 (kkThreshold == 7), ist kein GE-Beitrag moeglich.
int computeIniGe({
  required int ge,
  required int kkBase,
  required int kkThreshold,
}) {
  final normalizedThreshold = kkThreshold < 1 ? 1 : kkThreshold;
  final geBase = 26 - kkBase; // Spiegelkonstante zur KK-Basis
  final geThreshold =
      7 - normalizedThreshold; // Spiegelkonstante zum KK-Schwellenwert
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
