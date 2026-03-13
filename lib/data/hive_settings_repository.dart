import 'dart:async';

import 'package:hive/hive.dart';

import 'package:dsa_heldenverwaltung/domain/app_settings.dart';

/// Hive-basierte Persistenz fuer globale App-Einstellungen.
///
/// Speichert die Einstellungen als einzelnen Eintrag in der Box
/// `app_settings_v1` unter dem Schluessel `settings`.
class HiveSettingsRepository {
  HiveSettingsRepository._(this._box);

  static const _boxName = 'app_settings_v1';
  static const _settingsKey = 'settings';

  final Box<Map> _box;

  final StreamController<AppSettings> _controller =
      StreamController<AppSettings>.broadcast();

  /// Erstellt und initialisiert das Settings-Repository.
  static Future<HiveSettingsRepository> create({
    required String storagePath,
  }) async {
    final box = await Hive.openBox<Map>(_boxName, path: storagePath);
    return HiveSettingsRepository._(box);
  }

  /// Laedt die aktuellen Einstellungen (oder Defaults bei leerer Box).
  AppSettings load() {
    final raw = _box.get(_settingsKey);
    if (raw == null) {
      return const AppSettings();
    }
    return AppSettings.fromJson(raw.cast<String, dynamic>());
  }

  /// Speichert die Einstellungen persistent und benachrichtigt Listener.
  Future<void> save(AppSettings settings) async {
    await _box.put(_settingsKey, settings.toJson());
    _controller.add(settings);
  }

  /// Stream der Einstellungsaenderungen.
  Stream<AppSettings> watch() {
    return _controller.stream;
  }

  /// Schliesst Box und Streamcontroller.
  Future<void> close() async {
    await _controller.close();
    await _box.close();
  }
}
