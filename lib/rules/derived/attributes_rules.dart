import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/excel_rounding.dart';
// This file contains the logic for computing derived attributes like LEP, AU, ASP, etc. based on the hero's base attributes and modifiers.

// The formulas are based on the DSA 4.1 rules, with some adjustments for hero level and bought attributes.
int _clampNonNegative(int value) => value < 0 ? 0 : value;
int _cappedLevel(int level) => level > 21 ? 21 : (level < 0 ? 0 : level);

// Computes the maximum LEP (Lebensenergie) for a hero based on their attributes, modifiers, bought attributes, and level.
int computeMaxLep(HeroSheet sheet, StatModifiers mods) {
  final base = _baseLep(sheet);
  final total = base + mods.lep + sheet.bought.lep + _cappedLevel(sheet.level);
  return _clampNonNegative(total);
}

int _baseLep(HeroSheet sheet) {
  final ko = sheet.attributes.ko;
  final kk = sheet.attributes.kk;
  return excelCeil((ko + ko + kk) / 2);
}

// Computes the maximum AU (Ausdauer) for a hero based on their attributes, modifiers, bought attributes, and level.
int computeMaxAu(HeroSheet sheet, StatModifiers mods) {
  final base = _baseAu(sheet);
  final total = base + mods.au + sheet.bought.au + sheet.level * 2;
  return _clampNonNegative(total);
}

int _baseAu(HeroSheet sheet) {
  final mu = sheet.attributes.mu;
  final ko = sheet.attributes.ko;
  final ge = sheet.attributes.ge;
  return excelCeil((mu + ko + ge) / 2);
}

// Computes the maximum ASP (Astralenergie) for a hero based on their attributes, modifiers, bought attributes, and level.
int computeMaxAsp(HeroSheet sheet, StatModifiers mods) {
  final base = _baseAsp(sheet);
  final total = base + mods.asp + sheet.bought.asp + sheet.level * 2;
  return _clampNonNegative(total);
}

int _baseAsp(HeroSheet sheet) {
  final mu = sheet.attributes.mu;
  final inn = sheet.attributes.inn;
  final ch = sheet.attributes.ch;
  return excelCeil((mu + inn + ch) / 2);
}

// Computes the maximum KAP (Karma-Punkte) for a hero based on their attributes, modifiers, bought attributes, and level.
int computeMaxKap(HeroSheet sheet, StatModifiers mods) {
  final total = mods.kap + sheet.bought.kap;
  return _clampNonNegative(total);
}

int computeMr(HeroSheet sheet, StatModifiers mods) {
  final base = _baseMr(sheet);
  final total = base + mods.mr + sheet.bought.mr;
  return _clampNonNegative(total);
}

// The base MR (Magieresistenz) is calculated from the hero's MU, KL, and KO attributes.
int _baseMr(HeroSheet sheet) {
  final mu = sheet.attributes.mu;
  final kl = sheet.attributes.kl;
  final ko = sheet.attributes.ko;
  return excelRound((mu + kl + ko) / 5);
}

// Computes the initiative base for a hero based on their attributes and modifiers.
int computeIniBase(HeroSheet sheet, StatModifiers mods) {
  return _baseIni(sheet) + mods.iniBase;
}

int _baseIni(HeroSheet sheet) {
  final mu = sheet.attributes.mu;
  final inn = sheet.attributes.inn;
  final ge = sheet.attributes.ge;
  return excelCeil((mu + mu + inn + ge) / 5);
}

// Computes the Geschwindigkeits modifier for a hero based on their attributes and modifiers.
int computeGs(HeroSheet sheet, StatModifiers mods) {
  return _baseGs(sheet) + mods.gs;
}

int _baseGs(HeroSheet sheet) {
  final ge = sheet.attributes.ge;
  int gs = 8;
  if (ge > 15) {
    gs += 1;
  } else if (ge < 11) {
    gs -= 1;
  }
  return gs;
}

// Computes the AT (Attacke) for a hero based on their attributes and modifiers.
int computeAt(HeroSheet sheet, StatModifiers mods) {
  return _baseAt(sheet) + mods.at;
}

int _baseAt(HeroSheet sheet) {
  final mu = sheet.attributes.mu;
  final ge = sheet.attributes.ge;
  final kk = sheet.attributes.kk;
  return excelCeil((mu + ge + kk) / 5);
}

// Computes the PA (Parade) for a hero based on their attributes and modifiers.
int computePa(HeroSheet sheet, StatModifiers mods) {
  return _basePa(sheet) + mods.pa;
}

int _basePa(HeroSheet sheet) {
  final inn = sheet.attributes.inn;
  final ge = sheet.attributes.ge;
  final kk = sheet.attributes.kk;
  return excelCeil((inn + ge + kk) / 5);
}

// Computes the FK (Fernkampf) for a hero based on their attributes and modifiers.
int computeFk(HeroSheet sheet, StatModifiers mods) {
  return _baseFk(sheet) + mods.fk;
}

int _baseFk(HeroSheet sheet) {
  final inn = sheet.attributes.inn;
  final ff = sheet.attributes.ff;
  final kk = sheet.attributes.kk;
  return excelCeil((inn + ff + kk) / 5);
}

// Computes the Ausweichen for a hero based on their attributes and modifiers.
int computeAusweichen(HeroSheet sheet, StatModifiers mods) {
  return _baseAusweichen(sheet) + mods.ausweichen;
}

int _baseAusweichen(HeroSheet sheet) {
  return 0;
}


