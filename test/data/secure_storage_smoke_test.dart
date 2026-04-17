import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_config.dart';

void main() {
  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dsa_secure_smoke_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('HiveSettingsRepository — Secure Storage', () {
    test('API-Key wird in Secure Storage gespeichert und wieder gelesen', () async {
      final repo = await HiveSettingsRepository.create(storagePath: root.path);
      addTearDown(repo.close);

      const apiKey = 'sk-test-1234';
      await repo.save(
        const AppSettings(avatarApiConfig: AvatarApiConfig(apiKey: apiKey)),
      );

      final loaded = repo.load();
      expect(loaded.avatarApiConfig.apiKey, apiKey);
    });

    test('Katalog-Passwort wird in Secure Storage gespeichert und wieder gelesen', () async {
      final repo = await HiveSettingsRepository.create(storagePath: root.path);
      addTearDown(repo.close);

      const pw = 'meinKatalogPw99';
      await repo.save(const AppSettings(catalogContentPassword: pw));

      final loaded = repo.load();
      expect(loaded.catalogContentPassword, pw);
    });
  });
}
