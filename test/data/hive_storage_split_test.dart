import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/hive_hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

void main() {
  setUpAll(() {
    // Aktiviert den In-Memory-Mock fuer flutter_secure_storage in Unit-Tests.
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('stores settings and heroes in separate directories', () async {
    final root = await Directory.systemTemp.createTemp(
      'dsa_storage_split_test_',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final settingsPath = '${root.path}${Platform.pathSeparator}settings';
    final heroesPath = '${root.path}${Platform.pathSeparator}heroes';

    final settingsRepo = await HiveSettingsRepository.create(
      storagePath: settingsPath,
    );
    addTearDown(settingsRepo.close);

    final heroRepo = await HiveHeroRepository.create(storagePath: heroesPath);
    addTearDown(heroRepo.close);

    await settingsRepo.save(const AppSettings(dunkelModus: true));
    await heroRepo.saveHero(
      const HeroSheet(
        id: 'held-1',
        name: 'Alrik',
        level: 1,
        attributes: Attributes(
          mu: 11,
          kl: 11,
          inn: 11,
          ch: 11,
          ff: 11,
          ge: 11,
          ko: 11,
          kk: 11,
        ),
      ),
    );

    final settingsFiles = await Directory(settingsPath)
        .list()
        .map((entity) => entity.path.split(Platform.pathSeparator).last)
        .toList();
    final heroFiles = await Directory(heroesPath)
        .list()
        .map((entity) => entity.path.split(Platform.pathSeparator).last)
        .toList();

    expect(settingsFiles.any((name) => name.contains('app_settings_v1')), isTrue);
    expect(settingsFiles.any((name) => name.contains('heroes_v1')), isFalse);
    expect(heroFiles.any((name) => name.contains('heroes_v1')), isTrue);
    expect(heroFiles.any((name) => name.contains('app_settings_v1')), isFalse);
  });
}
