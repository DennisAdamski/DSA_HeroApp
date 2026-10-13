import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ap_level_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/excel_rounding.dart';

int _cappedLevel(int level) => level > 21 ? 21 : (level < 0 ? 0 : level);

/// LeP-Grundwert aus Eigenschaften: round((KO+KO+KK)/2).
int grundwertLep(Attributes a) => excelRound((a.ko + a.ko + a.kk) / 2);

/// LeP aus der Stufe: Level, höchstens 21.
int stufenanteilLep(int level) => _cappedLevel(level);

/// Au-Grundwert aus Eigenschaften: round((MU+KO+GE)/2).
int grundwertAu(Attributes a) => excelRound((a.mu + a.ko + a.ge) / 2);

/// Stufe, deren Au-Anteil zählt.
///
/// Epische Charaktere erhalten keinen weiteren stufenweisen Au-Bonus über
/// ihren Aktivierungs-Level hinaus.
int stufeFuerAu(HeroSheet sheet) => sheet.isEpisch
    ? math.min(computeLevelFromSpentAp(sheet.epicStartAp), sheet.level)
    : sheet.level;

/// AsP-Grundwert aus Eigenschaften: round((MU+IN+CH)/2).
int grundwertAsp(Attributes a) => excelRound((a.mu + a.inn + a.ch) / 2);

/// MR-Grundwert aus Eigenschaften: round((MU+KL+KO)/5).
int grundwertMr(Attributes a) => excelRound((a.mu + a.kl + a.ko) / 5);

// Maximale Lebensenergie: round((KO+KO+KK)/2) + min(level,21) + gekauft + Mod.
int computeMaxLep(HeroSheet sheet, StatModifiers mods) {
  final base = grundwertLep(sheet.attributes);
  final total =
      base + mods.lep + sheet.bought.lep + stufenanteilLep(sheet.level);
  return clampNonNegative(total);
}

// Maximale Ausdauer: round((MU+KO+GE)/2) + level*2 + gekauft + Mod.
int computeMaxAu(HeroSheet sheet, StatModifiers mods) {
  final base = grundwertAu(sheet.attributes);
  final total = base + mods.au + sheet.bought.au + stufeFuerAu(sheet) * 2;
  return clampNonNegative(total);
}

// Maximale Astralenergie: round((MU+IN+CH)/2) + level*2 + gekauft + Mod.
int computeMaxAsp(HeroSheet sheet, StatModifiers mods) {
  final base = grundwertAsp(sheet.attributes);
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
  final base = grundwertMr(sheet.attributes);
  final total = base + mods.mr + sheet.bought.mr;
  return clampNonNegative(total);
}
