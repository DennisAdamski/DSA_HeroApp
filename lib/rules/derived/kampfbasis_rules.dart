import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/excel_rounding.dart';

/// AT-Grundwert aus Eigenschaften: round((MU+GE+KK)/5).
int grundwertAt(Attributes a) => excelRound((a.mu + a.ge + a.kk) / 5);

/// PA-Grundwert aus Eigenschaften: round((IN+GE+KK)/5).
int grundwertPa(Attributes a) => excelRound((a.inn + a.ge + a.kk) / 5);

/// FK-Grundwert aus Eigenschaften: round((IN+FF+KK)/5).
int grundwertFk(Attributes a) => excelRound((a.inn + a.ff + a.kk) / 5);

/// GS-Anteil der Gewandtheit: +1 über GE 15, −1 unter GE 11.
int geAnteilGs(int ge) => ge > 15 ? 1 : (ge < 11 ? -1 : 0);

/// Grundgeschwindigkeit vor Gewandtheit, Modifikatoren und Behinderung.
const int kGrundgeschwindigkeit = 8;

// Attacke-Basiswert: round((MU+GE+KK)/5) + Mod.
int computeAt(HeroSheet sheet, StatModifiers mods) {
  return grundwertAt(sheet.attributes) + mods.at;
}

// Parade-Basiswert: round((IN+GE+KK)/5) + Mod.
int computePa(HeroSheet sheet, StatModifiers mods) {
  return grundwertPa(sheet.attributes) + mods.pa;
}

// Fernkampf-Basiswert: round((IN+FF+KK)/5) + Mod.
int computeFk(HeroSheet sheet, StatModifiers mods) {
  return grundwertFk(sheet.attributes) + mods.fk;
}

/// Berechnet die aktuelle Geschwindigkeit inklusive Behinderungsabzug.
///
/// Grundlage ist GS 8, modifiziert durch GE-Schwellen, direkte GS-Modifikatoren
/// und die aktuelle Kampf-BE nach Rüstungsgewöhnung.
int computeGs(HeroSheet sheet, StatModifiers mods, {int beKampf = 0}) {
  final gs = kGrundgeschwindigkeit + geAnteilGs(sheet.attributes.ge);
  return gs + mods.gs - beKampf;
}
