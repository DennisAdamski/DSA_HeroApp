import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/bought_stats.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';

/// Persistiertes Kernmodell eines Helden (ohne Laufzeitzustand).
///
/// Wichtige Invarianten:
/// - `id` ist der stabile Schluessel fuer Repository und Transfer.
/// - `schemaVersion` beschreibt nur das Heldenobjektformat.
/// - Laufzeitwerte wie aktuelle LeP/AsP liegen bewusst in `HeroState`.
/// - `unknownModifierFragments` speichert Parser-Restfragmente fuer UI-Hinweise.
class HeroSheet {
  const HeroSheet({
    required this.id,
    this.schemaVersion = 4,
    required this.name,
    required this.level,
    required this.attributes,
    Attributes? startAttributes,
    this.persistentMods = const StatModifiers(),
    this.bought = const BoughtStats(),
    this.combatConfig = const CombatConfig(),
    this.talents = const <String, HeroTalentEntry>{},
    this.hiddenTalentIds = const <String>[],
    this.rasse = '',
    this.rasseModText = '',
    this.kultur = '',
    this.kulturModText = '',
    this.profession = '',
    this.professionModText = '',
    this.geschlecht = '',
    this.alter = '',
    this.groesse = '',
    this.gewicht = '',
    this.haarfarbe = '',
    this.augenfarbe = '',
    this.aussehen = '',
    this.stand = '',
    this.titel = '',
    this.familieHerkunftHintergrund = '',
    this.sozialstatus = 0,
    this.vorteileText = '',
    this.nachteileText = '',
    this.apTotal = 0,
    this.apSpent = 0,
    this.apAvailable = 0,
    this.dukaten = '',
    this.inventoryEntries = const <HeroInventoryEntry>[],
    this.unknownModifierFragments = const <String>[],
  }) : startAttributes = startAttributes ?? attributes;

  final String id;
  final int schemaVersion;
  final String name;
  final int level;
  final Attributes attributes;
  final Attributes startAttributes;
  final StatModifiers persistentMods;
  final BoughtStats bought;
  final CombatConfig combatConfig;
  final Map<String, HeroTalentEntry> talents;
  final List<String> hiddenTalentIds;

  final String rasse;
  final String rasseModText;
  final String kultur;
  final String kulturModText;
  final String profession;
  final String professionModText;
  final String geschlecht;
  final String alter;
  final String groesse;
  final String gewicht;
  final String haarfarbe;
  final String augenfarbe;
  final String aussehen;
  final String stand;
  final String titel;
  final String familieHerkunftHintergrund;
  final int sozialstatus;
  final String vorteileText;
  final String nachteileText;
  final int apTotal;
  final int apSpent;
  final int apAvailable;
  final String dukaten;
  final List<HeroInventoryEntry> inventoryEntries;
  final List<String> unknownModifierFragments;

  /// Immutable Update fuer gezielte Feldanpassungen.
  HeroSheet copyWith({
    String? id,
    String? name,
    int? level,
    Attributes? attributes,
    Attributes? startAttributes,
    StatModifiers? persistentMods,
    BoughtStats? bought,
    CombatConfig? combatConfig,
    Map<String, HeroTalentEntry>? talents,
    List<String>? hiddenTalentIds,
    String? rasse,
    String? rasseModText,
    String? kultur,
    String? kulturModText,
    String? profession,
    String? professionModText,
    String? geschlecht,
    String? alter,
    String? groesse,
    String? gewicht,
    String? haarfarbe,
    String? augenfarbe,
    String? aussehen,
    String? stand,
    String? titel,
    String? familieHerkunftHintergrund,
    int? sozialstatus,
    String? vorteileText,
    String? nachteileText,
    int? apTotal,
    int? apSpent,
    int? apAvailable,
    String? dukaten,
    List<HeroInventoryEntry>? inventoryEntries,
    List<String>? unknownModifierFragments,
  }) {
    return HeroSheet(
      id: id ?? this.id,
      schemaVersion: schemaVersion,
      name: name ?? this.name,
      level: level ?? this.level,
      attributes: attributes ?? this.attributes,
      startAttributes: startAttributes ?? this.startAttributes,
      persistentMods: persistentMods ?? this.persistentMods,
      bought: bought ?? this.bought,
      combatConfig: combatConfig ?? this.combatConfig,
      talents: talents ?? this.talents,
      hiddenTalentIds: hiddenTalentIds == null
          ? this.hiddenTalentIds
          : _normalizeHiddenTalentIds(hiddenTalentIds),
      rasse: rasse ?? this.rasse,
      rasseModText: rasseModText ?? this.rasseModText,
      kultur: kultur ?? this.kultur,
      kulturModText: kulturModText ?? this.kulturModText,
      profession: profession ?? this.profession,
      professionModText: professionModText ?? this.professionModText,
      geschlecht: geschlecht ?? this.geschlecht,
      alter: alter ?? this.alter,
      groesse: groesse ?? this.groesse,
      gewicht: gewicht ?? this.gewicht,
      haarfarbe: haarfarbe ?? this.haarfarbe,
      augenfarbe: augenfarbe ?? this.augenfarbe,
      aussehen: aussehen ?? this.aussehen,
      stand: stand ?? this.stand,
      titel: titel ?? this.titel,
      familieHerkunftHintergrund:
          familieHerkunftHintergrund ?? this.familieHerkunftHintergrund,
      sozialstatus: sozialstatus ?? this.sozialstatus,
      vorteileText: vorteileText ?? this.vorteileText,
      nachteileText: nachteileText ?? this.nachteileText,
      apTotal: apTotal ?? this.apTotal,
      apSpent: apSpent ?? this.apSpent,
      apAvailable: apAvailable ?? this.apAvailable,
      dukaten: dukaten ?? this.dukaten,
      inventoryEntries: inventoryEntries ?? this.inventoryEntries,
      unknownModifierFragments:
          unknownModifierFragments ?? this.unknownModifierFragments,
    );
  }

