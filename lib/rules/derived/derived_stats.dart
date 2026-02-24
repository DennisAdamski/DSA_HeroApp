import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';

import 'package:dsa_heldenverwaltung/rules/derived/attributes_rules.dart';
import 'modifier_parser.dart';

/// Ergebniscontainer fuer alle zentral berechneten Heldenwerte.
class DerivedStats {
  const DerivedStats({
    required this.maxLep,
    required this.maxAu,
    required this.maxAsp,
    required this.maxKap,
    required this.mr,
    required this.iniBase,
    required this.gs,
    required this.ausweichen,
  });

  final int maxLep;
  final int maxAu;
  final int maxAsp;
  final int maxKap;
  final int mr;
  final int iniBase;
  final int gs;
  final int ausweichen;
}

/// Berechnet alle abgeleiteten Werte aus Stammdaten und Laufzeitzustand.
///
/// Datenfluss:
/// 1. Textmodifikatoren parsen (`modifier_parser.dart`)
/// 2. Attributmodifikatoren auf Basisattribute anwenden
/// 3. Stat-Modifikatoren aus persistent + geparst + temporaer zusammenfuehren
/// 4. Einzelformeln aus `attributes_rules.dart` auswerten
DerivedStats computeDerivedStats(HeroSheet sheet, HeroState state) {
  final parsed = parseModifierTextsForHero(sheet);
  final effectiveSheet = sheet.copyWith(
    attributes: applyAttributeModifiers(sheet.attributes, parsed.attributeMods),
  );
  final mods = sheet.persistentMods + parsed.statMods + state.tempMods;

  return DerivedStats(
    maxLep: computeMaxLep(effectiveSheet, mods),
    maxAu: computeMaxAu(effectiveSheet, mods),
    maxAsp: computeMaxAsp(effectiveSheet, mods),
    maxKap: computeMaxKap(effectiveSheet, mods),
    mr: computeMr(effectiveSheet, mods),
    iniBase: computeIniBase(effectiveSheet, mods),
    gs: computeGs(effectiveSheet, mods),
    ausweichen: computeAusweichen(effectiveSheet, mods),
  );
}
