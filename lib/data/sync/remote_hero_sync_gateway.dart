import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';

/// Remote-Wrapper fuer ein synchronisiertes Heldenblatt.
class RemoteHeroRecord {
  /// Erstellt einen Remote-Datensatz fuer einen Helden oder Tombstone.
  const RemoteHeroRecord({
    required this.id,
    required this.hero,
    required this.revision,
    required this.contentHash,
    required this.isDeleted,
    required this.updatedAt,
  });

  /// Dokument-ID und Helden-ID.
  final String id;

  /// Remote-Held; `null` bei Tombstone.
  final HeroSheet? hero;

  /// Monoton wechselnde Remote-Revision.
  final String revision;

  /// Stabiler Hash des Payloads.
  final String contentHash;

  /// Ob dieser Datensatz eine geloeschte Remote-Version markiert.
  final bool isDeleted;

  /// Remote-Aenderungszeitpunkt, sofern bekannt.
  final DateTime? updatedAt;
}

/// Remote-Wrapper fuer einen synchronisierten Heldenzustand.
class RemoteHeroStateRecord {
  /// Erstellt einen Remote-Datensatz fuer einen Heldenzustand oder Tombstone.
  const RemoteHeroStateRecord({
    required this.heroId,
    required this.state,
    required this.revision,
    required this.contentHash,
    required this.isDeleted,
    required this.updatedAt,
  });

  /// ID des zugehoerigen Helden.
  final String heroId;

  /// Remote-Zustand; `null` bei Tombstone.
  final HeroState? state;

  /// Monoton wechselnde Remote-Revision.
  final String revision;

  /// Stabiler Hash des Payloads.
  final String contentHash;

  /// Ob dieser Datensatz eine geloeschte Remote-Version markiert.
  final bool isDeleted;

  /// Remote-Aenderungszeitpunkt, sofern bekannt.
  final DateTime? updatedAt;
}

/// Remote-Vertrag fuer accountgebundenen Helden- und Zustands-Sync.
abstract class RemoteHeroSyncGateway {
  /// Laedt alle Remote-Helden inklusive Tombstones.
  Future<List<RemoteHeroRecord>> loadAllHeroes();

  /// Laedt einen Remote-Helden inklusive Tombstone.
  Future<RemoteHeroRecord?> loadHero(String heroId);

  /// Speichert [hero] remote und gibt die neue Remote-Revision zurueck.
  Future<RemoteHeroRecord> saveHero(
    HeroSheet hero, {
    required String? previousRevision,
  });

  /// Markiert einen Helden remote als geloescht.
  Future<RemoteHeroRecord> deleteHero(
    String heroId, {
    required String? previousRevision,
  });

  /// Beobachtet Remote-Helden fuer Foreground-Live-Sync.
  Stream<List<RemoteHeroRecord>> watchHeroes();
}

/// Optionaler Remote-Vertrag fuer Heldenzustands-Sync.
abstract class RemoteHeroStateSyncGateway {
  /// Laedt alle Remote-Zustaende inklusive Tombstones.
  Future<List<RemoteHeroStateRecord>> loadAllHeroStates();

  /// Laedt einen Remote-Zustand inklusive Tombstone.
  Future<RemoteHeroStateRecord?> loadHeroState(String heroId);

  /// Speichert [state] remote und gibt die neue Remote-Revision zurueck.
  Future<RemoteHeroStateRecord> saveHeroState(
    String heroId,
    HeroState state, {
    required String? previousRevision,
  });

  /// Markiert einen Heldenzustand remote als geloescht.
  Future<RemoteHeroStateRecord> deleteHeroState(
    String heroId, {
    required String? previousRevision,
  });

  /// Beobachtet Remote-Zustaende fuer Foreground-Live-Sync.
  Stream<List<RemoteHeroStateRecord>> watchHeroStates();
}
