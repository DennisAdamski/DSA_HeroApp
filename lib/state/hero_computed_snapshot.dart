import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';

/// Zentraler Compute-Snapshot fuer alle abgeleiteten Heldenwerte.
class HeroComputedSnapshot {
  const HeroComputedSnapshot({
    required this.hero,
    required this.state,
    required this.modifierParse,
    required this.effectiveStartAttributes,
    required this.attributeMaximums,
    required this.effectiveAttributes,
    required this.derivedStats,
    required this.combatPreviewStats,
  });

  final HeroSheet hero;
  final HeroState state;
  final ModifierParseResult modifierParse;
  final Attributes effectiveStartAttributes;
  final Attributes attributeMaximums;
  final Attributes effectiveAttributes;
  final DerivedStats derivedStats;
  final CombatPreviewStats combatPreviewStats;
}
