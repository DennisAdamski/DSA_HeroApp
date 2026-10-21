import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_instance_rules.dart';

import 'basiswert_herleitung_rules.dart';
import 'derived_stats.dart';
import 'eigenschaft_herleitung_rules.dart';
import 'epic_main_attribute_rules.dart';
import 'inventory_modifier_rules.dart';
import 'modifier_parser.dart';
import 'modifier_source_breakdown.dart';
import 'wund_rules.dart';

/// Gemeinsame Recheneingaben für Übersicht und ungespeicherte Steigerungsvorschau.
class HeroStatInputs {
  /// Hält dieselben Modifikatoren für Ressourcen, Kampfwerte und Detailansichten.
  const HeroStatInputs({
    required this.parsed,
    required this.inventory,
    required this.permanent,
    required this.effective,
    required this.wounds,
    this.textAufteilung,
    this.eigenschaftHerleitungen,
    this.zauberEffekte = const SpellEffectBeitraege(),
  });
  final ModifierParseResult parsed;
  final InventoryModifierAggregation inventory;
  final Attributes permanent;
  final Attributes effective;
  final WundEffekte wounds;

  /// Textmodifikatoren nach Rasse, Kultur, Profession und Vor-/Nachteilen,
  /// nur für die Herleitung der Basiswerte (ARCH-04).
  final List<StatModifikatorQuelle>? textAufteilung;

  /// Herleitung der effektiven Eigenschaften ([effective]) (ARCH-04).
  final EigenschaftHerleitungen? eigenschaftHerleitungen;

  /// Empfangene Kampf-Mali laufender Zaubereffekte (MAG-EFF-03).
  final SpellEffectBeitraege zauberEffekte;

  /// Eigenschaftswerte für Proben: [effective] mit den Zauber-
  /// Eigenschaftsquellen (Karnifilo, `wendeZauberEigenschaftenAn`) und
  /// abzüglich der wundbedingten Eigenschaftsverluste. Abgeleitete Werte
  /// rechnen nie damit (WdS S. 111).
  Attributes get probenEigenschaften => wendeWundVerlusteAn(
    wendeZauberEigenschaftenAn(effective, zauberEffekte),
    wounds,
  );

  /// Wendet die zentralen Basiswertregeln auf die vorbereiteten Eingaben an.
  DerivedStats derive(HeroSheet hero, HeroState state) =>
      computeDerivedStatsFromInputs(
        sheet: hero,
        state: state,
        parsedModifiers: parsed,
        effectiveAttributes: effective,
        permanentAttributes: permanent,
        inventoryStatMods: inventory.statMods,
        wundStatMods: wundEffekteToStatModifiers(wounds),
        textAufteilung: textAufteilung,
        zauberEffekte: zauberEffekte,
      );
}

/// Löst permanente, temporäre und Inventarboni sowie Wunden konsistent auf.
HeroStatInputs computeHeroStatInputs({
  required HeroSheet hero,
  required HeroState state,
  required List<TalentDef> talents,
  required bool epicAdvantagesActive,
  required RulesCatalog? catalog,
}) {
  final parsed = parseModifierTextsForHero(hero, catalog: catalog);
  // Inventar-Modifikatoren aus ausgeruesteten Items aggregieren
  final inventoryMods = aggregateInventoryModifiers(
    hero.inventoryEntries,
    talents: talents,
  );

  final breakdown = computeModifierSourceBreakdown(hero, catalog: catalog);
  // Eigenschaften als Herleitung (ARCH-04), einmal ohne temporäre Boni:
  // Attributo und ähnliche Zaubereffekte verändern die Ressourcen-Obergrenzen
  // (LeP/Au/AsP) nicht, wohl aber AT/PA/INI/GS/MR/FK.
  EigenschaftHerleitungen eigenschaften({required bool mitTemporaer}) =>
      computeEigenschaftHerleitungen(
        gespeichert: hero.attributes,
        quellen: sammleEigenschaftQuellen(
          textMods: parsed.attributeMods,
          eigene: hero.attributeModifiers,
          textAufteilung: herkunftsEigenschaftQuellen(breakdown),
          inventar: inventoryMods.attributeMods,
          temporaer: mitTemporaer ? effektiveTempAttributeMods(state) : null,
        ),
      );
  final permanent = eigenschaften(mitTemporaer: false)
      .werteAuf(hero.attributes);
  final effektiveHerleitungen = eigenschaften(mitTemporaer: true);
  final effective = effektiveHerleitungen.werteAuf(hero.attributes);
  final zauberEffekte = berechneSpellEffectBeitraegeFuerHeld(
    held: hero,
    zustand: state,
    katalog: catalog,
  );
  final gezaehlteWunden = computeHeroWundEffekte(
    hero: hero,
    zustand: state.wpiZustand,
    epicAdvantagesActive: epicAdvantagesActive,
    parsed: parsed,
  );
  // Im Kampfrausch (Karnifilo) mindern Wunden AT und PA nicht.
  final kampfrausch = zauberEffekte.kampfrauschQuelle;
  final wundEffekte = kampfrausch == null
      ? gezaehlteWunden
      : wundEffekteImKampfrausch(gezaehlteWunden, quelle: kampfrausch);
  return HeroStatInputs(
    parsed: parsed,
    inventory: inventoryMods,
    permanent: permanent,
    effective: effective,
    wounds: wundEffekte,
    textAufteilung: herkunftsQuellen(breakdown),
    eigenschaftHerleitungen: effektiveHerleitungen,
    zauberEffekte: zauberEffekte,
  );
}

/// Berechnet die Wundeffekte eines Helden für [zustand].
///
/// Liest die beiden heldenbezogenen Schalter an einer Stelle: Linkshänder
/// (Katalogschalter `linkshaender`, ARCH-02) macht den linken Arm zum
/// Schwertarm, die epische KO-Haupteigenschaft halbiert das Unterdrücken von
/// Wunden („Epische Stufen“ S. 4). Snapshot und Unterdrückungsdialog nutzen
/// dieselbe Funktion, damit sie nie auseinanderlaufen.
WundEffekte computeHeroWundEffekte({
  required HeroSheet hero,
  required WundZustand zustand,
  required bool epicAdvantagesActive,
  required ModifierParseResult parsed,
}) {
  return computeWundEffekte(
    zustand,
    linkshaender: parsed.hasLinkshaenderFromVorteile,
    halbierteUnterdrueckung: isEpicMainAttributeBonusActive(
      ruleActive: epicAdvantagesActive,
      isEpisch: hero.isEpisch,
      mainAttributes: hero.epicMainAttributes,
      code: AttributeCode.ko,
    ),
  );
}
