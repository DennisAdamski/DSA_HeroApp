import 'dart:convert';

import 'package:hive_ce/hive.dart';

import 'package:dsa_heldenverwaltung/data/sync/sync_basis_store.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

/// Hive-basierte [SyncBasisStore] im Konto-Profilpfad (`sync_basis_v1`).
///
/// Liegt neben `sync_metadata_v1` und gilt wie sie je Konto. Einträge sind
/// JSON-Text, damit verschachtelte Inhalte ohne Typverlust zurückkommen.
class HiveSyncBasisStore implements SyncBasisStore {
  HiveSyncBasisStore._(this._box);

  static const String _boxName = 'sync_basis_v1';

  final Box<String> _box;

  /// Öffnet die Basisablage im angegebenen Profilpfad.
  static Future<HiveSyncBasisStore> create({
    required String storagePath,
  }) async {
    final box = await Hive.openBox<String>(_boxName, path: storagePath);
    return HiveSyncBasisStore._(box);
  }

  @override
  Future<SyncBasis?> lade(SyncObjectKey key) async {
    final roh = _box.get(key.storageKey);
    if (roh == null) {
      return null;
    }
    final gelesen = jsonDecode(roh);
    if (gelesen is! Map) {
      return null;
    }
    final revision = gelesen['revision'];
    final inhalt = gelesen['inhalt'];
    if (revision is! String || inhalt is! Map) {
      return null;
    }
    return SyncBasis(
      revision: revision,
      inhalt: inhalt.cast<String, dynamic>(),
    );
  }

  @override
  Future<void> merke(SyncObjectKey key, SyncBasis basis) async {
    await _box.put(
      key.storageKey,
      jsonEncode(<String, Object?>{
        'revision': basis.revision,
        'inhalt': basis.inhalt,
      }),
    );
  }

  @override
  Future<void> vergiss(SyncObjectKey key) async {
    await _box.delete(key.storageKey);
  }

  /// Schließt die zugrunde liegende Hive-Box.
  Future<void> close() async {
    await _box.close();
  }
}
