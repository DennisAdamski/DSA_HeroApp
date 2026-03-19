import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/avatar_api_client.dart';
import 'package:dsa_heldenverwaltung/data/avatar_file_storage.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
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
