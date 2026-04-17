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

    test('API-Key und Passwort landen nicht im Hive-Klartext', () async {
      final repo = await HiveSettingsRepository.create(storagePath: root.path);
      addTearDown(repo.close);

      await repo.save(const AppSettings(
        avatarApiConfig: AvatarApiConfig(apiKey: 'sk-geheim'),
        catalogContentPassword: 'pw-geheim',
      ));

      // Hive-Box-Datei nach sensiblen Strings durchsuchen
      final hiveFile = File('${root.path}/app_settings_v1.hive');
      expect(await hiveFile.exists(), isTrue,
          reason: 'app_settings_v1.hive muss nach save() existieren');
      final bytes = await hiveFile.readAsBytes();
      final content = String.fromCharCodes(bytes.where((b) => b >= 32 && b < 127));
      expect(content, isNot(contains('sk-geheim')));
      expect(content, isNot(contains('pw-geheim')));
    });
  });
}
