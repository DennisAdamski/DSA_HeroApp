import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/bought_stats.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_gruppen_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_se_pools.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_connection_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_language_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_meta_talent.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reisebericht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/magic_special_ability.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';

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
    this.schemaVersion = 24,
    required this.name,
    required this.level,
    required this.attributes,
    Attributes? rawStartAttributes,
    Attributes? startAttributes,
    this.persistentMods = const StatModifiers(),
    this.bought = const BoughtStats(),
    this.combatConfig = const CombatConfig(),
    this.talents = const <String, HeroTalentEntry>{},
    this.metaTalents = const <HeroMetaTalent>[],
    this.hiddenTalentIds = const <String>[],
    this.talentSpecialAbilities = const <TalentSpecialAbility>[],
    this.spells = const <String, HeroSpellEntry>{},
    this.ritualCategories = const <HeroRitualCategory>[],
    this.representationen = const <String>[],
    this.merkmalskenntnisse = const <String>[],
    this.magicSpecialAbilities = const <MagicSpecialAbility>[],
    this.magicLeadAttribute = '',
    this.sprachen = const <String, HeroLanguageEntry>{},
    this.schriften = const <String, HeroScriptEntry>{},
    this.muttersprache = '',
    this.appearance = const HeroAppearance(),
    this.background = const HeroBackground(),
    this.vorteileText = '',
    this.nachteileText = '',
    this.apTotal = 0,
    this.apSpent = 0,
    this.apAvailable = 0,
    this.dukaten = '',
    this.resourceActivationConfig = const HeroResourceActivationConfig(),
    this.inventoryEntries = const <HeroInventoryEntry>[],
    this.notes = const <HeroNoteEntry>[],
    this.connections = const <HeroConnectionEntry>[],
    this.adventures = const <HeroAdventureEntry>[],
    this.attributeSePool = const HeroAttributeSePool(),
    this.statSePool = const HeroStatSePool(),
    this.companions = const <HeroCompanion>[],
    this.gruppen = const <HeroGruppenMitgliedschaft>[],
    this.reisebericht = const HeroReisebericht(),
    this.statModifiers = const <String, List<HeroTalentModifier>>{},
    this.attributeModifiers = const <String, List<HeroTalentModifier>>{},
    this.unknownModifierFragments = const <String>[],
  }) : rawStartAttributes = rawStartAttributes ?? startAttributes ?? attributes,
       startAttributes = startAttributes ?? attributes;

  final String id;
  final int schemaVersion;
  final String name;
  final int level;
  final Attributes attributes;
  final Attributes rawStartAttributes;
  final Attributes startAttributes;
  final StatModifiers persistentMods;
  final BoughtStats bought;
  final CombatConfig combatConfig;
  final Map<String, HeroTalentEntry> talents;
  final List<HeroMetaTalent> metaTalents;
  final List<String> hiddenTalentIds;
  final List<TalentSpecialAbility> talentSpecialAbilities;
  final Map<String, HeroSpellEntry> spells;
  final List<HeroRitualCategory> ritualCategories;
  final List<String> representationen;
  final List<String> merkmalskenntnisse;
  final List<MagicSpecialAbility> magicSpecialAbilities;
  final String magicLeadAttribute;

  /// Sprachkenntnisse: sprachId → Eintrag.
  final Map<String, HeroLanguageEntry> sprachen;

  /// Schriftkenntnisse: schriftId → Eintrag.
  final Map<String, HeroScriptEntry> schriften;

  /// ID der Muttersprache (leer, wenn nicht gesetzt).
  final String muttersprache;

  final HeroAppearance appearance;
  final HeroBackground background;
  final String vorteileText;
  final String nachteileText;
  final int apTotal;
  final int apSpent;
  final int apAvailable;
  final String dukaten;
  final HeroResourceActivationConfig resourceActivationConfig;
  final List<HeroInventoryEntry> inventoryEntries;
  final List<HeroNoteEntry> notes;
  final List<HeroConnectionEntry> connections;
  final List<HeroAdventureEntry> adventures;
  final HeroAttributeSePool attributeSePool;
  final HeroStatSePool statSePool;

  /// Begleiter und Vertraute des Helden.
  final List<HeroCompanion> companions;

  /// Gruppenmitgliedschaften des Helden (Firebase-Sync).
  final List<HeroGruppenMitgliedschaft> gruppen;

  /// Reisebericht-Zustand (abgehakte Erfahrungen und Belohnungen).
  final HeroReisebericht reisebericht;

  /// Benannte, persistente Modifikatoren pro Basiswert (z.B. 'lep' → [...]).
  final Map<String, List<HeroTalentModifier>> statModifiers;

  /// Benannte, persistente Modifikatoren pro Eigenschaft (z.B. 'mu' → [...]).
  final Map<String, List<HeroTalentModifier>> attributeModifiers;

  final List<String> unknownModifierFragments;

  /// Immutable Update fuer gezielte Feldanpassungen.
  HeroSheet copyWith({
    String? id,
    String? name,
    int? level,
    Attributes? attributes,
    Attributes? rawStartAttributes,
    Attributes? startAttributes,
    StatModifiers? persistentMods,
    BoughtStats? bought,
    CombatConfig? combatConfig,
    Map<String, HeroTalentEntry>? talents,
    List<HeroMetaTalent>? metaTalents,
    List<String>? hiddenTalentIds,
    List<TalentSpecialAbility>? talentSpecialAbilities,
    Map<String, HeroSpellEntry>? spells,
    List<HeroRitualCategory>? ritualCategories,
    List<String>? representationen,
    List<String>? merkmalskenntnisse,
    List<MagicSpecialAbility>? magicSpecialAbilities,
    String? magicLeadAttribute,
    Map<String, HeroLanguageEntry>? sprachen,
    Map<String, HeroScriptEntry>? schriften,
    String? muttersprache,
    HeroAppearance? appearance,
    HeroBackground? background,
    String? vorteileText,
    String? nachteileText,
    int? apTotal,
    int? apSpent,
    int? apAvailable,
    String? dukaten,
    HeroResourceActivationConfig? resourceActivationConfig,
    List<HeroInventoryEntry>? inventoryEntries,
    List<HeroNoteEntry>? notes,
    List<HeroConnectionEntry>? connections,
    List<HeroAdventureEntry>? adventures,
    HeroAttributeSePool? attributeSePool,
    HeroStatSePool? statSePool,
    List<HeroCompanion>? companions,
    List<HeroGruppenMitgliedschaft>? gruppen,
    HeroReisebericht? reisebericht,
    Map<String, List<HeroTalentModifier>>? statModifiers,
    Map<String, List<HeroTalentModifier>>? attributeModifiers,
    List<String>? unknownModifierFragments,
  }) {
    return HeroSheet(
      id: id ?? this.id,
      schemaVersion: schemaVersion,
      name: name ?? this.name,
      level: level ?? this.level,
      attributes: attributes ?? this.attributes,
      rawStartAttributes: rawStartAttributes ?? this.rawStartAttributes,
      startAttributes: startAttributes ?? this.startAttributes,
      persistentMods: persistentMods ?? this.persistentMods,
      bought: bought ?? this.bought,
      combatConfig: combatConfig ?? this.combatConfig,
      talents: talents ?? this.talents,
      metaTalents: metaTalents ?? this.metaTalents,
      hiddenTalentIds: hiddenTalentIds == null
          ? this.hiddenTalentIds
          : _normalizeHiddenTalentIds(hiddenTalentIds),
      talentSpecialAbilities:
          talentSpecialAbilities ?? this.talentSpecialAbilities,
      spells: spells ?? this.spells,
      ritualCategories: ritualCategories ?? this.ritualCategories,
      representationen: representationen ?? this.representationen,
      merkmalskenntnisse: merkmalskenntnisse ?? this.merkmalskenntnisse,
      magicSpecialAbilities:
          magicSpecialAbilities ?? this.magicSpecialAbilities,
      magicLeadAttribute: magicLeadAttribute ?? this.magicLeadAttribute,
      sprachen: sprachen ?? this.sprachen,
      schriften: schriften ?? this.schriften,
      muttersprache: muttersprache ?? this.muttersprache,
      appearance: appearance ?? this.appearance,
      background: background ?? this.background,
      vorteileText: vorteileText ?? this.vorteileText,
      nachteileText: nachteileText ?? this.nachteileText,
      apTotal: apTotal ?? this.apTotal,
      apSpent: apSpent ?? this.apSpent,
      apAvailable: apAvailable ?? this.apAvailable,
      dukaten: dukaten ?? this.dukaten,
      resourceActivationConfig:
          resourceActivationConfig ?? this.resourceActivationConfig,
      inventoryEntries: inventoryEntries ?? this.inventoryEntries,
      notes: notes ?? this.notes,
      connections: connections ?? this.connections,
      adventures: adventures ?? this.adventures,
      attributeSePool: attributeSePool ?? this.attributeSePool,
      statSePool: statSePool ?? this.statSePool,
      companions: companions ?? this.companions,
      gruppen: gruppen ?? this.gruppen,
      reisebericht: reisebericht ?? this.reisebericht,
      statModifiers: statModifiers ?? this.statModifiers,
      attributeModifiers: attributeModifiers ?? this.attributeModifiers,
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
      'rawStartAttributes': rawStartAttributes.toJson(),
      'startAttributes': startAttributes.toJson(),
      'persistentMods': persistentMods.toJson(),
      'bought': bought.toJson(),
      'combatConfig': combatConfig.toJson(),
      'talents': talents.map((key, value) => MapEntry(key, value.toJson())),
      'metaTalents': metaTalents
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'hiddenTalentIds': _normalizeHiddenTalentIds(hiddenTalentIds),
      'talentSpecialAbilities': talentSpecialAbilities
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'spells': spells.map((key, value) => MapEntry(key, value.toJson())),
      'ritualCategories': ritualCategories
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'representationen': representationen,
      'merkmalskenntnisse': merkmalskenntnisse,
      'magicSpecialAbilities': magicSpecialAbilities
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'magicLeadAttribute': magicLeadAttribute,
      'sprachen': sprachen.map((key, value) => MapEntry(key, value.toJson())),
      'schriften': schriften.map((key, value) => MapEntry(key, value.toJson())),
      'muttersprache': muttersprache,
      ...appearance.toJson(),
      ...background.toJson(),
      'vorteileText': vorteileText,
      'nachteileText': nachteileText,
      'apTotal': apTotal,
      'apSpent': apSpent,
      'apAvailable': apAvailable,
      'dukaten': dukaten,
      'resourceActivationConfig': resourceActivationConfig.toJson(),
      'inventoryEntries': inventoryEntries
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'notes': notes.map((entry) => entry.toJson()).toList(growable: false),
      'connections': connections
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'adventures': adventures
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'attributeSePool': attributeSePool.toJson(),
      'statSePool': statSePool.toJson(),
      'companions': companions
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'gruppen': gruppen
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'reisebericht': reisebericht.toJson(),
      'statModifiers': statModifiers.map(
        (key, list) => MapEntry(
          key,
          list.map((entry) => entry.toJson()).toList(growable: false),
        ),
      ),
      'attributeModifiers': attributeModifiers.map(
        (key, list) => MapEntry(
          key,
          list.map((entry) => entry.toJson()).toList(growable: false),
        ),
      ),
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
    final rawNotes = (json['notes'] as List?) ?? const <dynamic>[];
    final rawConnections = (json['connections'] as List?) ?? const <dynamic>[];
    final rawAdventures = (json['adventures'] as List?) ?? const <dynamic>[];
    final rawCompanions = (json['companions'] as List?) ?? const <dynamic>[];
    final rawGruppen = (json['gruppen'] as List?) ?? const <dynamic>[];
    final rawMetaTalents = (json['metaTalents'] as List?) ?? const <dynamic>[];
    final rawHiddenTalentIds =
        (json['hiddenTalentIds'] as List?) ?? const <dynamic>[];
    final rawTalentSpecialAbilities = json['talentSpecialAbilities'];
    final rawSpells =
        (json['spells'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final rawRitualCategories =
        (json['ritualCategories'] as List?) ?? const <dynamic>[];
    final rawRepresentationen =
        (json['representationen'] as List?) ?? const <dynamic>[];
    final rawMerkmalskenntnisse =
        (json['merkmalskenntnisse'] as List?) ?? const <dynamic>[];
    final rawMagicSpecialAbilities =
        (json['magicSpecialAbilities'] as List?) ?? const <dynamic>[];
    final rawSprachen =
        (json['sprachen'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final rawSchriften =
        (json['schriften'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    String getString(String key) => (json[key] as String?) ?? '';

    final parsedAttributes = Attributes.fromJson(
      (json['attributes'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final parsedRawStartAttributes = Attributes.fromJson(
      (json['rawStartAttributes'] as Map?)?.cast<String, dynamic>() ??
          (json['startAttributes'] as Map?)?.cast<String, dynamic>() ??
          (json['attributes'] as Map?)?.cast<String, dynamic>() ??
          const {},
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
      rawStartAttributes: parsedRawStartAttributes,
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
      metaTalents: rawMetaTalents
          .whereType<Map>()
          .map(
            (entry) => HeroMetaTalent.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
      hiddenTalentIds: _normalizeHiddenTalentIds(rawHiddenTalentIds),
      talentSpecialAbilities: _parseTalentSpecialAbilities(
        rawTalentSpecialAbilities,
      ),
      spells: rawSpells.map((key, value) {
        final map = value is Map
            ? value.cast<String, dynamic>()
            : const <String, dynamic>{};
        return MapEntry(key, HeroSpellEntry.fromJson(map));
      }),
      ritualCategories: rawRitualCategories
          .whereType<Map>()
          .map(
            (entry) =>
                HeroRitualCategory.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
      representationen: rawRepresentationen
          .map((entry) => entry.toString())
          .toList(growable: false),
      merkmalskenntnisse: rawMerkmalskenntnisse
          .map((entry) => entry.toString())
          .toList(growable: false),
      magicSpecialAbilities: rawMagicSpecialAbilities
          .whereType<Map>()
          .map(
            (entry) =>
                MagicSpecialAbility.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
      magicLeadAttribute: getString('magicLeadAttribute').toUpperCase(),
      sprachen: rawSprachen.map((key, value) {
        final map = value is Map
            ? value.cast<String, dynamic>()
            : const <String, dynamic>{};
        return MapEntry(key, HeroLanguageEntry.fromJson(map));
      }),
      schriften: rawSchriften.map((key, value) {
        final map = value is Map
            ? value.cast<String, dynamic>()
            : const <String, dynamic>{};
        return MapEntry(key, HeroScriptEntry.fromJson(map));
      }),
      muttersprache: getString('muttersprache'),
      appearance: HeroAppearance.fromJson(json),
      background: HeroBackground.fromJson(json),
      vorteileText: getString('vorteileText'),
      nachteileText: getString('nachteileText'),
      apTotal: getInt('apTotal'),
      apSpent: getInt('apSpent'),
      apAvailable: getInt('apAvailable'),
      dukaten: getString('dukaten'),
      resourceActivationConfig: HeroResourceActivationConfig.fromJson(
        (json['resourceActivationConfig'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      inventoryEntries: rawInventoryEntries
          .whereType<Map>()
          .map(
            (entry) =>
                HeroInventoryEntry.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
      notes: rawNotes
          .whereType<Map>()
          .map((entry) => HeroNoteEntry.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false),
      connections: rawConnections
          .whereType<Map>()
          .map(
            (entry) =>
                HeroConnectionEntry.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
      adventures: rawAdventures
          .whereType<Map>()
          .map(
            (entry) =>
                HeroAdventureEntry.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
      attributeSePool: HeroAttributeSePool.fromJson(
        (json['attributeSePool'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      statSePool: HeroStatSePool.fromJson(
        (json['statSePool'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      companions: rawCompanions
          .whereType<Map>()
          .map((entry) => HeroCompanion.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false),
      gruppen: rawGruppen
          .whereType<Map>()
          .map(
            (entry) => HeroGruppenMitgliedschaft.fromJson(
              entry.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      reisebericht: HeroReisebericht.fromJson(
        (json['reisebericht'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      statModifiers: _parseNamedModifiersMap(
        json['statModifiers'],
        migrationFallback: StatModifiers.fromJson(
          (json['persistentMods'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      ),
      attributeModifiers: _parseNamedModifiersMap(json['attributeModifiers']),
      unknownModifierFragments: rawUnknown
          .map((entry) => entry.toString())
          .toList(growable: false),
    );
  }
}

List<TalentSpecialAbility> _parseTalentSpecialAbilities(dynamic raw) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map(
          (entry) =>
              TalentSpecialAbility.fromJson(entry.cast<String, dynamic>()),
        )
        .where((entry) => entry.name.trim().isNotEmpty)
        .toList(growable: false);
  }
  if (raw is String) {
    return parseLegacyTalentSpecialAbilities(raw);
  }
  return const <TalentSpecialAbility>[];
}

/// Parst eine verschachtelte Modifikator-Map aus JSON.
///
/// Bei fehlenden Daten und vorhandenem [migrationFallback] werden Nicht-Null-
/// Werte aus den alten persistentMods als benannte Eintraege migriert.
Map<String, List<HeroTalentModifier>> _parseNamedModifiersMap(
  dynamic raw, {
  StatModifiers? migrationFallback,
}) {
  if (raw is Map) {
    final result = <String, List<HeroTalentModifier>>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final list = entry.value;
      if (list is! List) {
        continue;
      }
      final modifiers = <HeroTalentModifier>[];
      for (final item in list) {
        if (item is! Map) {
          continue;
        }
        final parsed = HeroTalentModifier.fromJson(
          item.cast<String, dynamic>(),
        );
        if (parsed != null) {
          modifiers.add(parsed);
        }
      }
      if (modifiers.isNotEmpty) {
        result[key] = List<HeroTalentModifier>.unmodifiable(modifiers);
      }
    }
    if (result.isNotEmpty) {
      return Map<String, List<HeroTalentModifier>>.unmodifiable(result);
    }
  }

  // Migration: persistentMods-Werte als benannte Eintraege uebernehmen.
  if (migrationFallback != null) {
    return _migrateStatModifiers(migrationFallback);
  }
  return const <String, List<HeroTalentModifier>>{};
}

/// Konvertiert alte persistentMods in benannte Modifikatoreintraege.
Map<String, List<HeroTalentModifier>> _migrateStatModifiers(
  StatModifiers mods,
) {
  final result = <String, List<HeroTalentModifier>>{};
  void add(String key, int value) {
    if (value != 0) {
      result[key] = [
        HeroTalentModifier(modifier: value, description: 'Manuell'),
      ];
    }
  }

  add('lep', mods.lep);
  add('au', mods.au);
  add('asp', mods.asp);
  add('kap', mods.kap);
  add('mr', mods.mr);
  add('iniBase', mods.iniBase);
  add('at', mods.at);
  add('pa', mods.pa);
  add('fk', mods.fk);
  add('gs', mods.gs);
  add('ausweichen', mods.ausweichen);
  add('rs', mods.rs);

  if (result.isEmpty) {
    return const <String, List<HeroTalentModifier>>{};
  }
  return Map<String, List<HeroTalentModifier>>.unmodifiable(result);
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
