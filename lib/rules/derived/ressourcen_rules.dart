import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ap_level_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/excel_rounding.dart';

int _cappedLevel(int level) => level > 21 ? 21 : (level < 0 ? 0 : level);

// Maximale Lebensenergie: round((KO+KO+KK)/2) + min(level,21) + gekauft + Mod.
int computeMaxLep(HeroSheet sheet, StatModifiers mods) {
  final ko = sheet.attributes.ko;
  final kk = sheet.attributes.kk;
  final base = excelRound((ko + ko + kk) / 2);
  final total = base + mods.lep + sheet.bought.lep + _cappedLevel(sheet.level);
  return clampNonNegative(total);
}

// Maximale Ausdauer: round((MU+KO+GE)/2) + level*2 + gekauft + Mod.
// Epische Charaktere erhalten keinen weiteren stufenweisen Au-Bonus ueber ihren
// Aktivierungs-Level hinaus.
int computeMaxAu(HeroSheet sheet, StatModifiers mods) {
  final mu = sheet.attributes.mu;
  final ko = sheet.attributes.ko;
  final ge = sheet.attributes.ge;
  final base = excelRound((mu + ko + ge) / 2);
  final levelForAu = sheet.isEpisch
      ? math.min(computeLevelFromSpentAp(sheet.epicStartAp), sheet.level)
      : sheet.level;
  final total = base + mods.au + sheet.bought.au + levelForAu * 2;
  return clampNonNegative(total);
}

// Maximale Astralenergie: round((MU+IN+CH)/2) + level*2 + gekauft + Mod.
int computeMaxAsp(HeroSheet sheet, StatModifiers mods) {
  final mu = sheet.attributes.mu;
  final inn = sheet.attributes.inn;
  final ch = sheet.attributes.ch;
  final base = excelRound((mu + inn + ch) / 2);
  final total = base + mods.asp + sheet.bought.asp + sheet.level * 2;
  return clampNonNegative(total);
}

// Maximale Karmaenergie: nur gekauft + Mod (kein Attribut-Basiswert).
int computeMaxKap(HeroSheet sheet, StatModifiers mods) {
  final total = mods.kap + sheet.bought.kap;
  return clampNonNegative(total);
}

// Magieresistenz: round((MU+KL+KO)/5) + gekauft + Mod.
int computeMr(HeroSheet sheet, StatModifiers mods) {
  final mu = sheet.attributes.mu;
  final kl = sheet.attributes.kl;
  final ko = sheet.attributes.ko;
  final base = excelRound((mu + kl + ko) / 5);
  final total = base + mods.mr + sheet.bought.mr;
  return clampNonNegative(total);
}
