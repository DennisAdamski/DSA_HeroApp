import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';
import 'package:dsa_heldenverwaltung/catalog/combat_special_ability_def.dart';
import 'package:dsa_heldenverwaltung/catalog/maneuver_def.dart';
import 'package:dsa_heldenverwaltung/catalog/reisebericht_def.dart';
import 'package:dsa_heldenverwaltung/catalog/schrift_def.dart';
import 'package:dsa_heldenverwaltung/catalog/spell_def.dart';
import 'package:dsa_heldenverwaltung/catalog/sprache_def.dart';
import 'package:dsa_heldenverwaltung/catalog/talent_def.dart';
import 'package:dsa_heldenverwaltung/catalog/weapon_def.dart';

// Re-Exports fuer abwaertskompatible Imports.
export 'package:dsa_heldenverwaltung/catalog/catalog_constants.dart';
export 'package:dsa_heldenverwaltung/catalog/combat_special_ability_def.dart';
export 'package:dsa_heldenverwaltung/catalog/maneuver_def.dart';
export 'package:dsa_heldenverwaltung/catalog/schrift_def.dart';
export 'package:dsa_heldenverwaltung/catalog/spell_def.dart';
export 'package:dsa_heldenverwaltung/catalog/sprache_def.dart';
export 'package:dsa_heldenverwaltung/catalog/talent_def.dart';
export 'package:dsa_heldenverwaltung/catalog/reisebericht_def.dart';
export 'package:dsa_heldenverwaltung/catalog/weapon_def.dart';

/// Haelt alle zur Laufzeit geladenen DSA-Spielregeldaten.
///
/// Wird einmalig beim App-Start durch [CatalogLoader] aus den Split-JSON-
/// Assets befuellt und dann als unveraenderliches Objekt weitergegeben.
/// Der Katalog ist die zentrale Quelle fuer Talent-, Waffen-, Zauber- und
/// Manoeuverdefinitionen.
class RulesCatalog {
  const RulesCatalog({
    required this.version,
    required this.source,
    required this.talents,
    required this.spells,
    required this.weapons,
    this.maneuvers = const [],
    this.combatSpecialAbilities = const [],
    this.sprachen = const [],
    this.schriften = const [],
    this.reisebericht = const [],
    this.metadata = const {},
  });

  final String version; // Katalogversion (z. B. 'house_rules_v1')
  final String source; // Quell-ID (z. B. Dateiname des Manifests)
  final List<TalentDef> talents; // Alle Talente (regulaer + Kampftalente)
  final List<SpellDef> spells; // Alle Zaubersprueche
  final List<WeaponDef> weapons; // Alle Waffendefinitionen
  final List<ManeuverDef> maneuvers; // Kampfmanöver (optional, kann leer sein)
  final List<CombatSpecialAbilityDef>
  combatSpecialAbilities; // Kampf-Sonderfertigkeiten
  final List<SpracheDef> sprachen; // Sprachdefinitionen
  final List<SchriftDef> schriften; // Schriftdefinitionen
  final List<ReiseberichtDef> reisebericht; // Reisebericht-Eintraege
  final Map<String, dynamic> metadata; // Sonstige Metadaten aus dem Manifest

  /// Sucht ein Manöver anhand des Namens (Groß-/Kleinschreibung wird ignoriert).
  ManeuverDef? maneuverByName(String name) {
    final needle = name.trim().toLowerCase();
    for (final m in maneuvers) {
      if (m.name.trim().toLowerCase() == needle) return m;
    }
    return null;
  }

  factory RulesCatalog.fromJson(Map<String, dynamic> json) {
    final talentsRaw = (json['talents'] as List?) ?? const [];
    final spellsRaw = (json['spells'] as List?) ?? const [];
    final weaponsRaw = (json['weapons'] as List?) ?? const [];
    final maneuversRaw = (json['maneuvers'] as List?) ?? const [];
    final combatSpecialAbilitiesRaw =
        (json['combatSpecialAbilities'] as List?) ?? const [];
    final sprachenRaw = (json['sprachen'] as List?) ?? const [];
    final schriftenRaw = (json['schriften'] as List?) ?? const [];
    final reiseberichtRaw = (json['reisebericht'] as List?) ?? const [];

    return RulesCatalog(
      version: readCatalogString(json, 'version', fallback: 'unknown'),
      source: readCatalogString(json, 'source', fallback: 'unknown'),
      talents: talentsRaw
          .whereType<Map>()
          .map((entry) => TalentDef.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false),
      spells: spellsRaw
          .whereType<Map>()
          .map((entry) => SpellDef.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false),
      weapons: weaponsRaw
          .whereType<Map>()
          .map((entry) => WeaponDef.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false),
      maneuvers: maneuversRaw
          .whereType<Map>()
          .map((entry) => ManeuverDef.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false),
      combatSpecialAbilities: combatSpecialAbilitiesRaw
          .whereType<Map>()
          .map(
            (entry) =>
                CombatSpecialAbilityDef.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
      sprachen: sprachenRaw
          .whereType<Map>()
          .map((entry) => SpracheDef.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false),
      schriften: schriftenRaw
          .whereType<Map>()
          .map((entry) => SchriftDef.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false),
      reisebericht: reiseberichtRaw
          .whereType<Map>()
          .map(
            (entry) =>
                ReiseberichtDef.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
      metadata:
          (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'source': source,
      'metadata': metadata,
      'talents': talents.map((entry) => entry.toJson()).toList(growable: false),
      'spells': spells.map((entry) => entry.toJson()).toList(growable: false),
      'weapons': weapons.map((entry) => entry.toJson()).toList(growable: false),
      'maneuvers': maneuvers
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'combatSpecialAbilities': combatSpecialAbilities
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'sprachen': sprachen
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'schriften': schriften
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'reisebericht': reisebericht
          .map((entry) => entry.toJson())
          .toList(growable: false),
    };
  }
}
