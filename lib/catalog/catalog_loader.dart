import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_provenance.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';

/// Laedt und validiert das Split-JSON-Katalogformat aus Flutter-Assets.
///
/// Der Katalog besteht aus einer `manifest.json` (Einstiegspunkt) die Pfade zu
/// den Teilkatalog-Dateien enthaelt (Talente, Kampftalente, Waffen, Magie,
/// optional Manoever und Kampf-Sonderfertigkeiten). Alle Dateipfade werden relativ zur Manifest-Datei
/// aufgeloest.
class CatalogLoader {
  const CatalogLoader({
    this.defaultAssetPath = 'assets/catalogs/house_rules_v1/manifest.json',
  });

  /// Asset-Pfad zur Standard-Manifest-Datei.
  final String defaultAssetPath;

  /// Laedt den Standard-Katalog aus [defaultAssetPath].
  Future<RulesCatalog> loadDefaultCatalog() {
    return loadFromAsset(defaultAssetPath);
  }

  /// Laedt die Rohdaten des Standard-Katalogs aus [defaultAssetPath].
  Future<CatalogSourceData> loadDefaultSourceData() {
    return loadSourceData(defaultAssetPath);
  }

  /// Laedt alle eingebauten Hausregel-Pakete fuer eine Katalogversion.
  Future<HouseRulePackSourceSnapshot> loadBuiltInHouseRulePacks({
    required String catalogVersion,
  }) async {
    // Eventschleife einmal yielden, damit das App-Shell auf dem Web vor der
    // Asset-Arbeit der Pack-Manifeste den ersten Frame malen kann.
    // Funktioniert auch in Tests ohne Frame-Pump (im Gegensatz zu endOfFrame).
    await Future<void>.delayed(Duration.zero);
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();
    final prefix = 'assets/catalogs/$catalogVersion/packs/';
    final manifestPaths =
        assets
            .where(
              (assetPath) =>
                  assetPath.startsWith(prefix) &&
                  assetPath.endsWith('/manifest.json'),
            )
            .toList(growable: false)
          ..sort();

    final packs = <HouseRulePackManifest>[];
    final issues = <HouseRulePackIssue>[];
    final seenIds = <String>{};
    final loadedManifests = await Future.wait(
      manifestPaths.map(_loadBuiltInHouseRulePackManifest),
    );

    for (final result in loadedManifests) {
      final loadIssue = result.issue;
      if (loadIssue != null) {
        issues.add(loadIssue);
        continue;
      }
      final pack = result.manifest!;
      if (!seenIds.add(pack.id)) {
        issues.add(
          HouseRulePackIssue(
            packId: pack.id,
            packTitle: pack.title,
            filePath: result.assetPath,
            message:
                'Doppelte eingebaute Paket-ID; das spaetere Manifest wird ignoriert.',
          ),
        );
        continue;
      }
      packs.add(pack);
    }

    return HouseRulePackSourceSnapshot(
      packs: List<HouseRulePackManifest>.unmodifiable(packs),
      issues: List<HouseRulePackIssue>.unmodifiable(issues),
    );
  }

  /// Laedt einen Katalog aus der angegebenen Manifest-Datei.
  ///
  /// Liest alle Teilkatalog-Dateien, validiert die Kampftalent-Aufteilung
  /// und prueft auf doppelte IDs. Wirft [FormatException] bei Fehlern.
  Future<RulesCatalog> loadFromAsset(String manifestAssetPath) async {
    final sourceData = await loadSourceData(manifestAssetPath);
    return buildCatalogFromSourceData(
      sourceData,
      assetPathForErrors: manifestAssetPath,
    );
  }

  /// Laedt die Split-JSON-Struktur als rohe Sektionsdaten.
  Future<CatalogSourceData> loadSourceData(String manifestAssetPath) async {
    final manifest = await _loadJsonObject(manifestAssetPath);
    final files = _readJsonObject(
      manifest,
      'files',
      assetPath: manifestAssetPath,
      context: 'manifest',
    );
    final metadata =
        (manifest['metadata'] as Map?)?.cast<String, dynamic>() ?? const {};
    final sectionResultsFuture = Future.wait([
      for (final section in _requiredCatalogSections)
        _loadRequiredSection(
          files: files,
          manifestAssetPath: manifestAssetPath,
          section: section,
        ).then((entries) => _CatalogSectionLoad(section, entries)),
      for (final section in _optionalCatalogSections)
        _loadOptionalSection(
          files: files,
          manifestAssetPath: manifestAssetPath,
          section: section,
        ).then((entries) => _CatalogSectionLoad(section, entries)),
    ]);
    final reiseberichtFuture = _loadOptionalSectionByKey(
      files: files,
      manifestAssetPath: manifestAssetPath,
      manifestKey: reiseberichtManifestKey,
    );
    final sectionResults = await sectionResultsFuture;
    final sections = <CatalogSectionId, List<Map<String, dynamic>>>{
      for (final result in sectionResults) result.section: result.entries,
    };
    final reisebericht = await reiseberichtFuture;

    return CatalogSourceData(
      version: _readOptionalString(manifest, 'version', fallback: 'unknown'),
      source: _readOptionalString(manifest, 'source', fallback: 'unknown'),
      metadata: metadata,
      sections: sections,
      reisebericht: reisebericht,
    );
  }

