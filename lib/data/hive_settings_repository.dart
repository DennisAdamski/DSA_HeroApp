import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

import 'package:dsa_heldenverwaltung/data/firestore_secrets_repository.dart';
import 'package:dsa_heldenverwaltung/data/secrets_cipher.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_config.dart';

/// Hive-basierte Persistenz fuer globale App-Einstellungen.
///
/// Sensible Felder (OpenAI API-Key, Katalog-Passwort) werden ueber
/// [FlutterSecureStorage] im Betriebssystem-Schluessel-Speicher abgelegt
/// (iOS Keychain, Android Keystore, Windows Credential Manager).
/// Alle anderen Felder liegen in der unverschluesselten Hive-Box.
class HiveSettingsRepository {
  HiveSettingsRepository._(
    this._box,
    this._secure,
    this._cachedApiKey,
    this._cachedCatalogPassword,
  );

  static const _boxName = 'app_settings_v1';
  static const _settingsKey = 'settings';
  static const _apiKeySecureKey = 'avatar_api_key';
  static const _catalogPasswordSecureKey = 'catalog_content_password';

  final Box<Map> _box;
  final FlutterSecureStorage _secure;

  String _cachedApiKey;
  String? _cachedCatalogPassword;

  RemoteSecretsRepository? _remote;
  SecretsCipher? _cipher;
  String? _attachedUid;

  final StreamController<AppSettings> _controller =
      StreamController<AppSettings>.broadcast();

  /// Erstellt und initialisiert das Settings-Repository.
  ///
  /// Migriert einmalig vorhandene sensible Felder aus Hive in den
  /// sicheren Speicher, falls dort noch keine Werte hinterlegt sind.
  ///
  /// Auf Web wird FlutterSecureStorage uebergangen — sensible Felder
  /// koennen dort ohnehin nicht durchgehend abgesichert werden, und einige
  /// Browser werfen bei der Initialisierung Fehler. Der API-Key bleibt
  /// deshalb auf Web nicht persistiert. Das Katalog-Passwort wird seit
  /// Web v2 dagegen als Klartext in der Hive-Box (IndexedDB) abgelegt — es
  /// dient nur als Casual-Schutz vor versehentlichem Lesen geschuetzter
  /// Inhalte und muss zur Entschluesselung ohnehin im Klartext im RAM liegen.
  static Future<HiveSettingsRepository> create({
    required String storagePath,
  }) async {
    const secure = FlutterSecureStorage();
    final box = await Hive.openBox<Map>(_boxName, path: storagePath);

    if (kIsWeb) {
      final raw = box.get(_settingsKey);
      final cachedPassword = raw == null
          ? null
          : AppSettings.fromJson(raw.cast<String, dynamic>())
                .catalogContentPassword;
      return HiveSettingsRepository._(box, secure, '', cachedPassword);
    }

    var cachedApiKey = await secure.read(key: _apiKeySecureKey) ?? '';
    final rawCatalogPw = await secure.read(key: _catalogPasswordSecureKey);
    var cachedCatalogPassword =
        (rawCatalogPw == null || rawCatalogPw.isEmpty) ? null : rawCatalogPw;

    // Einmalige Migration: sensible Felder aus Hive in Secure Storage umziehen.
    final rawHive = box.get(_settingsKey);
    if (rawHive != null) {
      final oldSettings = AppSettings.fromJson(rawHive.cast<String, dynamic>());
      var migrated = false;

      if (cachedApiKey.isEmpty && oldSettings.avatarApiConfig.apiKey.isNotEmpty) {
        cachedApiKey = oldSettings.avatarApiConfig.apiKey;
        await secure.write(key: _apiKeySecureKey, value: cachedApiKey);
        migrated = true;
      }

      if (cachedCatalogPassword == null &&
          oldSettings.catalogContentPassword != null) {
        cachedCatalogPassword = oldSettings.catalogContentPassword;
        await secure.write(
          key: _catalogPasswordSecureKey,
          value: cachedCatalogPassword!,
        );
        migrated = true;
      }

      if (migrated) {
        final stripped = _stripSensitiveFields(oldSettings);
        await box.put(_settingsKey, stripped.toJson());
      }
    }

    return HiveSettingsRepository._(box, secure, cachedApiKey, cachedCatalogPassword);
  }

