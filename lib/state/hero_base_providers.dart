import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/hero_transfer_codec.dart';
import 'package:dsa_heldenverwaltung/data/hero_transfer_file_gateway.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

/// Repository-Abstraktion (wird beim App-Start ueberschrieben).
///
/// Wirft [UnimplementedError] wenn nicht beim Start uebersteuert.
final heroRepositoryProvider = Provider<HeroRepository>((ref) {
  throw UnimplementedError(
    'HeroRepository muss beim App-Start uebersteuert werden.',
  );
});

/// Codec fuer Transfer-JSON (Import/Export).
final heroTransferCodecProvider = Provider<HeroTransferCodec>((ref) {
  return const HeroTransferCodec();
});

/// Plattformabhaengiger Dateigateway fuer Transferdateien.
final heroTransferFileGatewayProvider = Provider<HeroTransferFileGateway>((
  ref,
) {
  return createHeroTransferFileGateway();
});

/// ID des aktuell in der Heldenliste ausgewaehlten Helden (oder `null`).
///
/// Initialisiert sich wenn moeglich aus der zuletzt gespeicherten Auswahl.
final selectedHeroIdProvider = StateProvider<String?>((ref) {
  try {
    final settingsRepository = ref.read(settingsRepositoryProvider);
    return settingsRepository.load().lastSelectedHeroId;
  } catch (error) {
    if (!_isMissingSettingsRepository(error)) {
      rethrow;
    }
    return null;
  }
});

/// Koordiniert UI-Auswahl und persistierte Startseiten-Selektion.
class SelectedHeroSelectionActions {
  /// Erstellt die Schreib-API fuer die Heldenauswahl.
  SelectedHeroSelectionActions(this._ref);

  final Ref _ref;

  /// Merkt sich [heroId] als aktuelle Heldenauswahl.
  ///
  /// Die Auswahl wird sofort lokal aktualisiert und, falls verfuegbar,
  /// parallel in den App-Einstellungen gespeichert.
  Future<void> selectHero(String? heroId) async {
    final normalizedHeroId = _normalizeHeroId(heroId);
    _ref.read(selectedHeroIdProvider.notifier).state = normalizedHeroId;
    await _persistSelectedHeroId(normalizedHeroId);
  }

  /// Entfernt die aktuelle Heldenauswahl lokal und persistent.
  Future<void> clearSelection() async {
    await selectHero(null);
  }

  String? _normalizeHeroId(String? heroId) {
    final trimmed = heroId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Future<void> _persistSelectedHeroId(String? heroId) async {
    try {
      final settingsRepository = _ref.read(settingsRepositoryProvider);
      final currentSettings = settingsRepository.load();
      if (currentSettings.lastSelectedHeroId == heroId) {
        return;
      }
      await settingsRepository.save(
        currentSettings.copyWith(lastSelectedHeroId: heroId),
      );
    } catch (error) {
      if (!_isMissingSettingsRepository(error)) {
        rethrow;
      }
      // Tests und isolierte Provider-Szenarien duerfen ohne Settings laufen.
    }
  }
}

/// Schreiboperationen fuer die persistierte Heldenauswahl.
final selectedHeroSelectionActionsProvider =
    Provider<SelectedHeroSelectionActions>((ref) {
      return SelectedHeroSelectionActions(ref);
    });

bool _isMissingSettingsRepository(Object error) {
  return error is UnimplementedError ||
      error.toString().contains(
        'HiveSettingsRepository muss beim App-Start uebersteuert werden.',
      );
}