  /// Baut einen typisierten Laufzeitkatalog aus rohen Sektionsdaten.
  RulesCatalog buildCatalogFromSourceData(
    CatalogSourceData sourceData, {
    String assetPathForErrors = 'catalog',
    CatalogRuleResolver ruleResolver = const CatalogRuleResolver(),
  }) {
    final talents = sourceData.entriesFor(CatalogSectionId.talents);
    final combatTalents = sourceData.entriesFor(CatalogSectionId.combatTalents);
    final weapons = sourceData.entriesFor(CatalogSectionId.weapons);
    final spells = sourceData.entriesFor(CatalogSectionId.spells);
    final maneuvers = sourceData.entriesFor(CatalogSectionId.maneuvers);
    final combatSpecialAbilities = sourceData.entriesFor(
      CatalogSectionId.combatSpecialAbilities,
    );
    final generalSpecialAbilities = sourceData.entriesFor(
      CatalogSectionId.generalSpecialAbilities,
    );
    final magicSpecialAbilities = sourceData.entriesFor(
      CatalogSectionId.magicSpecialAbilities,
    );
    final karmalSpecialAbilities = sourceData.entriesFor(
      CatalogSectionId.karmalSpecialAbilities,
    );
    final sprachen = sourceData.entriesFor(CatalogSectionId.sprachen);
    final schriften = sourceData.entriesFor(CatalogSectionId.schriften);

    _validateCombatSplit(
      entries: talents,
      mustBeCombatTalent: false,
      assetPath: assetPathForErrors,
    );
    _validateCombatSplit(
      entries: combatTalents,
      mustBeCombatTalent: true,
      assetPath: assetPathForErrors,
    );

    final combinedTalents = <Map<String, dynamic>>[
      ...talents,
      ...combatTalents,
    ];
    _validateUniqueIds(
      entries: combinedTalents,
      domainName: 'talents',
      assetPath: assetPathForErrors,
    );
    _validateUniqueIds(
      entries: spells,
      domainName: 'spells',
      assetPath: assetPathForErrors,
    );
    _validateUniqueIds(
      entries: weapons,
      domainName: 'weapons',
      assetPath: assetPathForErrors,
    );
    _validateUniqueIds(
      entries: maneuvers,
      domainName: 'maneuvers',
      assetPath: assetPathForErrors,
    );
    _validateUniqueIds(
      entries: combatSpecialAbilities,
      domainName: 'combat special abilities',
      assetPath: assetPathForErrors,
    );
    _validateUniqueIds(
      entries: generalSpecialAbilities,
      domainName: 'general special abilities',
      assetPath: assetPathForErrors,
    );
    _validateUniqueIds(
      entries: magicSpecialAbilities,
      domainName: 'magic special abilities',
      assetPath: assetPathForErrors,
    );
    _validateUniqueIds(
      entries: karmalSpecialAbilities,
      domainName: 'karmal special abilities',
      assetPath: assetPathForErrors,
    );
    _validateUniqueIds(
      entries: sprachen,
      domainName: 'sprachen',
      assetPath: assetPathForErrors,
    );
    _validateUniqueIds(
      entries: schriften,
      domainName: 'schriften',
      assetPath: assetPathForErrors,
    );
    _validateUniqueIds(
      entries: sourceData.reisebericht,
      domainName: 'reisebericht',
      assetPath: assetPathForErrors,
    );

    return RulesCatalog(
      version: sourceData.version,
      source: sourceData.source,
      metadata: sourceData.metadata,
      talents: combinedTalents
          .map((entry) => TalentDef.fromJson(entry))
          .toList(growable: false),
      spells: spells
          .map((entry) => SpellDef.fromJson(entry))
          .toList(growable: false),
      weapons: weapons
          .map((entry) => WeaponDef.fromJson(entry))
          .toList(growable: false),
      maneuvers: maneuvers
          .map((entry) => ManeuverDef.fromJson(entry))
          .toList(growable: false),
      combatSpecialAbilities: combatSpecialAbilities
          .map((entry) => CombatSpecialAbilityDef.fromJson(entry))
          .toList(growable: false),
      generalSpecialAbilities: generalSpecialAbilities
          .map((entry) => SpecialAbilityDef.fromJson(entry))
          .toList(growable: false),
      magicSpecialAbilities: magicSpecialAbilities
          .map((entry) => SpecialAbilityDef.fromJson(entry))
          .toList(growable: false),
      karmalSpecialAbilities: karmalSpecialAbilities
          .map((entry) => SpecialAbilityDef.fromJson(entry))
          .toList(growable: false),
      sprachen: sprachen
          .map((entry) => SpracheDef.fromJson(entry))
          .toList(growable: false),
      schriften: schriften
          .map((entry) => SchriftDef.fromJson(entry))
          .toList(growable: false),
      reisebericht: sourceData.reisebericht
          .map((entry) => ReiseberichtDef.fromJson(entry))
          .toList(growable: false),
      ruleResolver: ruleResolver,
    );
  }
}