  /// Laedt die aktuellen Einstellungen (oder Defaults bei leerer Box).
  ///
  /// Sensible Felder werden aus dem In-Memory-Cache injiziert, der beim
  /// Start aus dem sicheren Speicher bevoelkert wurde.
  AppSettings load() {
    final raw = _box.get(_settingsKey);
    final base =
        raw == null ? const AppSettings() : AppSettings.fromJson(raw.cast<String, dynamic>());
    return base.copyWith(
      avatarApiConfig: base.avatarApiConfig.copyWith(apiKey: _cachedApiKey),
      catalogContentPassword: _cachedCatalogPassword,
    );
  }

  /// Speichert die Einstellungen persistent und benachrichtigt Listener.
  ///
  /// Sensible Felder gehen in den sicheren Speicher; alle anderen in Hive.
  /// Auf Web wird FlutterSecureStorage uebergangen.
  /// Wenn ein User via [attachUser] verbunden ist, werden die sensiblen
  /// Felder zusaetzlich verschluesselt nach Firestore geschrieben.
  Future<void> save(AppSettings settings) async {
    _cachedApiKey = settings.avatarApiConfig.apiKey;
    _cachedCatalogPassword = settings.catalogContentPassword;

    if (kIsWeb) {
      await _box.put(_settingsKey, _stripWebSensitiveFields(settings).toJson());
    } else {
      await Future.wait([
        _secure.write(key: _apiKeySecureKey, value: _cachedApiKey),
        _secure.write(
          key: _catalogPasswordSecureKey,
          value: _cachedCatalogPassword ?? '',
        ),
        _box.put(_settingsKey, _stripSensitiveFields(settings).toJson()),
      ]);
    }

    final remote = _remote;
    final cipher = _cipher;
    if (remote != null && cipher != null) {
      try {
        await remote.save(_buildRemoteSecrets(
          cipher: cipher,
          apiKey: _cachedApiKey,
          catalogPassword: _cachedCatalogPassword,
          provider: settings.avatarApiConfig.provider,
        ));
      } on Object catch (e, st) {
        // Remote-Fehler blockieren den lokalen Save nicht (siehe HybridHeroRepository).
        debugPrint('[settings] remote save fehlgeschlagen: $e\n$st');
      }
    }

    _controller.add(settings);
  }

  /// Verbindet das Repository mit dem Firestore-Account des eingeloggten Users.
  ///
  /// Beim Aufruf wird einmalig ein Sync gemaess Konflikt-Tabelle ausgefuehrt:
  /// - lokal leer + remote leer: nichts.
  /// - lokal gefuellt + remote leer: lokale Werte hochladen.
  /// - lokal leer + remote gefuellt: remote Werte herunterladen.
  /// - beide gefuellt: remote gewinnt.
  ///
  /// In Tests koennen [remote] und [cipher] direkt injiziert werden.
  /// In Produktion werden sie aus der [uid] erzeugt.
  Future<void> attachUser(
    String uid, {
    RemoteSecretsRepository? remote,
    SecretsCipher? cipher,
  }) async {
    final effectiveRemote =
        remote ?? FirestoreSecretsRepository(userId: uid);
    final effectiveCipher = cipher ?? SecretsCipher.forUser(uid);

    _attachedUid = uid;
    _remote = effectiveRemote;
    _cipher = effectiveCipher;

    try {
      await _reconcileWithRemote();
    } on Object catch (e, st) {
      debugPrint('[settings] remote reconcile fehlgeschlagen: $e\n$st');
    }
  }

  /// Trennt das Repository vom Firestore-Account.
  ///
  /// Auf Web wird zusaetzlich der In-Memory-Cache geleert, damit ein
  /// nachfolgender Login mit anderem User keine alten Werte erbt.
  Future<void> detachUser() async {
    _remote = null;
    _cipher = null;
    _attachedUid = null;

    if (kIsWeb) {
      _cachedApiKey = '';
      _cachedCatalogPassword = null;
      _controller.add(load());
    }
  }

  /// True, sobald [attachUser] erfolgreich aufgerufen wurde.
  bool get isAttached => _remote != null;

  /// UID des aktuell verbundenen Users (oder `null`).
  String? get attachedUid => _attachedUid;

