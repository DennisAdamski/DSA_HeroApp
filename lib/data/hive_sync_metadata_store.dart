import 'package:hive_ce/hive.dart';

import 'package:dsa_heldenverwaltung/data/sync/sync_metadata_store.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

/// Hive-basierter Speicher fuer Sync-Metadaten eines lokalen Profils.
class HiveSyncMetadataStore implements SyncMetadataStore {
  HiveSyncMetadataStore._(this._box);

  static const String _boxName = 'sync_metadata_v1';

  final Box<Map> _box;

  /// Oeffnet die Metadaten-Box im angegebenen Profilpfad.
  static Future<HiveSyncMetadataStore> create({
    required String storagePath,
  }) async {
    final box = await Hive.openBox<Map>(_boxName, path: storagePath);
    return HiveSyncMetadataStore._(box);
  }

  @override
  Future<void> delete(SyncObjectKey key) async {
    await _box.delete(key.storageKey);
  }

  @override
  Future<SyncMetadata?> load(SyncObjectKey key) async {
    final raw = _box.get(key.storageKey);
    if (raw == null) {
      return null;
    }
    return SyncMetadata.fromJson(raw.cast<String, dynamic>());
  }

  @override
  Future<void> save(SyncMetadata metadata) async {
    await _box.put(metadata.key.storageKey, metadata.toJson());
  }

  /// IDs aller Helden, zu denen ein Sync-Stand vorliegt.
  ///
  /// Wer hier steht, wurde mit dem Konto abgeglichen und liegt damit auch
  /// online. Unlesbare Schluessel werden uebersprungen.
  Future<Set<String>> heldenIds() async {
    final ids = <String>{};
    for (final raw in _box.keys) {
      try {
        final key = SyncObjectKey.parse(raw.toString());
        if (key.type == SyncObjectType.hero) {
          ids.add(key.id);
        }
      } on FormatException {
        continue;
      }
    }
    return ids;
  }

  /// Schliesst die zugrunde liegende Hive-Box.
  Future<void> close() async {
    await _box.close();
  }
}
