import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';

import 'package:dsa_heldenverwaltung/rules/derived/basiswert_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_source_breakdown.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_instance_rules.dart';

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
    this.modifiers = const StatModifiers(),
    this.herleitungen,
    this.zauberEffekte = const SpellEffectBeitraege(),
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

  /// Summe aller Stat-Modifikatoren, mit der diese Werte gerechnet wurden:
  /// Inspector (`persistentMods`), benannte Modifikatoren, Textmodifikatoren,
  /// temporaere, Inventar- und Wundmodifikatoren.
  ///
  /// Die Kampfvorschau rechnet damit weiter, damit AT, PA, RS und INI
  /// dieselben Quellen beruecksichtigen wie die Basiswerte.
  final StatModifiers modifiers;

  /// Herleitung jedes Werts (ARCH-04); `null` nur bei von Hand gebauten
  /// Werten, etwa in Tests.
  final BasiswertHerleitungen? herleitungen;

  /// Empfangene Kampf-Mali laufender Zaubereffekte (MAG-EFF-03). Ihre
  /// Basiswert-Anteile stecken bereits in [modifiers] und [herleitungen]; der
  /// Abzug auf die fertige Helden-INI (Blitz) und die Hinweise werden von der
  /// Kampfvorschau gelesen.
  final SpellEffectBeitraege zauberEffekte;
}

/// Berechnet alle abgeleiteten Werte aus Stammdaten und Laufzeitzustand.
///
/// Datenfluss:
/// 1. Textmodifikatoren parsen (`modifier_parser.dart`)
/// 2. Attributmodifikatoren auf Basisattribute anwenden
/// 3. Stat-Modifikatoren aus persistent + geparst + temporaer zusammenfuehren
/// 4. Einzelformeln aus Ressourcen-/Kampfbasis-/Ini-Regeln auswerten
///
/// Mit [catalog] wirken Vor- und Nachteile über ihre Katalog-ID (ARCH-02).
DerivedStats computeDerivedStats(
  HeroSheet sheet,
  HeroState state, {
  RulesCatalog? catalog,
}) {
  final parsed = parseModifierTextsForHero(sheet, catalog: catalog);
  final namedAttrMods = aggregateNamedAttributeModifiers(
    sheet.attributeModifiers,
  );
  // Permanente Attribute ohne temporaere Boni (fuer LeP/Au/AsP-Maxima).
  final permanentAttributes = applyAttributeModifiers(
    sheet.attributes,
    parsed.attributeMods + namedAttrMods,
  );
  // Effektive Attribute inkl. temporaerer Boni (fuer AT/PA/INI/GS/MR/FK).
  final effectiveAttributes = applyAttributeModifiers(
    sheet.attributes,
    parsed.attributeMods + namedAttrMods + effektiveTempAttributeMods(state),
  );
  return computeDerivedStatsFromInputs(
    sheet: sheet,
    state: state,
    parsedModifiers: parsed,
    effectiveAttributes: effectiveAttributes,
    permanentAttributes: permanentAttributes,
    zauberEffekte: berechneSpellEffectBeitraegeFuerHeld(
      held: sheet,
      zustand: state,
      katalog: catalog,
    ),
  );
}

/// Berechnet die Basiswerte aus vorbereiteten Eingaben.
///
/// Die Werte stammen aus den [BasiswertHerleitungen] (ARCH-04); sie liegen
/// in [DerivedStats.herleitungen], damit jede Anzeige genau die gerechnete
/// Herleitung zeigt. [textAufteilung] zerlegt den Textanteil nach Herkunft
/// und Merkmalen, ohne den Wert zu verändern.
DerivedStats computeDerivedStatsFromInputs({
  required HeroSheet sheet,
  required HeroState state,
  required ModifierParseResult parsedModifiers,
  required Attributes effectiveAttributes,
  // Attribute ohne temporaere Boni (Attributo etc.) fuer Ressourcen-Maxima
  // (LeP/Au/AsP). Faellt auf effectiveAttributes zurueck wenn nicht angegeben.
  Attributes? permanentAttributes,
  StatModifiers inventoryStatMods = const StatModifiers(),
  StatModifiers wundStatMods = const StatModifiers(),
  List<StatModifikatorQuelle>? textAufteilung,
  SpellEffectBeitraege zauberEffekte = const SpellEffectBeitraege(),
}) {
  final quellen = sammleStatModifikatorQuellen(
    sheet: sheet,
    state: state,
    textMods: parsedModifiers.statMods,
    textAufteilung: textAufteilung,
    inventar: inventoryStatMods,
    wunden: wundStatMods,
    zauber: zauberEffekte.statQuellen,
  );
  final h = computeBasiswertHerleitungen(
    sheet: sheet,
    state: state,
    // Ressourcen-Maxima ignorieren temporaere Zauberboni (Attributo).
    permanentAttributes: permanentAttributes ?? effectiveAttributes,
    effectiveAttributes: effectiveAttributes,
    quellen: quellen,
    hasFlinkFromVorteile: parsedModifiers.hasFlinkFromVorteile,
    hasBehaebigFromNachteile: parsedModifiers.hasBehaebigFromNachteile,
    wundGs: wundStatMods.gs,
  );

  return DerivedStats(
    maxLep: h.maxLep.wert,
    maxAu: h.maxAu.wert,
    maxAsp: h.maxAsp.wert,
    maxKap: h.maxKap.wert,
    mr: h.mr.wert,
    iniBase: h.iniBase.wert,
    atBase: h.atBase.wert,
    paBase: h.paBase.wert,
    fkBase: h.fkBase.wert,
    gs: h.gs.wert,
    ausweichen: h.ausweichen.wert,
    modifiers: summeDerQuellen(quellen),
    herleitungen: h,
    zauberEffekte: zauberEffekte,
  );
}