const List<CatalogSectionId> _requiredCatalogSections = <CatalogSectionId>[
  CatalogSectionId.talents,
  CatalogSectionId.combatTalents,
  CatalogSectionId.weapons,
  CatalogSectionId.spells,
];

const List<CatalogSectionId> _optionalCatalogSections = <CatalogSectionId>[
  CatalogSectionId.maneuvers,
  CatalogSectionId.combatSpecialAbilities,
  CatalogSectionId.generalSpecialAbilities,
  CatalogSectionId.magicSpecialAbilities,
  CatalogSectionId.karmalSpecialAbilities,
  CatalogSectionId.sprachen,
  CatalogSectionId.schriften,
];

class _CatalogSectionLoad {
  const _CatalogSectionLoad(this.section, this.entries);

  final CatalogSectionId section;
  final List<Map<String, dynamic>> entries;
}

class _BuiltInHouseRulePackLoad {
  const _BuiltInHouseRulePackLoad({
    required this.assetPath,
    this.manifest,
    this.issue,
  });

  final String assetPath;
  final HouseRulePackManifest? manifest;
  final HouseRulePackIssue? issue;
}

Future<_BuiltInHouseRulePackLoad> _loadBuiltInHouseRulePackManifest(
  String assetPath,
) async {
  try {
    final json = await _loadJsonObject(assetPath);
    final manifest = HouseRulePackManifest.fromJson(
      json,
      filePath: assetPath,
      isBuiltIn: true,
    );
    return _BuiltInHouseRulePackLoad(assetPath: assetPath, manifest: manifest);
  } on FormatException catch (error) {
    return _BuiltInHouseRulePackLoad(
      assetPath: assetPath,
      issue: HouseRulePackIssue(filePath: assetPath, message: error.message),
    );
  }
}

// Schwelle, ab der jsonDecode in einen Web-Worker / Isolate ausgelagert wird.
// Unter ~32 KB ist der Worker-Spawn-Overhead groesser als der eigentliche Decode.
const int _jsonDecodeOffThreadThreshold = 32 * 1024;

Object? _decodeJsonTopLevel(String raw) => jsonDecode(raw);

Future<Object?> _decodeJsonAdaptive(String raw) {
  if (raw.length > _jsonDecodeOffThreadThreshold) {
    return compute(_decodeJsonTopLevel, raw);
  }
  return Future.value(_decodeJsonTopLevel(raw));
}

/// Laedt eine JSON-Asset-Datei und gibt sie als Map zurueck.
///
/// Wirft [FormatException] wenn der Inhalt kein JSON-Objekt ist.
Future<Map<String, dynamic>> _loadJsonObject(String assetPath) async {
  final raw = await rootBundle.loadString(assetPath, cache: false);
  final decoded = await _decodeJsonAdaptive(raw);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.cast<String, dynamic>();
  }
  throw FormatException('Catalog asset is not a valid JSON object: $assetPath');
}

/// Laedt eine JSON-Asset-Datei und gibt sie als Liste von Maps zurueck.
///
/// Wirft [FormatException] wenn der Inhalt kein JSON-Array aus Objekten ist.
Future<List<Map<String, dynamic>>> _loadJsonList(String assetPath) async {
  final raw = await rootBundle.loadString(assetPath, cache: false);
  final decoded = await _decodeJsonAdaptive(raw);
  if (decoded is! List) {
    throw FormatException(
      'Catalog section asset must be a JSON array: $assetPath',
    );
  }

  final entries = <Map<String, dynamic>>[];
  for (var index = 0; index < decoded.length; index++) {
    final entry = decoded[index];
    if (entry is Map<String, dynamic>) {
      entries.add(entry);
      continue;
    }
    if (entry is Map) {
      entries.add(entry.cast<String, dynamic>());
      continue;
    }
    throw FormatException(
      'Catalog section asset contains non-object entry at index $index: $assetPath',
    );
  }
  return entries;
}

