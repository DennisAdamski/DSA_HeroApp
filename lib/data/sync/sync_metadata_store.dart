import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

/// Persistenzvertrag fuer Sync-Metadaten.
abstract class SyncMetadataStore {
  /// Laedt Metadaten fuer [key] oder `null`, wenn kein Sync-Stand existiert.
  Future<SyncMetadata?> load(SyncObjectKey key);

  /// Speichert Metadaten fuer ein erfolgreich synchronisiertes Objekt.
  Future<void> save(SyncMetadata metadata);

  /// Entfernt Metadaten fuer [key].
  Future<void> delete(SyncObjectKey key);
}
