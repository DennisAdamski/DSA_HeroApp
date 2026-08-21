import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/avatar_api_client.dart';
import 'package:dsa_heldenverwaltung/data/avatar_backfill_service.dart';
import 'package:dsa_heldenverwaltung/data/avatar_file_storage.dart';
import 'package:dsa_heldenverwaltung/data/avatar_thumbnail_encoder.dart';
import 'package:dsa_heldenverwaltung/data/cloud_avatar_storage.dart';
import 'package:dsa_heldenverwaltung/data/syncing_avatar_storage.dart';
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
///
/// Auf Plattformen mit lokalem Dateisystem wird die Ablage in
/// [SyncingAvatarStorage] gewickelt, damit Bilder zusaetzlich in der Cloud
/// landen und von dort nachgeladen werden koennen. Im Web ist die
/// Plattformimplementierung bereits der Cloud-Speicher.
final avatarFileStorageProvider = Provider<AvatarFileStorage>((ref) {
  final platform = createAvatarFileStorage();
  if (platform.isCloudBacked) {
    return platform;
  }
  return SyncingAvatarStorage(
    local: platform,
    cloud: ref.watch(cloudAvatarStorageProvider),
  );
});

/// Erzeugt kompakte PNG-Thumbnails fuer Gruppen-Sync und -Export.
final avatarThumbnailEncoderProvider = Provider<AvatarThumbnailEncoder>((ref) {
  return const AvatarThumbnailEncoder();
});

/// Ergebnis des letzten Avatar-Backfills, oder `null` wenn keiner lief.
///
/// Wird von `AppStartupGate` per Override befuellt. Ohne diese Anzeige ist im
/// Release-Build nicht feststellbar, ob der Abgleich lief — genau die Frage,
/// die beim leeren Web-Album aufkam.
final avatarBackfillReportProvider = Provider<AvatarBackfillReport?>((ref) {
  return null;
});

/// Cloud-Speicher fuer Avatarbilder.
final cloudAvatarStorageProvider = Provider<CloudAvatarStorage>((ref) {
  return const FirebaseCloudAvatarStorage();
});

/// Anzahl der KI-generierten Bilder eines bestimmten Helden.
final kiImageCountProvider = Provider.family<int, String>((ref, heroId) {
  final hero = ref.watch(heroByIdProvider(heroId));
  if (hero == null) return 0;
  return hero.appearance.avatarGallery.where((e) => e.quelle == 'ki').length;
});

/// Aktuelle Anzahl der Helden des Nutzers.
final heroCountProvider = Provider<int>((ref) {
  final snapshot = ref.watch(heroIndexProvider).valueOrNull;
  return snapshot?.sortedIds.length ?? 0;
});

/// Ob der aktive Provider Referenzbild-basierte Generierung unterstuetzt.
final avatarSupportsReferenceProvider = Provider<bool>((ref) {
  return ref.watch(avatarApiClientProvider)?.supportsReferenceImage ?? false;
});

/// Laedt die PNG-Bytes einer einzelnen Avatar-Datei.
///
/// Bewusst `Uint8List` statt `List<int>`: `MemoryImage` vergleicht seine Bytes
/// per Identitaet. Wer die Instanz aus diesem Provider unveraendert an
/// `Image.memory` weiterreicht, trifft den globalen `ImageCache`; ein
/// `Uint8List.fromList(...)` im Widget wuerde ihn bei jedem Rebuild verfehlen
/// und das PNG neu dekodieren.
///
/// Liefert `null` statt zu werfen, damit fehlende Bilder im Platzhalter
/// landen.
final avatarBytesProvider =
    FutureProvider.family<Uint8List?, ({String heroId, String fileName})>((
      ref,
      args,
    ) async {
      if (args.fileName.isEmpty) return null;
      final location = await ref.watch(heroStorageLocationProvider.future);
      final storage = ref.watch(avatarFileStorageProvider);
      return storage.loadGalleryImageBytes(
        heroStoragePath: location.effectivePath,
        fileName: args.fileName,
      );
    });

/// Laedt die PNG-Bytes des Primaerbilds eines Helden.
final primaerbildBytesProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  heroId,
) async {
  final hero = ref.watch(heroByIdProvider(heroId));
  if (hero == null) return null;

  final primaerbildId = hero.appearance.primaerbildId;
  if (primaerbildId.isEmpty) return null;

  final entry = hero.appearance.avatarGallery
      .where((e) => e.id == primaerbildId)
      .firstOrNull;
  if (entry == null) return null;

  return ref.watch(
    avatarBytesProvider((heroId: heroId, fileName: entry.fileName)).future,
  );
});

/// Laedt die PNG-Bytes des aktiv angezeigten Bildes (Header + Uebersicht).
///
/// Die Fallback-Kette steckt in `HeroAppearance.aktivesBild`.
final activeAvatarBytesProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  heroId,
) async {
  final hero = ref.watch(heroByIdProvider(heroId));
  final entry = hero?.appearance.aktivesBild;
  if (entry == null) return null;

  return ref.watch(
    avatarBytesProvider((heroId: heroId, fileName: entry.fileName)).future,
  );
});

/// Berechnet den Snapshot-Diff zwischen Primaerbild-Snapshot und aktuellem Held.
final avatarSnapshotDiffProvider = Provider.family<AvatarSnapshotDiff?, String>(
  (ref, heroId) {
    final hero = ref.watch(heroByIdProvider(heroId));
    if (hero == null) return null;

    final snapshot = hero.appearance.avatarSnapshot;
    if (snapshot == null) return null;

    return computeAvatarSnapshotDiff(snapshot, hero);
  },
);
