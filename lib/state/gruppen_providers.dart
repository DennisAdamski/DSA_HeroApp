import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/gruppen_snapshot_codec.dart';
import 'package:dsa_heldenverwaltung/data/hive_gruppen_repository.dart';
import 'package:dsa_heldenverwaltung/domain/gruppen_snapshot.dart';

/// Repository fuer Gruppen-Snapshots (wird beim App-Start uebersteuert).
final gruppenRepositoryProvider = Provider<HiveGruppenRepository>((ref) {
  throw UnimplementedError(
    'GruppenRepository muss beim App-Start übersteuert werden.',
  );
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
