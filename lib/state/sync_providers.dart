import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/sync_controller.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
export 'package:dsa_heldenverwaltung/domain/sync_controller.dart';

/// Aktiver Konto-Sync-Controller; `null` im reinen Offline-Modus.
final syncControllerProvider = Provider<AppSyncController?>((ref) {
  return null;
});

/// Reaktiver Snapshot fuer Konto-, Sync- und Konfliktstatus.
final syncStatusProvider = StreamProvider<SyncStatusSnapshot>((ref) {
  final controller = ref.watch(syncControllerProvider);
  if (controller == null) {
    return Stream<SyncStatusSnapshot>.value(const SyncStatusSnapshot());
  }
  return controller.watchStatus();
});
