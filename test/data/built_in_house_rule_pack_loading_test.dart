import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog loader discovers built-in house rule packs from assets', () async {
    const loader = CatalogLoader();
    final baseData = await loader.loadDefaultSourceData();
    final snapshot = await loader.loadBuiltInHouseRulePacks(
      catalogVersion: baseData.version,
    );
    final packIds = snapshot.packs.map((pack) => pack.id).toSet();

    expect(snapshot.issues, isEmpty);
    expect(packIds, contains('epic_rules_v1'));
    expect(packIds, contains('regelwerk_ueberarbeitung_v1'));
    expect(
      packIds,
      contains('regelwerk_ueberarbeitung_v1.talents_learning'),
    );
  });

  test('every built-in pack manifest is declared as Flutter asset', () {
    final pubspecAssets = _readPubspecAssetEntries();
    final manifestDirectory = Directory('assets/catalogs/house_rules_v1/packs');
    final builtInManifestPaths = manifestDirectory
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => _normalizeAssetPath(file.path))
        .where((path) => path.endsWith('/manifest.json'))
        .toList(growable: false)
      ..sort();

    final missingAssets = builtInManifestPaths
        .where((assetPath) => !pubspecAssets.contains(assetPath))
        .toList(growable: false);

    expect(
      missingAssets,
      isEmpty,
      reason:
          'Diese Pack-Manifeste fehlen in pubspec.yaml und tauchen dadurch '
          'nicht in den Einstellungen auf:\n${missingAssets.join('\n')}',
    );
  });
}

// Liest die explizit deklarierten Asset-Pfade aus dem Flutter-Manifest.
Set<String> _readPubspecAssetEntries() {
  final lines = File('pubspec.yaml').readAsLinesSync();
  final assets = <String>{};
  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (!line.startsWith('- ')) {
      continue;
    }
    assets.add(_normalizeAssetPath(line.substring(2).trim()));
  }
  return assets;
}

// Vereinheitlicht Windows- und POSIX-Pfade fuer String-Vergleiche.
String _normalizeAssetPath(String path) {
  return path.replaceAll('\\', '/');
}