  Future<void> _reconcileWithRemote() async {
    final remote = _remote;
    final cipher = _cipher;
    if (remote == null || cipher == null) {
      return;
    }

    final localSettings = load();
    final localApiKey = localSettings.avatarApiConfig.apiKey;
    final localPassword = localSettings.catalogContentPassword;
    final localProvider = localSettings.avatarApiConfig.provider;

    final remoteSecrets = await remote.load();

    if (remoteSecrets == null) {
      // Remote leer: lokale Werte hochladen, falls vorhanden.
      if (localApiKey.isNotEmpty || (localPassword?.isNotEmpty ?? false)) {
        await remote.save(_buildRemoteSecrets(
          cipher: cipher,
          apiKey: localApiKey,
          catalogPassword: localPassword,
          provider: localProvider,
        ));
      }
      return;
    }

    // Remote vorhanden: Werte entschluesseln und uebernehmen (Remote gewinnt
    // bei beidseitig gefuellten Werten, Remote setzt auch leere Werte).
    final remoteApiKey = remoteSecrets.apiKeyCipher.isEmpty
        ? ''
        : cipher.decryptString(
            cipher: remoteSecrets.apiKeyCipher,
            iv: remoteSecrets.apiKeyIv,
          );
    final remotePassword = !remoteSecrets.catalogPasswordSet
        ? null
        : remoteSecrets.catalogPasswordCipher.isEmpty
            ? ''
            : cipher.decryptString(
                cipher: remoteSecrets.catalogPasswordCipher,
                iv: remoteSecrets.catalogPasswordIv,
              );
    final remoteProvider =
        AvatarApiProvider.fromId(remoteSecrets.apiProvider) ?? localProvider;

    // Wenn lokal gefuellt und remote leer (pro Wert): lokale gewinnen — sonst Remote.
    final mergedApiKey =
        remoteApiKey.isEmpty && localApiKey.isNotEmpty ? localApiKey : remoteApiKey;
    final mergedPassword = (remotePassword == null || remotePassword.isEmpty) &&
            (localPassword?.isNotEmpty ?? false)
        ? localPassword
        : remotePassword;
    final mergedProvider =
        remoteSecrets.apiProvider.isEmpty ? localProvider : remoteProvider;

    final hasLocalChange =
        mergedApiKey != localApiKey || mergedPassword != localPassword;
    if (hasLocalChange) {
      await save(localSettings.copyWith(
        avatarApiConfig: localSettings.avatarApiConfig.copyWith(
          apiKey: mergedApiKey,
          provider: mergedProvider,
        ),
        catalogContentPassword: mergedPassword,
      ));
    } else if (mergedApiKey != remoteApiKey ||
        mergedPassword != remotePassword ||
        mergedProvider.name != remoteSecrets.apiProvider) {
      // Remote war unvollstaendig — lokales Bild dorthin schreiben.
      await remote.save(_buildRemoteSecrets(
        cipher: cipher,
        apiKey: mergedApiKey,
        catalogPassword: mergedPassword,
        provider: mergedProvider,
      ));
    }
  }

  static RemoteSecrets _buildRemoteSecrets({
    required SecretsCipher cipher,
    required String apiKey,
    required String? catalogPassword,
    required AvatarApiProvider provider,
  }) {
    final apiEnc = cipher.encryptString(apiKey);
    final pwPlain = catalogPassword ?? '';
    final pwEnc = cipher.encryptString(pwPlain);
    return RemoteSecrets(
      catalogPasswordCipher: pwEnc.cipher,
      catalogPasswordIv: pwEnc.iv,
      catalogPasswordSet: catalogPassword != null && catalogPassword.isNotEmpty,
      apiKeyCipher: apiEnc.cipher,
      apiKeyIv: apiEnc.iv,
      apiProvider: provider.name,
      cipherVersion: 1,
      lastModified: DateTime.now(),
    );
  }

  /// Stream der Einstellungsaenderungen.
  Stream<AppSettings> watch() => _controller.stream;

  /// Schliesst Box und Streamcontroller.
  Future<void> close() async {
    await _controller.close();
    await _box.close();
  }

  static AppSettings _stripSensitiveFields(AppSettings s) => s.copyWith(
        avatarApiConfig: s.avatarApiConfig.copyWith(apiKey: ''),
        catalogContentPassword: null,
      );

  // Auf Web bleibt der API-Key gestrippt, das Katalog-Passwort wird dagegen
  // bewusst im Klartext in der Hive-Box persistiert (siehe `create`).
  static AppSettings _stripWebSensitiveFields(AppSettings s) => s.copyWith(
        avatarApiConfig: s.avatarApiConfig.copyWith(apiKey: ''),
      );
}
