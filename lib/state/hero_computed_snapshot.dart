import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';

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

  /// Aggregierte Stat-Modifikatoren aus ausgeruesteten Inventar-Items.
  final StatModifiers inventoryStatMods;

  /// Aggregierte Eigenschafts-Modifikatoren aus ausgeruesteten Inventar-Items.
  final AttributeModifiers inventoryAttributeMods;

  /// Aggregierte Talentboni aus ausgeruesteten Inventar-Items (talentId → Bonus).
  final Map<String, int> inventoryTalentMods;
}
