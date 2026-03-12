import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/excel_rounding.dart';

// Attacke-Basiswert: round((MU+GE+KK)/5) + Mod.
int computeAt(HeroSheet sheet, StatModifiers mods) {
  final mu = sheet.attributes.mu;
  final ge = sheet.attributes.ge;
  final kk = sheet.attributes.kk;
  return excelRound((mu + ge + kk) / 5) + mods.at;
}

// Parade-Basiswert: round((IN+GE+KK)/5) + Mod.
int computePa(HeroSheet sheet, StatModifiers mods) {
  final inn = sheet.attributes.inn;
  final ge = sheet.attributes.ge;
  final kk = sheet.attributes.kk;
  return excelRound((inn + ge + kk) / 5) + mods.pa;
}

// Fernkampf-Basiswert: round((IN+FF+KK)/5) + Mod.
int computeFk(HeroSheet sheet, StatModifiers mods) {
  final inn = sheet.attributes.inn;
  final ff = sheet.attributes.ff;
  final kk = sheet.attributes.kk;
  return excelRound((inn + ff + kk) / 5) + mods.fk;
}

/// Berechnet die aktuelle Geschwindigkeit inklusive Behinderungsabzug.
///
/// Grundlage ist GS 8, modifiziert durch GE-Schwellen, direkte GS-Modifikatoren
/// und die aktuelle Kampf-BE nach Rüstungsgewöhnung.
int computeGs(HeroSheet sheet, StatModifiers mods, {int beKampf = 0}) {
  final ge = sheet.attributes.ge;
  int gs = 8;
  if (ge > 15) {
    gs += 1;
  } else if (ge < 11) {
    gs -= 1;
  }
  return gs + mods.gs - beKampf;
}
