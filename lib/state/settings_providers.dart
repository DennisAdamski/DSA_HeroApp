import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/data/storage_directory_picker.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_config.dart' show AvatarApiConfig;
export 'package:dsa_heldenverwaltung/domain/app_settings.dart' show UiVariante;
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';

/// Settings-Repository (wird beim App-Start uebersteuert).
final settingsRepositoryProvider = Provider<HiveSettingsRepository>((ref) {
  throw UnimplementedError(
    'HiveSettingsRepository muss beim App-Start uebersteuert werden.',
  );
});

/// Zentrale Pfadlogik fuer Einstellungen und Heldendaten.
final appStoragePathsProvider = Provider<AppStoragePaths>((ref) {
  return const AppStoragePaths();
});

/// Native Ordnerauswahl fuer den Heldenspeicher.
final storageDirectoryPickerProvider = Provider<StorageDirectoryPicker>((ref) {
  throw UnimplementedError(
    'StorageDirectoryPicker muss beim App-Start uebersteuert werden.',
  );
});

/// Reaktiver Stream der aktuellen App-Einstellungen.
final appSettingsProvider = StreamProvider<AppSettings>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return Stream.value(repo.load()).asyncExpand((initial) async* {
    yield initial;
    yield* repo.watch();
  });
});

/// Schnellzugriff auf den Debug-Modus-Zustand.
final debugModusProvider = Provider<bool>((ref) {
  return ref.watch(appSettingsProvider).valueOrNull?.debugModus ?? false;
});

/// Schnellzugriff auf den Dunkelmodus-Zustand.
final dunkelModusProvider = Provider<bool>((ref) {
  return ref.watch(appSettingsProvider).valueOrNull?.dunkelModus ?? false;
});

/// Schnellzugriff auf die aktive UI-Variante.
final uiVarianteProvider = Provider<UiVariante>((ref) {
  return ref.watch(appSettingsProvider).valueOrNull?.uiVariante
      ?? UiVariante.codex;
});

/// Ob die Kernwerte-Rail im Workspace zugeklappt ist.
final summaryRailCollapsedProvider = Provider<bool>((ref) {
  return ref.watch(appSettingsProvider).valueOrNull?.summaryRailCollapsed
      ?? false;
});

/// true wenn ein gueltiges Entschluesselungspasswort gespeichert ist.
/// Damit sind geschuetzte Kataloginhalte dauerhaft freigeschaltet.
final catalogContentVisibleProvider = Provider<bool>((ref) {
  final pw = ref.watch(appSettingsProvider).valueOrNull?.catalogContentPassword;
  return pw != null && pw.isNotEmpty;
});

/// Aktuelle Beschreibung des wirksamen Heldenspeicherorts.
final heroStorageLocationProvider = FutureProvider<HeroStorageLocation>((ref) {
  final storagePaths = ref.watch(appStoragePathsProvider);
  final configuredPath = ref.watch(appSettingsProvider).valueOrNull?.heroStoragePath;
  return storagePaths.describeHeroStorageLocation(
    configuredPath: configuredPath,
  );
});

/// Lokaler Speicherort fuer App-Einstellungen.
final settingsStoragePathProvider = FutureProvider<String>((ref) {
  return ref.watch(appStoragePathsProvider).resolveSettingsStoragePath();
});

/// Schreiboperationen fuer App-Einstellungen.
class SettingsActions {
  SettingsActions(this._repo);

  final HiveSettingsRepository _repo;

  /// Schaltet den Debug-Modus um.
  Future<void> toggleDebugModus() async {
    final current = _repo.load();
    await _repo.save(current.copyWith(debugModus: !current.debugModus));
  }

  /// Schaltet den Dunkelmodus um.
  Future<void> toggleDunkelModus() async {
    final current = _repo.load();
    await _repo.save(current.copyWith(dunkelModus: !current.dunkelModus));
  }

  /// Speichert einen benutzerdefinierten Heldenspeicherpfad.
  Future<void> setHeroStoragePath(String path) async {
    final normalizedPath = path.trim();
    final current = _repo.load();
    await _repo.save(
      current.copyWith(
        heroStoragePath: normalizedPath.isEmpty ? null : normalizedPath,
      ),
    );
  }

  /// Entfernt den benutzerdefinierten Heldenspeicherpfad.
  Future<void> clearHeroStoragePath() async {
    final current = _repo.load();
    await _repo.save(current.copyWith(heroStoragePath: null));
  }

  /// Setzt die visuelle Darstellungsvariante.
  Future<void> setUiVariante(UiVariante variante) async {
    final current = _repo.load();
    await _repo.save(current.copyWith(uiVariante: variante));
  }

  /// Speichert die Avatar-API-Konfiguration.
  Future<void> saveAvatarApiConfig(AvatarApiConfig config) async {
    final current = _repo.load();
    await _repo.save(current.copyWith(avatarApiConfig: config));
  }

  /// Setzt oder entfernt das Katalog-Inhaltspasswort.
  Future<void> setCatalogContentPassword(String? password) async {
    final current = _repo.load();
    final trimmed = password?.trim();
    await _repo.save(
      current.copyWith(
        catalogContentPassword:
            (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      ),
    );
  }

  /// Schaltet den Collapse-Zustand der Kernwerte-Rail um.
  Future<void> toggleSummaryRailCollapsed() async {
    final current = _repo.load();
    await _repo.save(
      current.copyWith(summaryRailCollapsed: !current.summaryRailCollapsed),
    );
  }
}

/// Provider fuer Einstellungs-Schreiboperationen.
final settingsActionsProvider = Provider<SettingsActions>((ref) {
  return SettingsActions(ref.watch(settingsRepositoryProvider));
});
