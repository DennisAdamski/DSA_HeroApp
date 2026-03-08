import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';

import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ini_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampfbasis_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_rules.dart';
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
    required this.atBase,
    required this.paBase,
    required this.fkBase,
    required this.gs,
    required this.ausweichen,
  });

  final int maxLep;
  final int maxAu;
  final int maxAsp;
  final int maxKap;
  final int mr;
  final int iniBase;
  final int atBase;
  final int paBase;
  final int fkBase;
  final int gs;
  final int ausweichen;
}

/// Berechnet alle abgeleiteten Werte aus Stammdaten und Laufzeitzustand.
///
/// Datenfluss:
/// 1. Textmodifikatoren parsen (`modifier_parser.dart`)
/// 2. Attributmodifikatoren auf Basisattribute anwenden
/// 3. Stat-Modifikatoren aus persistent + geparst + temporaer zusammenfuehren
/// 4. Einzelformeln aus Ressourcen-/Kampfbasis-/Ini-Regeln auswerten
DerivedStats computeDerivedStats(HeroSheet sheet, HeroState state) {
  final parsed = parseModifierTextsForHero(sheet);
  final effectiveAttributes = applyAttributeModifiers(
    sheet.attributes,
    parsed.attributeMods + state.tempAttributeMods,
  );
  return computeDerivedStatsFromInputs(
    sheet: sheet,
    state: state,
    parsedModifiers: parsed,
    effectiveAttributes: effectiveAttributes,
  );
}

DerivedStats computeDerivedStatsFromInputs({
  required HeroSheet sheet,
  required HeroState state,
  required ModifierParseResult parsedModifiers,
  required Attributes effectiveAttributes,
}) {
  final effectiveSheet = sheet.copyWith(attributes: effectiveAttributes);
  final mods = sheet.persistentMods + parsedModifiers.statMods + state.tempMods;
  final baseGs = computeGs(effectiveSheet, mods);
  final axxeleratusActive = isAxxeleratusEffectActive(
    sheet: sheet,
    state: state,
  );
  final gs = computeAxxeleratusGs(
    gs: baseGs,
    axxeleratusActive: axxeleratusActive,
  );

  return DerivedStats(
    maxLep: computeMaxLep(effectiveSheet, mods),
    maxAu: computeMaxAu(effectiveSheet, mods),
    maxAsp: computeMaxAsp(effectiveSheet, mods),
    maxKap: computeMaxKap(effectiveSheet, mods),
    mr: computeMr(effectiveSheet, mods),
    iniBase: computeIniBase(effectiveSheet, mods),
    atBase: computeAt(effectiveSheet, mods),
    paBase: computePa(effectiveSheet, mods),
    fkBase: computeFk(effectiveSheet, mods),
    gs: gs,
    // Ausweichen wird nicht mehr als Basiswertformel aus Attributen berechnet.
    // Der abgeleitete Wert spiegelt hier nur explizite Modifikatoren wider.
    ausweichen: mods.ausweichen,
  );
}
