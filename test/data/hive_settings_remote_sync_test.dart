import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/firestore_secrets_repository.dart';
import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/data/secrets_cipher.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_config.dart';

class FakeRemoteSecretsRepository implements RemoteSecretsRepository {
  RemoteSecrets? stored;
  int saveCount = 0;
  int loadCount = 0;

  @override
  Future<RemoteSecrets?> load() async {
    loadCount++;
    return stored;
  }

  @override
  Future<void> save(RemoteSecrets secrets) async {
    saveCount++;
    stored = secrets;
  }
}

void main() {
  late Directory root;
  const testUid = 'test-uid-1234';

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('dsa_remote_sync_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('HiveSettingsRepository — Firestore-Sync via attachUser', () {
    test('attachUser pulled Werte aus Remote in lokalen Cache, wenn lokal leer', () async {
      // Remote vorbefuellen: API-Key und Katalog-Passwort
      final cipher = SecretsCipher.forUser(testUid);
      final apiEnc = cipher.encryptString('sk-from-remote');
      final pwEnc = cipher.encryptString('katalog-pw-remote');
      final fake = FakeRemoteSecretsRepository()
        ..stored = RemoteSecrets(
          catalogPasswordCipher: pwEnc.cipher,
          catalogPasswordIv: pwEnc.iv,
          catalogPasswordSet: true,
          apiKeyCipher: apiEnc.cipher,
          apiKeyIv: apiEnc.iv,
          apiProvider: AvatarApiProvider.openaiDalle3.name,
          cipherVersion: 1,
          lastModified: DateTime.now(),
        );

      final repo = await HiveSettingsRepository.create(storagePath: root.path);
      addTearDown(repo.close);

      await repo.attachUser(testUid, remote: fake, cipher: cipher);

      final loaded = repo.load();
      expect(loaded.avatarApiConfig.apiKey, 'sk-from-remote');
      expect(loaded.avatarApiConfig.provider, AvatarApiProvider.openaiDalle3);
      expect(loaded.catalogContentPassword, 'katalog-pw-remote');
    });

    test('attachUser pushed lokale Werte ins Remote, wenn Remote leer', () async {
      final repo = await HiveSettingsRepository.create(storagePath: root.path);
      addTearDown(repo.close);

      await repo.save(const AppSettings(
        avatarApiConfig: AvatarApiConfig(
          provider: AvatarApiProvider.openaiGptImage1,
          apiKey: 'sk-local-only',
        ),
        catalogContentPassword: 'pw-local-only',
      ));

      final cipher = SecretsCipher.forUser(testUid);
      final fake = FakeRemoteSecretsRepository();

      await repo.attachUser(testUid, remote: fake, cipher: cipher);

      expect(fake.stored, isNotNull,
          reason: 'Remote muss nach attachUser mit lokalen Werten befuellt sein');
      final stored = fake.stored!;
      expect(stored.catalogPasswordSet, isTrue);
      expect(stored.apiProvider, AvatarApiProvider.openaiGptImage1.name);

      final pwBack = cipher.decryptString(
        cipher: stored.catalogPasswordCipher,
        iv: stored.catalogPasswordIv,
      );
      final keyBack = cipher.decryptString(
        cipher: stored.apiKeyCipher,
        iv: stored.apiKeyIv,
      );
      expect(pwBack, 'pw-local-only');
      expect(keyBack, 'sk-local-only');
    });

    test('attachUser: bei Konflikt gewinnt Remote', () async {
      final repo = await HiveSettingsRepository.create(storagePath: root.path);
      addTearDown(repo.close);

      await repo.save(const AppSettings(
        avatarApiConfig: AvatarApiConfig(apiKey: 'lokal-key'),
        catalogContentPassword: 'lokal-pw',
      ));

      final cipher = SecretsCipher.forUser(testUid);
      final apiEnc = cipher.encryptString('remote-key');
      final pwEnc = cipher.encryptString('remote-pw');
      final fake = FakeRemoteSecretsRepository()
        ..stored = RemoteSecrets(
          catalogPasswordCipher: pwEnc.cipher,
          catalogPasswordIv: pwEnc.iv,
          catalogPasswordSet: true,
          apiKeyCipher: apiEnc.cipher,
          apiKeyIv: apiEnc.iv,
          apiProvider: AvatarApiProvider.openaiGptImage1.name,
          cipherVersion: 1,
          lastModified: DateTime.now(),
        );

      await repo.attachUser(testUid, remote: fake, cipher: cipher);

      final loaded = repo.load();
      expect(loaded.avatarApiConfig.apiKey, 'remote-key');
      expect(loaded.catalogContentPassword, 'remote-pw');
    });

    test('attachUser: beide leer = kein Remote-Save, kein Lokal-Update', () async {
      final repo = await HiveSettingsRepository.create(storagePath: root.path);
      addTearDown(repo.close);

      final cipher = SecretsCipher.forUser(testUid);
      final fake = FakeRemoteSecretsRepository();

      await repo.attachUser(testUid, remote: fake, cipher: cipher);

      expect(fake.stored, isNull);
      final loaded = repo.load();
      expect(loaded.avatarApiConfig.apiKey, '');
      expect(loaded.catalogContentPassword, isNull);
    });

    test('save() nach attachUser schreibt verschluesselt ins Remote', () async {
      final repo = await HiveSettingsRepository.create(storagePath: root.path);
      addTearDown(repo.close);

      final cipher = SecretsCipher.forUser(testUid);
      final fake = FakeRemoteSecretsRepository();
      await repo.attachUser(testUid, remote: fake, cipher: cipher);

      await repo.save(const AppSettings(
        avatarApiConfig: AvatarApiConfig(apiKey: 'sk-new-after-attach'),
        catalogContentPassword: 'pw-new-after-attach',
      ));

      expect(fake.stored, isNotNull);
      final stored = fake.stored!;
      // Cipher-Bytes duerfen nicht den Klartext enthalten.
      expect(_containsAscii(stored.apiKeyCipher, 'sk-new-after-attach'), isFalse);
      expect(_containsAscii(stored.catalogPasswordCipher, 'pw-new-after-attach'),
          isFalse);
      // Aber decrypt liefert den Original-Klartext zurueck.
      expect(
        cipher.decryptString(
          cipher: stored.apiKeyCipher,
          iv: stored.apiKeyIv,
        ),
        'sk-new-after-attach',
      );
      expect(
        cipher.decryptString(
          cipher: stored.catalogPasswordCipher,
          iv: stored.catalogPasswordIv,
        ),
        'pw-new-after-attach',
      );
    });

    test('detachUser stoppt nachfolgende Remote-Writes', () async {
      final repo = await HiveSettingsRepository.create(storagePath: root.path);
      addTearDown(repo.close);

      final cipher = SecretsCipher.forUser(testUid);
      final fake = FakeRemoteSecretsRepository();
      await repo.attachUser(testUid, remote: fake, cipher: cipher);

      await repo.save(const AppSettings(
        avatarApiConfig: AvatarApiConfig(apiKey: 'before-detach'),
      ));
      final saveCountBefore = fake.saveCount;

      await repo.detachUser();

      await repo.save(const AppSettings(
        avatarApiConfig: AvatarApiConfig(apiKey: 'after-detach'),
      ));

      expect(fake.saveCount, saveCountBefore,
          reason: 'Nach detachUser darf kein weiterer Remote-Write erfolgen');
    });

    test('save() schreibt nicht ins Remote, solange noch nicht attached', () async {
      final repo = await HiveSettingsRepository.create(storagePath: root.path);
      addTearDown(repo.close);

      // Kein attachUser aufgerufen.
      await repo.save(const AppSettings(
        avatarApiConfig: AvatarApiConfig(apiKey: 'sk-pre-login'),
      ));

      // Es gibt nichts zu pruefen — der einzige Test ist, dass kein
      // Exception fliegt und der lokale Save funktioniert.
      final loaded = repo.load();
      expect(loaded.avatarApiConfig.apiKey, 'sk-pre-login');
    });
  });
}

bool _containsAscii(Uint8List bytes, String needle) {
  final ascii = String.fromCharCodes(bytes.where((b) => b >= 32 && b < 127));
  return ascii.contains(needle);
}
