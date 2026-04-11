import 'package:dsa_heldenverwaltung/catalog/combat_special_ability_def.dart';
import 'package:dsa_heldenverwaltung/catalog/maneuver_def.dart';
import 'package:dsa_heldenverwaltung/catalog/schrift_def.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/catalog/spell_def.dart';
import 'package:dsa_heldenverwaltung/catalog/sprache_def.dart';
import 'package:dsa_heldenverwaltung/catalog/talent_def.dart';
import 'package:dsa_heldenverwaltung/catalog/weapon_def.dart';

/// Alle in der Settings-Katalogverwaltung bearbeitbaren Katalogsektionen.
enum CatalogSectionId {
  talents,
  combatTalents,
  weapons,
  spells,
  maneuvers,
  combatSpecialAbilities,
  generalSpecialAbilities,
  magicSpecialAbilities,
  karmalSpecialAbilities,
  sprachen,
  schriften,
}

/// Reihenfolge der im Settings-Bereich sichtbaren Katalogsektionen.
const List<CatalogSectionId> editableCatalogSections = <CatalogSectionId>[
  CatalogSectionId.talents,
  CatalogSectionId.combatTalents,
  CatalogSectionId.weapons,
  CatalogSectionId.spells,
  CatalogSectionId.maneuvers,
  CatalogSectionId.combatSpecialAbilities,
  CatalogSectionId.generalSpecialAbilities,
  CatalogSectionId.magicSpecialAbilities,
  CatalogSectionId.karmalSpecialAbilities,
  CatalogSectionId.sprachen,
  CatalogSectionId.schriften,
];

/// Schluessel der manifestbasierten Reisebericht-Datei.
const String reiseberichtManifestKey = 'reisebericht';

/// Liefert Hilfsdaten und Default-Verhalten fuer Katalogsektionen.
extension CatalogSectionIdX on CatalogSectionId {
  /// Manifest-Key innerhalb der Split-Katalogstruktur.
  String get manifestFileKey => switch (this) {
    CatalogSectionId.talents => 'talente',
    CatalogSectionId.combatTalents => 'waffentalente',
    CatalogSectionId.weapons => 'waffen',
    CatalogSectionId.spells => 'magie',
    CatalogSectionId.maneuvers => 'manoever',
    CatalogSectionId.combatSpecialAbilities => 'kampf_sonderfertigkeiten',
    CatalogSectionId.generalSpecialAbilities =>
      'allgemeine_sonderfertigkeiten',
    CatalogSectionId.magicSpecialAbilities => 'magische_sonderfertigkeiten',
    CatalogSectionId.karmalSpecialAbilities => 'karmale_sonderfertigkeiten',
    CatalogSectionId.sprachen => 'sprachen',
    CatalogSectionId.schriften => 'schriften',
  };

  /// Verzeichnisname im Heldenspeicher fuer benutzerdefinierte Eintraege.
  String get directoryName => manifestFileKey;

  /// Anzeigename der Sektion in der UI.
  String get displayName => switch (this) {
    CatalogSectionId.talents => 'Talente',
    CatalogSectionId.combatTalents => 'Waffentalente',
    CatalogSectionId.weapons => 'Waffen',
    CatalogSectionId.spells => 'Zauber',
    CatalogSectionId.maneuvers => 'Manöver',
    CatalogSectionId.combatSpecialAbilities => 'Kampf-Sonderfertigkeiten',
    CatalogSectionId.generalSpecialAbilities => 'Allgemeine Sonderfertigkeiten',
    CatalogSectionId.magicSpecialAbilities => 'Magische Sonderfertigkeiten',
    CatalogSectionId.karmalSpecialAbilities => 'Karmale Sonderfertigkeiten',
    CatalogSectionId.sprachen => 'Sprachen',
    CatalogSectionId.schriften => 'Schriften',
  };

