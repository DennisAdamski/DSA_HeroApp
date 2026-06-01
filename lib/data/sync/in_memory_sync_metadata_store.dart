import 'package:dsa_heldenverwaltung/data/sync/sync_metadata_store.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

/// Speicher fuer Sync-Metadaten in Tests und isolierten Szenarien.
class InMemorySyncMetadataStore implements SyncMetadataStore {
  final Map<String, SyncMetadata> _entries = <String, SyncMetadata>{};

  @override
  Future<void> delete(SyncObjectKey key) async {
    _entries.remove(key.storageKey);
  }

  @override
  Future<SyncMetadata?> load(SyncObjectKey key) async {
    return _entries[key.storageKey];
  }

  @override
  Future<void> save(SyncMetadata metadata) async {
    _entries[metadata.key.storageKey] = metadata;
  }
}
