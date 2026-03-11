import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';

/// Settings-Repository (wird beim App-Start uebersteuert).
final settingsRepositoryProvider = Provider<HiveSettingsRepository>((ref) {
  throw UnimplementedError(
    'HiveSettingsRepository muss beim App-Start uebersteuert werden.',
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
}

/// Provider fuer Einstellungs-Schreiboperationen.
final settingsActionsProvider = Provider<SettingsActions>((ref) {
  return SettingsActions(ref.watch(settingsRepositoryProvider));
});