  /// Serialisierung fuer lokale Persistenz und Export.
  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'id': id,
      'name': name,
      'level': level,
      'attributes': attributes.toJson(),
      'startAttributes': startAttributes.toJson(),
      'persistentMods': persistentMods.toJson(),
      'bought': bought.toJson(),
      'combatConfig': combatConfig.toJson(),
      'talents': talents.map((key, value) => MapEntry(key, value.toJson())),
      'hiddenTalentIds': _normalizeHiddenTalentIds(hiddenTalentIds),
      'rasse': rasse,
      'rasseModText': rasseModText,
      'kultur': kultur,
      'kulturModText': kulturModText,
      'profession': profession,
      'professionModText': professionModText,
      'geschlecht': geschlecht,
      'alter': alter,
      'groesse': groesse,
      'gewicht': gewicht,
      'haarfarbe': haarfarbe,
      'augenfarbe': augenfarbe,
      'aussehen': aussehen,
      'stand': stand,
      'titel': titel,
      'familieHerkunftHintergrund': familieHerkunftHintergrund,
      'sozialstatus': sozialstatus,
      'vorteileText': vorteileText,
      'nachteileText': nachteileText,
      'apTotal': apTotal,
      'apSpent': apSpent,
      'apAvailable': apAvailable,
      'dukaten': dukaten,
      'inventoryEntries': inventoryEntries
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'unknownModifierFragments': unknownModifierFragments,
    };
  }

  /// Rueckwaertskompatibles Laden alter Datenstaende.
  static HeroSheet fromJson(Map<String, dynamic> json) {
    final rawTalents =
        (json['talents'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final rawUnknown =
        (json['unknownModifierFragments'] as List?) ?? const <dynamic>[];
    final rawInventoryEntries =
        (json['inventoryEntries'] as List?) ?? const <dynamic>[];
    final rawHiddenTalentIds =
        (json['hiddenTalentIds'] as List?) ?? const <dynamic>[];
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    String getString(String key) => (json[key] as String?) ?? '';

    final parsedAttributes = Attributes.fromJson(
      (json['attributes'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final parsedStartAttributes = Attributes.fromJson(
      (json['startAttributes'] as Map?)?.cast<String, dynamic>() ??
          (json['attributes'] as Map?)?.cast<String, dynamic>() ??
          const {},
    );

    return HeroSheet(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unbenannter Held',
      level: getInt('level') == 0 ? 1 : getInt('level'),
      attributes: parsedAttributes,
      startAttributes: parsedStartAttributes,
      persistentMods: StatModifiers.fromJson(
        (json['persistentMods'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      bought: BoughtStats.fromJson(
        (json['bought'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      combatConfig: CombatConfig.fromJson(
        (json['combatConfig'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      talents: rawTalents.map((key, value) {
        final map = value is Map
            ? value.cast<String, dynamic>()
            : const <String, dynamic>{};
        return MapEntry(key, HeroTalentEntry.fromJson(map));
      }),
      hiddenTalentIds: _normalizeHiddenTalentIds(rawHiddenTalentIds),
      rasse: getString('rasse'),
      rasseModText: getString('rasseModText'),
      kultur: getString('kultur'),
      kulturModText: getString('kulturModText'),
      profession: getString('profession'),
      professionModText: getString('professionModText'),
      geschlecht: getString('geschlecht'),
      alter: getString('alter'),
      groesse: getString('groesse'),
      gewicht: getString('gewicht'),
      haarfarbe: getString('haarfarbe'),
      augenfarbe: getString('augenfarbe'),
      aussehen: getString('aussehen'),
      stand: getString('stand'),
      titel: getString('titel'),
      familieHerkunftHintergrund: getString('familieHerkunftHintergrund'),
      sozialstatus: getInt('sozialstatus'),
      vorteileText: getString('vorteileText'),
      nachteileText: getString('nachteileText'),
      apTotal: getInt('apTotal'),
      apSpent: getInt('apSpent'),
      apAvailable: getInt('apAvailable'),
      dukaten: getString('dukaten'),
      inventoryEntries: rawInventoryEntries
          .whereType<Map>()
          .map(
            (entry) =>
                HeroInventoryEntry.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
      unknownModifierFragments: rawUnknown
          .map((entry) => entry.toString())
          .toList(growable: false),
    );
  }
}

List<String> _normalizeHiddenTalentIds(Iterable<dynamic> values) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final value in values) {
    final id = value.toString().trim();
    if (id.isEmpty || seen.contains(id)) {
      continue;
    }
    seen.add(id);
    normalized.add(id);
  }
  return normalized;
}
