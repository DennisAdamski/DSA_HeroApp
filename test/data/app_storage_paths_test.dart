import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/storage_exceptions.dart';

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('resolves settings and hero default paths beneath app support path', () async {
    final createdPaths = <String>[];
    final storagePaths = AppStoragePaths(
      appSupportPathLoader: () async => '/app/support',
      directoryCreator: (path) async {
        createdPaths.add(path);
      },
    );

    final settingsPath = await storagePaths.resolveSettingsStoragePath();
    final heroPath = await storagePaths.resolveDefaultHeroStoragePath();

    expect(settingsPath, p.join('/app/support', 'Einstellungen'));
    expect(heroPath, p.join('/app/support', 'Helden'));
    expect(createdPaths, <String>[settingsPath]);
  });

  test('uses configured custom hero path when validator accepts it', () async {
    final validatedPaths = <String>[];
    final storagePaths = AppStoragePaths(
      appSupportPathLoader: () async => '/app/support',
      directoryValidator: (path) async {
        validatedPaths.add(path);
      },
      directoryCreator: (path) async {},
    );

    final location = await storagePaths.describeHeroStorageLocation(
      configuredPath: '/cloud/heroes',
    );

    expect(location.usesCustomPath, isTrue);
    expect(location.effectivePath, '/cloud/heroes');
    expect(location.validationError, isNull);
    expect(validatedPaths, <String>['/cloud/heroes']);
  });

  test('reports invalid custom hero path without falling back silently', () async {
    final storagePaths = AppStoragePaths(
      appSupportPathLoader: () async => '/app/support',
      directoryValidator: (path) async {
        throw const HeroStoragePathException('Pfad nicht beschreibbar.');
      },
      directoryCreator: (path) async {},
    );

    final location = await storagePaths.describeHeroStorageLocation(
      configuredPath: '/cloud/heroes',
    );

    expect(location.usesCustomPath, isTrue);
    expect(location.isAccessible, isFalse);
    expect(location.validationError, 'Pfad nicht beschreibbar.');
    expect(location.effectivePath, '/cloud/heroes');
  });

  test(
    'uses logical browser storage paths without creating local directories',
    () async {
      var directoryCreateCalls = 0;
      final storagePaths = AppStoragePaths(
        appSupportPathLoader: () async => 'Browser-Speicher',
        directoryCreator: (path) async {
          directoryCreateCalls++;
        },
        customHeroStorageSupport: () => false,
        localDirectorySupport: () => false,
      );

      final settingsPath = await storagePaths.resolveSettingsStoragePath();
      final heroPath = await storagePaths.prepareHeroStoragePath(
        configuredPath: '/cloud/heroes',
      );
      final location = await storagePaths.describeHeroStorageLocation(
        configuredPath: '/cloud/heroes',
      );

      expect(settingsPath, p.join('Browser-Speicher', 'Einstellungen'));
      expect(heroPath, p.join('Browser-Speicher', 'Helden'));
      expect(directoryCreateCalls, 0);
      expect(location.customPathSupported, isFalse);
      expect(location.usesCustomPath, isFalse);
      expect(location.effectivePath, heroPath);
    },
  );
}
