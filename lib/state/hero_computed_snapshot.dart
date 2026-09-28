import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/attribute_start_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_wirkung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_stat_inputs.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';

/// Zentraler Compute-Snapshot fuer alle abgeleiteten Heldenwerte.
class HeroComputedSnapshot {
  const HeroComputedSnapshot({
    required this.hero,
    required this.state,
    required this.modifierParse,
    required this.resourceActivation,
    required this.effectiveStartAttributes,
    required this.attributeMaximums,
    required this.effectiveAttributes,
    required this.derivedStats,
    required this.combatPreviewStats,
    required this.wundEffekte,
    required this.wundschwelle,
    required this.wundschwellenStufen,
    this.inventoryStatMods = const StatModifiers(),
    this.inventoryAttributeMods = const AttributeModifiers(),
    this.inventoryTalentMods = const <String, int>{},
  });

  final HeroSheet hero;
  final HeroState state;
  final ModifierParseResult modifierParse;
  final HeroResourceActivation resourceActivation;
  final Attributes effectiveStartAttributes;
  final Attributes attributeMaximums;
  final Attributes effectiveAttributes;
  final DerivedStats derivedStats;
  final CombatPreviewStats combatPreviewStats;

  /// Aggregierte Wundeffekte (Mali auf AT, PA, FK, INI, GS, Proben).
  final WundEffekte wundEffekte;

  /// Effektive Wundschwelle (KO/2 + Modifikatoren).
  final int wundschwelle;

  /// Vier KO-basierte Wundschwellen fuer die Anzeige im Wundendialog.
  final WundschwellenStufen wundschwellenStufen;

  /// Aggregierte Stat-Modifikatoren aus ausgeruesteten Inventar-Items.
  final StatModifiers inventoryStatMods;

  /// Aggregierte Eigenschafts-Modifikatoren aus ausgeruesteten Inventar-Items.
  final AttributeModifiers inventoryAttributeMods;

  /// Aggregierte Talentboni aus ausgeruesteten Inventar-Items (talentId → Bonus).
  final Map<String, int> inventoryTalentMods;
}

/// Setzt den [HeroComputedSnapshot] aus Sheet, State und Katalog zusammen.
///
/// Reine Funktion ohne Provider-Zugriff: `heroComputedProvider` ruft sie mit
/// den beobachteten Werten auf, Regel- und Bestandsheldentests rechnen damit
/// dieselben Werte ohne `ProviderContainer`. Ohne geladenen [catalog] fehlen
/// nur die katalogabhaengigen Anteile (Talente, Manoever, Kampf-SF), genau wie
/// im Provider waehrend des Katalogladens.
HeroComputedSnapshot buildHeroComputedSnapshot({
  required HeroSheet hero,
  required HeroState state,
  required RulesCatalog? catalog,
  required bool epicAdvantagesActive,
}) {
  final catalogTalents = catalog?.talents ?? const <TalentDef>[];
  final catalogManeuvers = catalog?.maneuvers ?? const <ManeuverDef>[];
  final catalogCombatSpecialAbilities =
      catalog?.combatSpecialAbilities ?? const <CombatSpecialAbilityDef>[];

  final inputs = computeHeroStatInputs(
    hero: hero,
    state: state,
    talents: catalogTalents,
    epicAdvantagesActive: epicAdvantagesActive,
    catalog: catalog,
  );
  final parsed = inputs.parsed;
  final merkmale = werteMerkmaleAus(hero, catalog: catalog);
  final inventoryMods = inputs.inventory;
  final effective = inputs.effective;
  final wundEffekte = inputs.wounds;
  final resourceActivation = computeHeroResourceActivation(
    hero,
    catalog: catalog,
  );
  final effectiveStartAttributes = computeHeroEffectiveStartAttributes(
    hero,
    catalog: catalog,
  );
  final attributeMaximums = computeHeroAttributeMaximums(
    hero,
    catalog: catalog,
  );
  final wundschwelleMods = hero.statModifiers['wundschwelle'] ?? const [];
  final wundschwelle = computeWundschwelle(
    ko: effective.ko,
    mods: wundschwelleMods,
  );
  final wundschwellenStufen = computeWundschwellenStufen(
    ko: effective.ko,
    mods: wundschwelleMods,
    vorteileText: merkmale.freieVorteile,
    nachteileText: merkmale.freieNachteile,
    merkmalBonus: merkmale.wirkungen.wundschwelleBonus,
  );

  final derived = inputs.derive(hero, state);
  final combat = computeCombatPreviewStats(
    hero,
    state,
    catalogTalents: catalogTalents,
    catalogManeuvers: catalogManeuvers,
    catalogCombatSpecialAbilities: catalogCombatSpecialAbilities,
    parsedModifiers: parsed,
    effectiveAttributes: effective,
    derivedStats: derived,
    epicAdvantagesRuleActive: epicAdvantagesActive,
  );

  return HeroComputedSnapshot(
    hero: hero,
    state: state,
    modifierParse: parsed,
    resourceActivation: resourceActivation,
    effectiveStartAttributes: effectiveStartAttributes,
    attributeMaximums: attributeMaximums,
    effectiveAttributes: effective,
    derivedStats: derived,
    combatPreviewStats: combat,
    wundEffekte: wundEffekte,
    wundschwelle: wundschwelle,
    wundschwellenStufen: wundschwellenStufen,
    inventoryStatMods: inventoryMods.statMods,
    inventoryAttributeMods: inventoryMods.attributeMods,
    inventoryTalentMods: inventoryMods.talentMods,
  );
}
