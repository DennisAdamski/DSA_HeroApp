import 'package:dsa_heldenverwaltung/catalog/talent_def.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';

import 'derived_stats.dart';
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
  });
  final ModifierParseResult parsed;
  final InventoryModifierAggregation inventory;
  final Attributes permanent;
  final Attributes effective;
  final WundEffekte wounds;

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
      );
}

/// Löst permanente, temporäre und Inventarboni sowie Wunden konsistent auf.
HeroStatInputs computeHeroStatInputs({
  required HeroSheet hero,
  required HeroState state,
  required List<TalentDef> talents,
  required bool epicAdvantagesActive,
}) {
  final parsed = parseModifierTextsForHero(hero);
  // Inventar-Modifikatoren aus ausgeruesteten Items aggregieren
  final inventoryMods = aggregateInventoryModifiers(
    hero.inventoryEntries,
    talents: talents,
  );

  final namedAttrMods = aggregateNamedAttributeModifiers(
    hero.attributeModifiers,
  );
  // Permanente Attribute ohne temporaere Boni (fuer LeP/Au/AsP-Maxima).
  // Attributo und aehnliche Zauber-Effekte sollen die Ressourcen-Obergrenzen
  // nicht veraendern.
  final permanent = applyAttributeModifiers(
    hero.attributes,
    parsed.attributeMods + namedAttrMods + inventoryMods.attributeMods,
  );
  // Effektive Attribute inkl. temporaerer Boni (fuer AT/PA/INI/GS/MR/FK).
  final effective = applyAttributeModifiers(
    hero.attributes,
    parsed.attributeMods +
        namedAttrMods +
        state.tempAttributeMods +
        inventoryMods.attributeMods,
  );
  // Wundberechnung -- die epische KO-Haupteigenschaft halbiert die
  // Proben-Erschwernis (Kap. 2.1).
  final wundEffekte = computeWundEffekte(
    state.wpiZustand,
    halbierteProbenErschwernis: isEpicMainAttributeBonusActive(
      ruleActive: epicAdvantagesActive,
      isEpisch: hero.isEpisch,
      mainAttributes: hero.epicMainAttributes,
      code: AttributeCode.ko,
    ),
  );
  return HeroStatInputs(
    parsed: parsed,
    inventory: inventoryMods,
    permanent: permanent,
    effective: effective,
    wounds: wundEffekte,
  );
}