  /// Singular-Label fuer `+ <Singular>`-Buttons.
  String get singularLabel => switch (this) {
    CatalogSectionId.talents => 'Talent',
    CatalogSectionId.combatTalents => 'Waffentalent',
    CatalogSectionId.weapons => 'Waffe',
    CatalogSectionId.spells => 'Zauber',
    CatalogSectionId.maneuvers => 'Manöver',
    CatalogSectionId.combatSpecialAbilities => 'Kampf-Sonderfertigkeit',
    CatalogSectionId.generalSpecialAbilities => 'Allgemeine Sonderfertigkeit',
    CatalogSectionId.magicSpecialAbilities => 'Magische Sonderfertigkeit',
    CatalogSectionId.karmalSpecialAbilities => 'Karmale Sonderfertigkeit',
    CatalogSectionId.sprachen => 'Sprache',
    CatalogSectionId.schriften => 'Schrift',
  };

  /// Ob die Sektion in v1 bewusst ueber einen JSON-Editor gepflegt wird.
  bool get usesJsonEditor =>
      this == CatalogSectionId.combatSpecialAbilities ||
      this == CatalogSectionId.generalSpecialAbilities ||
      this == CatalogSectionId.magicSpecialAbilities ||
      this == CatalogSectionId.karmalSpecialAbilities;
}

/// Loest einen Verzeichnisnamen zu einer Katalogsektion auf.
CatalogSectionId? catalogSectionFromDirectoryName(String value) {
  final normalized = value.trim();
  for (final section in editableCatalogSections) {
    if (section.directoryName == normalized) {
      return section;
    }
  }
  return null;
}

/// Erzeugt einen leeren Standardentwurf fuer eine neue Katalogdefinition.
Map<String, dynamic> defaultCatalogEntryTemplate(CatalogSectionId section) {
  return switch (section) {
    CatalogSectionId.talents => const <String, dynamic>{
      'id': '',
      'name': '',
      'group': '',
      'steigerung': 'B',
      'attributes': <String>[],
      'type': '',
      'be': '',
      'weaponCategory': '',
      'alternatives': '',
      'source': '',
      'description': '',
      'active': true,
    },
    CatalogSectionId.combatTalents => const <String, dynamic>{
      'id': '',
      'name': '',
      'group': 'Kampftalent',
      'steigerung': 'D',
      'attributes': <String>[],
      'type': '',
      'be': '',
      'weaponCategory': '',
      'alternatives': '',
      'source': '',
      'description': '',
      'active': true,
    },
    CatalogSectionId.weapons => const <String, dynamic>{
      'id': '',
      'name': '',
      'type': 'Nahkampf',
      'combatSkill': '',
      'tp': '',
      'complexity': '',
      'weaponCategory': '',
      'possibleManeuvers': <String>[],
      'activeManeuvers': <String>[],
      'tpkk': '',
      'iniMod': 0,
      'atMod': 0,
      'paMod': 0,
      'weight': '',
      'length': '',
      'breakFactor': '',
      'price': '',
      'remarks': '',
      'reloadTime': 0,
      'reloadTimeText': '',
      'rangedDistanceBands': <Map<String, dynamic>>[],
      'rangedProjectiles': <Map<String, dynamic>>[],
      'reach': '',
      'source': '',
      'active': true,
    },
    CatalogSectionId.spells => const <String, dynamic>{
      'id': '',
      'name': '',
      'tradition': '',
      'steigerung': 'C',
      'attributes': <String>[],
      'availability': '',
      'traits': '',
      'modifier': '',
      'castingTime': '',
      'aspCost': '',
      'targetObject': '',
      'range': '',
      'duration': '',
      'modifications': '',
      'wirkung': '',
      'variants': <String>[],
      'category': '',
      'source': '',
      'active': true,
    },
    CatalogSectionId.maneuvers => const <String, dynamic>{
      'id': '',
      'name': '',
      'gruppe': '',
      'typ': '',
      'erschwernis': '',
      'seite': '',
      'erklarung': '',
      'erklarung_lang': '',
      'voraussetzungen': '',
      'verbreitung': '',
      'kosten': '',
    },
    CatalogSectionId.combatSpecialAbilities => const <String, dynamic>{
      'id': '',
      'name': '',
      'gruppe': 'kampf',
      'typ': 'sonderfertigkeit',
      'stil_typ': '',
      'seite': '',
      'beschreibung': '',
      'erklarung_lang': '',
      'voraussetzungen': '',
      'verbreitung': '',
      'kosten': '',
      'aktiviert_manoever_ids': <String>[],
      'kampfwert_boni': <Map<String, dynamic>>[],
    },
    CatalogSectionId.generalSpecialAbilities => const <String, dynamic>{
      'id': '',
      'name': '',
      'gruppe': 'allgemein',
      'typ': 'sonderfertigkeit',
      'kategorie': '',
      'seite': '',
      'beschreibung': '',
      'erklarung_lang': '',
      'voraussetzungen': '',
      'verbreitung': '',
      'kosten': '',
    },
    CatalogSectionId.magicSpecialAbilities => const <String, dynamic>{
      'id': '',
      'name': '',
      'gruppe': 'magisch',
      'typ': 'sonderfertigkeit',
      'kategorie': '',
      'seite': '',
      'beschreibung': '',
      'erklarung_lang': '',
      'voraussetzungen': '',
      'verbreitung': '',
      'kosten': '',
    },
    CatalogSectionId.karmalSpecialAbilities => const <String, dynamic>{
      'id': '',
      'name': '',
      'gruppe': 'karmal',
      'typ': 'sonderfertigkeit',
      'kategorie': '',
      'seite': '',
      'beschreibung': '',
      'erklarung_lang': '',
      'voraussetzungen': '',
      'verbreitung': '',
      'kosten': '',
    },
    CatalogSectionId.sprachen => const <String, dynamic>{
      'id': '',
      'name': '',
      'familie': '',
      'maxWert': 18,
      'steigerung': 'A',
      'schriftIds': <String>[],
      'schriftlos': false,
      'hinweise': '',
    },
    CatalogSectionId.schriften => const <String, dynamic>{
      'id': '',
      'name': '',
      'maxWert': 10,
      'beschreibung': '',
      'steigerung': 'A',
      'hinweise': '',
    },
  };
}

