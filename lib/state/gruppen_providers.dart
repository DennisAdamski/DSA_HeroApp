import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/gruppen_snapshot_codec.dart';
import 'package:dsa_heldenverwaltung/data/gruppen_sync_service.dart';
import 'package:dsa_heldenverwaltung/data/hive_externe_helden_repository.dart';
import 'package:dsa_heldenverwaltung/data/hive_gruppen_repository.dart';
import 'package:dsa_heldenverwaltung/domain/externer_held.dart';
import 'package:dsa_heldenverwaltung/domain/gruppen_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

/// Repository fuer Gruppen-Snapshots (wird beim App-Start uebersteuert).
final gruppenRepositoryProvider = Provider<HiveGruppenRepository>((ref) {
  throw UnimplementedError(
    'GruppenRepository muss beim App-Start übersteuert werden.',
  );
});

/// Repository fuer externe Helden (wird beim App-Start uebersteuert).
final externeHeldenRepositoryProvider =
    Provider<HiveExterneHeldenRepository>((ref) {
  throw UnimplementedError(
    'ExterneHeldenRepository muss beim App-Start übersteuert werden.',
  );
});

/// Firebase-Sync-Service fuer Heldengruppen.
final gruppenSyncServiceProvider = Provider<GruppenSyncService>((ref) {
  return GruppenSyncService();
});

/// Codec fuer Gruppen-Snapshot-JSON.
final gruppenSnapshotCodecProvider = Provider<GruppenSnapshotCodec>((ref) {
  return const GruppenSnapshotCodec();
});

/// Reaktiver Stream des aktiven Gruppen-Snapshots (nullable).
final gruppenSnapshotProvider = StreamProvider<GruppenSnapshot?>((ref) {
  final repo = ref.watch(gruppenRepositoryProvider);
  return repo.watchGruppe();
});

/// Reaktiver Stream aller externen Helden.
final externeHeldenProvider =
    StreamProvider<Map<String, ExternerHeld>>((ref) {
  final repo = ref.watch(externeHeldenRepositoryProvider);
  return repo.watchAll();
});

/// Externer Held per ID.
final externerHeldByIdProvider =
    Provider.family<ExternerHeld?, String>((ref, id) {
  final all = ref.watch(externeHeldenProvider).valueOrNull ??
      const <String, ExternerHeld>{};
  return all[id];
});

/// Alle externen Helden einer bestimmten Gruppe eines Helden.
final gruppenMitgliederProvider = Provider.family<List<ExternerHeld>,
    ({String heroId, String gruppenCode})>((ref, params) {
  final hero = ref.watch(heroByIdProvider(params.heroId));
  if (hero == null) return const <ExternerHeld>[];

  final mitgliedschaft = hero.gruppen
      .where((g) => g.gruppenCode == params.gruppenCode)
      .firstOrNull;
  if (mitgliedschaft == null) return const <ExternerHeld>[];

  final allExterne = ref.watch(externeHeldenProvider).valueOrNull ??
      const <String, ExternerHeld>{};
  return mitgliedschaft.externeHeldIds
      .map((id) => allExterne[id])
      .whereType<ExternerHeld>()
      .toList(growable: false);
});
