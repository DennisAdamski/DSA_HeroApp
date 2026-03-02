import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';

class CatalogLoader {
  const CatalogLoader({
    this.defaultAssetPath = 'assets/catalogs/house_rules_v1/manifest.json',
  });

  final String defaultAssetPath;

  Future<RulesCatalog> loadDefaultCatalog() {
    return loadFromAsset(defaultAssetPath);
  }

  Future<RulesCatalog> loadFromAsset(String manifestAssetPath) async {
    final manifest = await _loadJsonObject(manifestAssetPath);
    final files = _readJsonObject(
      manifest,
      'files',
      assetPath: manifestAssetPath,
      context: 'manifest',
    );
    final metadata =
        (manifest['metadata'] as Map?)?.cast<String, dynamic>() ?? const {};

    final talenteAssetPath = _resolveAssetPath(
      manifestAssetPath,
      _readRequiredString(
        files,
        'talente',
        assetPath: manifestAssetPath,
        context: 'manifest.files',
      ),
    );
    final waffentalenteAssetPath = _resolveAssetPath(
      manifestAssetPath,
      _readRequiredString(
        files,
        'waffentalente',
        assetPath: manifestAssetPath,
        context: 'manifest.files',
      ),
    );
    final waffenAssetPath = _resolveAssetPath(
      manifestAssetPath,
      _readRequiredString(
        files,
        'waffen',
        assetPath: manifestAssetPath,
        context: 'manifest.files',
      ),
    );
    final magieAssetPath = _resolveAssetPath(
      manifestAssetPath,
      _readRequiredString(
        files,
        'magie',
        assetPath: manifestAssetPath,
        context: 'manifest.files',
      ),
    );

    final manoeverRelative = _readOptionalStringFromMap(files, 'manoever');
    final manoeverAssetPath = manoeverRelative != null
        ? _resolveAssetPath(manifestAssetPath, manoeverRelative)
        : null;

    final talente = await _loadJsonList(talenteAssetPath);
    final waffentalente = await _loadJsonList(waffentalenteAssetPath);
    final waffen = await _loadJsonList(waffenAssetPath);
    final magie = await _loadJsonList(magieAssetPath);
    final manoeverRaw = manoeverAssetPath != null
        ? await _loadJsonList(manoeverAssetPath)
        : const <Map<String, dynamic>>[];

    _validateCombatSplit(
      entries: talente,
      mustBeCombatTalent: false,
      assetPath: talenteAssetPath,
    );
    _validateCombatSplit(
      entries: waffentalente,
      mustBeCombatTalent: true,
      assetPath: waffentalenteAssetPath,
    );

    final combinedTalents = <Map<String, dynamic>>[
      ...talente,
      ...waffentalente,
    ];
    _validateUniqueIds(
      entries: combinedTalents,
      domainName: 'talents',
      assetPath: manifestAssetPath,
    );
    _validateUniqueIds(
      entries: magie,
      domainName: 'spells',
      assetPath: manifestAssetPath,
    );
    _validateUniqueIds(
      entries: waffen,
      domainName: 'weapons',
      assetPath: manifestAssetPath,
    );

    return RulesCatalog(
      version: _readOptionalString(manifest, 'version', fallback: 'unknown'),
      source: _readOptionalString(manifest, 'source', fallback: 'unknown'),
      metadata: metadata,
      talents: combinedTalents
          .map((entry) => TalentDef.fromJson(entry))
          .toList(growable: false),
      spells: magie
          .map((entry) => SpellDef.fromJson(entry))
          .toList(growable: false),
      weapons: waffen
          .map((entry) => WeaponDef.fromJson(entry))
          .toList(growable: false),
      maneuvers: manoeverRaw
          .map((entry) => ManeuverDef.fromJson(entry))
          .toList(growable: false),
    );
  }
}

Future<Map<String, dynamic>> _loadJsonObject(String assetPath) async {
  final raw = await rootBundle.loadString(assetPath, cache: false);
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.cast<String, dynamic>();
  }
  throw FormatException('Catalog asset is not a valid JSON object: $assetPath');
}

Future<List<Map<String, dynamic>>> _loadJsonList(String assetPath) async {
  final raw = await rootBundle.loadString(assetPath, cache: false);
  final decoded = jsonDecode(raw);
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

String? _readOptionalStringFromMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

String _resolveAssetPath(String manifestAssetPath, String relativePath) {
  final slashIndex = manifestAssetPath.lastIndexOf('/');
  if (slashIndex < 0) {
    return relativePath;
  }
  final baseDir = manifestAssetPath.substring(0, slashIndex);
  return '$baseDir/$relativePath';
}

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
