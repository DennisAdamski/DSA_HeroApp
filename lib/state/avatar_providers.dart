import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/avatar_api_client.dart';
import 'package:dsa_heldenverwaltung/data/avatar_file_storage.dart';
import 'package:dsa_heldenverwaltung/rules/derived/avatar_snapshot_diff.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

/// Aktiver Avatar-API-Client (null wenn kein Key konfiguriert).
final avatarApiClientProvider = Provider<AvatarApiClient?>((ref) {
  final settings = ref.watch(appSettingsProvider).valueOrNull;
  if (settings == null) return null;
  final config = settings.avatarApiConfig;
  if (!config.isConfigured) return null;
  return createAvatarApiClient(config);
});

/// Schnellzugriff: Ist ein API-Key konfiguriert?
final avatarApiConfiguredProvider = Provider<bool>((ref) {
  return ref.watch(avatarApiClientProvider) != null;
});

/// Geschaetzte Kosten der Generierung in USD.
final avatarEstimatedCostProvider = Provider<double?>((ref) {
  return ref.watch(avatarApiClientProvider)?.estimatedCostUsd;
});

/// Avatar-Dateispeicherung.
final avatarFileStorageProvider = Provider<AvatarFileStorage>((ref) {
  return const AvatarFileStorage();
});

/// Ob der aktive Provider Referenzbild-basierte Generierung unterstuetzt.
final avatarSupportsReferenceProvider = Provider<bool>((ref) {
  return ref.watch(avatarApiClientProvider)?.supportsReferenceImage ?? false;
});

/// Laedt die PNG-Bytes des Primaerbilds eines Helden.
final primaerbildBytesProvider =
    FutureProvider.family<List<int>?, String>((ref, heroId) async {
  final hero = ref.watch(heroByIdProvider(heroId));
  if (hero == null) return null;

  final primaerbildId = hero.appearance.primaerbildId;
  if (primaerbildId.isEmpty) return null;

  final entry = hero.appearance.avatarGallery
      .where((e) => e.id == primaerbildId)
      .firstOrNull;
  if (entry == null) return null;

  final location = await ref.read(heroStorageLocationProvider.future);
  final storage = ref.read(avatarFileStorageProvider);
  return storage.loadGalleryImageBytes(
    heroStoragePath: location.effectivePath,
    fileName: entry.fileName,
  );
});

/// Berechnet den Snapshot-Diff zwischen Primaerbild-Snapshot und aktuellem Held.
final avatarSnapshotDiffProvider =
    Provider.family<AvatarSnapshotDiff?, String>((ref, heroId) {
  final hero = ref.watch(heroByIdProvider(heroId));
  if (hero == null) return null;

  final snapshot = hero.appearance.avatarSnapshot;
  if (snapshot == null) return null;

  return computeAvatarSnapshotDiff(snapshot, hero);
});
