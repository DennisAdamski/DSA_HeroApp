import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

/// Inhalt des zuletzt gemeinsam abgeglichenen Stands eines Sync-Objekts
/// (ARCH-06).
///
/// Die Sync-Metadaten merken sich nur Hash und Revision der Basis. Für eine
/// Dreiwege-Zusammenführung braucht es ihren Inhalt: erst damit ist zu
/// erkennen, welche Seite was geändert hat. Die Basis gilt nur zusammen mit
/// der Revision, unter der sie abgelegt wurde.
class SyncBasis {
  /// Erzeugt einen Basisstand.
  const SyncBasis({required this.revision, required this.inhalt});

  /// Online-Revision, zu der dieser Inhalt gehört.
  final String revision;

  /// `toJson()` des abgeglichenen Stands in der Darstellung dieser App.
  final Map<String, dynamic> inhalt;
}

/// Lokale Ablage der Basisstände je Sync-Objekt.
abstract interface class SyncBasisStore {
  /// Basis zu [key] oder `null`.
  Future<SyncBasis?> lade(SyncObjectKey key);

  /// Legt die Basis zu [key] ab oder ersetzt sie.
  Future<void> merke(SyncObjectKey key, SyncBasis basis);

  /// Entfernt die Basis zu [key].
  Future<void> vergiss(SyncObjectKey key);
}

/// Basisablage im Arbeitsspeicher, für Tests und ohne Heldenspeicher.
class SpeicherSyncBasisStore implements SyncBasisStore {
  final Map<String, SyncBasis> _basen = <String, SyncBasis>{};

  @override
  Future<SyncBasis?> lade(SyncObjectKey key) async => _basen[key.storageKey];

  @override
  Future<void> merke(SyncObjectKey key, SyncBasis basis) async {
    _basen[key.storageKey] = basis;
  }

  @override
  Future<void> vergiss(SyncObjectKey key) async {
    _basen.remove(key.storageKey);
  }
}
