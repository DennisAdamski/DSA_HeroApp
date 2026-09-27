import 'dart:convert';

import 'package:dsa_heldenverwaltung/data/sync/remote_hero_sync_gateway.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

/// In-Memory-Cloud fuer Helden-Sync-Tests.
///
/// Vergibt fortlaufende Revisionen und bildet den Precondition-Kontrakt der
/// echten Gateways nach; Zeitstempel sind deterministisch.
class FakeRemoteHeroSyncGateway implements RemoteHeroSyncGateway {
  final Map<String, RemoteHeroRecord> _heroes = <String, RemoteHeroRecord>{};
  int _revisionCounter = 0;

  @override
  Future<List<RemoteHeroRecord>> loadAllHeroes() async {
    return _heroes.values.toList(growable: false);
  }

  @override
  Future<RemoteHeroRecord?> loadHero(String heroId) async {
    return _heroes[heroId];
  }

  @override
  Future<RemoteHeroRecord> saveHero(
    HeroSheet hero, {
    required String? previousRevision,
  }) async {
    _enforcePreviousRevision(hero.id, previousRevision);
    final revision = 'r-${++_revisionCounter}';
    final record = RemoteHeroRecord(
      id: hero.id,
      hero: hero,
      revision: revision,
      // Wie die echten Gateways: Inhalt ohne `lastModified`.
      contentHash: heroContentHash(hero),
      isDeleted: false,
      updatedAt: DateTime.utc(2026, 1, 1, 12, _revisionCounter),
    );
    _heroes[hero.id] = record;
    return record;
  }

  /// Legt einen Helden ab, wie ihn eine **andere App-Version** schreibt.
  ///
  /// Firestore liefert den Inhalts-Hash des Schreibers mit. Er ist hier wie
  /// dort ueber das rohe JSON ohne `lastModified` gerechnet, der Held selbst
  /// entsteht aber mit dem `fromJson` dieser App. Kann sie den Stand nicht
  /// verlustfrei darstellen, weichen beide Hashes voneinander ab — genau
  /// diesen Fall braucht ein Test fuer Befund ARCH-07-B10.
  Future<RemoteHeroRecord> speichereFremdenStand(
    Map<String, dynamic> heldJson, {
    required String? previousRevision,
  }) async {
    final hero = HeroSheet.fromJson(_jsonKopie(heldJson));
    _enforcePreviousRevision(hero.id, previousRevision);
    final revision = 'r-${++_revisionCounter}';
    final record = RemoteHeroRecord(
      id: hero.id,
      hero: hero,
      revision: revision,
      contentHash: _schreiberHash(heldJson),
      isDeleted: false,
      updatedAt: DateTime.utc(2026, 1, 1, 12, _revisionCounter),
    );
    _heroes[hero.id] = record;
    return record;
  }

  @override
  Future<RemoteHeroRecord> deleteHero(
    String heroId, {
    required String? previousRevision,
  }) async {
    _enforcePreviousRevision(heroId, previousRevision);
    final revision = 'r-${++_revisionCounter}';
    final record = RemoteHeroRecord(
      id: heroId,
      hero: null,
      revision: revision,
      contentHash: '',
      isDeleted: true,
      updatedAt: DateTime.utc(2026, 1, 1, 12, _revisionCounter),
    );
    _heroes[heroId] = record;
    return record;
  }

  @override
  Stream<List<RemoteHeroRecord>> watchHeroes() {
    return const Stream<List<RemoteHeroRecord>>.empty();
  }

  /// Modelliert den serverseitigen Precondition-Kontrakt der echten Gateways.
  void _enforcePreviousRevision(String heroId, String? previousRevision) {
    if (previousRevision == null) {
      return;
    }
    final current = _heroes[heroId]?.revision;
    if (current != previousRevision) {
      throw SyncPreconditionException(
        'Revision von $heroId hat sich geändert.',
        expectedRevision: previousRevision,
        actualRevision: current,
      );
    }
  }
}

/// Wie [FakeRemoteHeroSyncGateway], zusaetzlich mit Zustandsdokumenten.
class FakeRemoteHeroAndStateSyncGateway extends FakeRemoteHeroSyncGateway
    implements RemoteHeroStateSyncGateway {
  final Map<String, RemoteHeroStateRecord> _states =
      <String, RemoteHeroStateRecord>{};
  int _stateRevisionCounter = 0;

  @override
  Future<List<RemoteHeroStateRecord>> loadAllHeroStates() async {
    return _states.values.toList(growable: false);
  }

  @override
  Future<RemoteHeroStateRecord?> loadHeroState(String heroId) async {
    return _states[heroId];
  }

  @override
  Future<RemoteHeroStateRecord> saveHeroState(
    String heroId,
    HeroState state, {
    required String? previousRevision,
  }) async {
    _enforcePreviousStateRevision(heroId, previousRevision);
    final revision = 's-${++_stateRevisionCounter}';
    final record = RemoteHeroStateRecord(
      heroId: heroId,
      state: state,
      revision: revision,
      contentHash: heroStateContentHash(state),
      isDeleted: false,
      updatedAt: DateTime.utc(2026, 1, 2, 12, _stateRevisionCounter),
    );
    _states[heroId] = record;
    return record;
  }

  /// Wie [speichereFremdenStand] fuer ein Zustandsdokument.
  Future<RemoteHeroStateRecord> speichereFremdenZustand(
    String heroId,
    Map<String, dynamic> zustandJson, {
    required String? previousRevision,
  }) async {
    _enforcePreviousStateRevision(heroId, previousRevision);
    final revision = 's-${++_stateRevisionCounter}';
    final record = RemoteHeroStateRecord(
      heroId: heroId,
      state: HeroState.fromJson(_jsonKopie(zustandJson)),
      revision: revision,
      contentHash: _schreiberHash(zustandJson),
      isDeleted: false,
      updatedAt: DateTime.utc(2026, 1, 2, 12, _stateRevisionCounter),
    );
    _states[heroId] = record;
    return record;
  }

  @override
  Future<RemoteHeroStateRecord> deleteHeroState(
    String heroId, {
    required String? previousRevision,
  }) async {
    _enforcePreviousStateRevision(heroId, previousRevision);
    final revision = 's-${++_stateRevisionCounter}';
    final record = RemoteHeroStateRecord(
      heroId: heroId,
      state: null,
      revision: revision,
      contentHash: '',
      isDeleted: true,
      updatedAt: DateTime.utc(2026, 1, 2, 12, _stateRevisionCounter),
    );
    _states[heroId] = record;
    return record;
  }

  @override
  Stream<List<RemoteHeroStateRecord>> watchHeroStates() {
    return const Stream<List<RemoteHeroStateRecord>>.empty();
  }

  /// Precondition-Kontrakt fuer Zustandsdokumente, wie bei den Helden.
  void _enforcePreviousStateRevision(String heroId, String? previousRevision) {
    if (previousRevision == null) {
      return;
    }
    final current = _states[heroId]?.revision;
    if (current != previousRevision) {
      throw SyncPreconditionException(
        'Zustandsrevision von $heroId hat sich geändert.',
        expectedRevision: previousRevision,
        actualRevision: current,
      );
    }
  }
}

// Tiefe Kopie ueber JSON, damit der Aufrufer die Vorlage weiterverwenden kann.
Map<String, dynamic> _jsonKopie(Map<String, dynamic> json) {
  return jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
}

// Inhalts-Hash, wie ihn der Schreiber ueber sein rohes JSON rechnet.
String _schreiberHash(Map<String, dynamic> json) {
  return stableContentHash(_jsonKopie(json)..remove('lastModified'));
}