/// Bringt einen Katalogeintrag in das serialisierte Zielschema der App.
Map<String, dynamic> canonicalizeCatalogEntry(
  CatalogSectionId section,
  Map<String, dynamic> raw,
) {
  return switch (section) {
    CatalogSectionId.talents ||
    CatalogSectionId.combatTalents => TalentDef.fromJson(raw).toJson(),
    CatalogSectionId.weapons => WeaponDef.fromJson(raw).toJson(),
    CatalogSectionId.spells => SpellDef.fromJson(raw).toJson(),
    CatalogSectionId.maneuvers => ManeuverDef.fromJson(raw).toJson(),
    CatalogSectionId.combatSpecialAbilities => CombatSpecialAbilityDef.fromJson(
      raw,
    ).toJson(),
    CatalogSectionId.generalSpecialAbilities ||
    CatalogSectionId.magicSpecialAbilities ||
    CatalogSectionId.karmalSpecialAbilities =>
      SpecialAbilityDef.fromJson(raw).toJson(),
    CatalogSectionId.sprachen => SpracheDef.fromJson(raw).toJson(),
    CatalogSectionId.schriften => SchriftDef.fromJson(raw).toJson(),
  };
}

/// Prueft sektionsspezifische Invarianten fuer einen Katalogeintrag.
void validateCatalogEntryStructure(
  CatalogSectionId section,
  Map<String, dynamic> raw,
) {
  final entry = canonicalizeCatalogEntry(section, raw);
  final id = (entry['id'] as String? ?? '').trim();
  if (id.isEmpty) {
    throw const FormatException('Katalogeintrag benötigt eine nicht-leere ID.');
  }

  if (section == CatalogSectionId.combatTalents) {
    final group = (entry['group'] as String? ?? '').trim();
    if (group != 'Kampftalent') {
      throw const FormatException(
        'Waffentalente müssen die Gruppe "Kampftalent" verwenden.',
      );
    }
  }

  if (section == CatalogSectionId.talents) {
    final group = (entry['group'] as String? ?? '').trim();
    if (group == 'Kampftalent') {
      throw const FormatException(
        'Normale Talente dürfen nicht die Gruppe "Kampftalent" verwenden.',
      );
    }
  }
}

/// Liest den stabilen Eintragsnamen fuer Listen und Detailansichten aus.
String catalogEntryDisplayName(Map<String, dynamic> entry) {
  final name = (entry['name'] as String? ?? '').trim();
  if (name.isNotEmpty) {
    return name;
  }
  final id = (entry['id'] as String? ?? '').trim();
  return id.isEmpty ? 'Ohne Namen' : id;
}
