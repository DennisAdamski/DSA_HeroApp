import 'package:hive/hive.dart';

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

  /// Schliesst die zugrunde liegende Hive-Box.
  Future<void> close() async {
    await _box.close();
  }
}