/// Liest ein Pflicht-Objekt aus einem JSON-Map.
///
/// Wirft [FormatException] wenn der Wert fehlt oder kein Objekt ist.
Map<String, dynamic> _readJsonObject(
  Map<String, dynamic> json,
  String key, {
  required String assetPath,
  required String context,
}) {
  final value = json[key];
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  throw FormatException('$context.$key must be a JSON object: $assetPath');
}

/// Liest einen Pflicht-String aus einem JSON-Map.
///
/// Wirft [FormatException] wenn der Wert fehlt oder leer ist.
String _readRequiredString(
  Map<String, dynamic> json,
  String key, {
  required String assetPath,
  required String context,
}) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw FormatException('$context.$key must be a non-empty string: $assetPath');
}

/// Liest einen optionalen String aus einem JSON-Map.
///
/// Gibt [fallback] zurueck wenn der Schluessel fehlt oder `null` ist.
String _readOptionalString(
  Map<String, dynamic> json,
  String key, {
  required String fallback,
}) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  if (value == null) {
    return fallback;
  }
  return value.toString();
}

/// Liest einen optionalen, nicht-leeren String aus einem JSON-Map.
///
/// Gibt `null` zurueck wenn der Schluessel fehlt, `null` ist oder leer ist.
String? _readOptionalStringFromMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

/// Berechnet den absoluten Asset-Pfad relativ zur Manifest-Datei.
///
/// Beispiel: `'assets/catalogs/v1/manifest.json'` + `'talente.json'`
/// ergibt `'assets/catalogs/v1/talente.json'`.
String _resolveAssetPath(String manifestAssetPath, String relativePath) {
  final baseDir = path.posix.dirname(manifestAssetPath);
  return path.posix.normalize(path.posix.join(baseDir, relativePath));
}

/// Prueft, ob alle Eintraege korrekt als Kampftalente markiert sind.
///
/// [mustBeCombatTalent] gibt an, ob die Eintraege in der Kampftalente-Datei
/// (group = 'Kampftalent') liegen muessen oder nicht.
/// Wirft [FormatException] bei Verletzungen.
void _validateCombatSplit({
  required List<Map<String, dynamic>> entries,
  required bool mustBeCombatTalent,
  required String assetPath,
}) {
  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    final groupRaw = entry['group'];
    final group = groupRaw == null ? '' : groupRaw.toString().trim();
    final isCombatTalent = group == 'Kampftalent';
    if (mustBeCombatTalent && !isCombatTalent) {
      throw FormatException(
        'Invalid talent split: entry at index $index in $assetPath is not group "Kampftalent".',
      );
    }
    if (!mustBeCombatTalent && isCombatTalent) {
      throw FormatException(
        'Invalid talent split: entry at index $index in $assetPath must not use group "Kampftalent".',
      );
    }
  }
}

/// Prueft, ob alle Eintraege eindeutige, nicht-leere IDs besitzen.
///
/// Wirft [FormatException] bei fehlenden oder duplizierten IDs.
void _validateUniqueIds({
  required List<Map<String, dynamic>> entries,
  required String domainName,
  required String assetPath,
}) {
  final seen = <String>{};
  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    final idRaw = entry['id'];
    final id = idRaw == null ? '' : idRaw.toString().trim();
    if (id.isEmpty) {
      throw FormatException(
        'Invalid $domainName entry at index $index: missing non-empty "id" ($assetPath).',
      );
    }
    if (!seen.add(id)) {
      throw FormatException(
        'Duplicate $domainName id "$id" detected in catalog ($assetPath).',
      );
    }
  }
}

Future<List<Map<String, dynamic>>> _loadRequiredSection({
  required Map<String, dynamic> files,
  required String manifestAssetPath,
  required CatalogSectionId section,
}) async {
  final relativePath = _readRequiredString(
    files,
    section.manifestFileKey,
    assetPath: manifestAssetPath,
    context: 'manifest.files',
  );
  final assetPath = _resolveAssetPath(manifestAssetPath, relativePath);
  return _loadJsonList(assetPath);
}

Future<List<Map<String, dynamic>>> _loadOptionalSection({
  required Map<String, dynamic> files,
  required String manifestAssetPath,
  required CatalogSectionId section,
}) {
  return _loadOptionalSectionByKey(
    files: files,
    manifestAssetPath: manifestAssetPath,
    manifestKey: section.manifestFileKey,
  );
}

Future<List<Map<String, dynamic>>> _loadOptionalSectionByKey({
  required Map<String, dynamic> files,
  required String manifestAssetPath,
  required String manifestKey,
}) async {
  final relativePath = _readOptionalStringFromMap(files, manifestKey);
  if (relativePath == null) {
    return const <Map<String, dynamic>>[];
  }
  final assetPath = _resolveAssetPath(manifestAssetPath, relativePath);
  return _loadJsonList(assetPath);
}
