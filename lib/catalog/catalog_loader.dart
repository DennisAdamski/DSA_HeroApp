import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';

class CatalogLoader {
  const CatalogLoader({this.defaultAssetPath = 'assets/catalogs/house_rules_v1.json'});

  final String defaultAssetPath;

  Future<RulesCatalog> loadDefaultCatalog() {
    return loadFromAsset(defaultAssetPath);
  }

  Future<RulesCatalog> loadFromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Catalog asset is not a valid JSON object: $assetPath');
    }
    return RulesCatalog.fromJson(decoded);
  }
}
