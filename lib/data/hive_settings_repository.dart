import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

import 'package:dsa_heldenverwaltung/domain/app_settings.dart';

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

  final StreamController<AppSettings> _controller =
      StreamController<AppSettings>.broadcast();

  /// Erstellt und initialisiert das Settings-Repository.
  ///
  /// Migriert einmalig vorhandene sensible Felder aus Hive in den
  /// sicheren Speicher, falls dort noch keine Werte hinterlegt sind.
  static Future<HiveSettingsRepository> create({
    required String storagePath,
  }) async {
    const secure = FlutterSecureStorage();
    final box = await Hive.openBox<Map>(_boxName, path: storagePath);

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
  Future<void> save(AppSettings settings) async {
    _cachedApiKey = settings.avatarApiConfig.apiKey;
    _cachedCatalogPassword = settings.catalogContentPassword;

    await Future.wait([
      _secure.write(key: _apiKeySecureKey, value: _cachedApiKey),
      _secure.write(
        key: _catalogPasswordSecureKey,
        value: _cachedCatalogPassword ?? '',
      ),
      _box.put(_settingsKey, _stripSensitiveFields(settings).toJson()),
    ]);

    _controller.add(settings);
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
}
