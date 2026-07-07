import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/sync/in_memory_sync_metadata_store.dart';
import 'package:dsa_heldenverwaltung/data/sync/remote_hero_sync_gateway.dart';
import 'package:dsa_heldenverwaltung/data/syncing_hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/sync_object_diff.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

void main() {
  HeroSheet hero(String id, String name) {
    return HeroSheet(
      id: id,
      name: name,
      level: 1,
      attributes: const Attributes(
        mu: 8,
        kl: 8,
        inn: 8,
        ch: 8,
        ff: 8,
        ge: 8,
        ko: 8,
        kk: 8,
      ),
    );
  }

  group('SyncingHeroRepository', () {
    test('pulls remote heroes when local cache is empty', () async {
      final local = FakeRepository.empty();
      final remote = FakeRemoteHeroSyncGateway();
      final metadata = InMemorySyncMetadataStore();
      final remoteHero = hero('h-1', 'Remote Alrik');
      await remote.saveHero(remoteHero, previousRevision: null);

      final repository = SyncingHeroRepository(
        local: local,
        remote: remote,
        metadataStore: metadata,
        accountId: 'user-1',
        startRemoteListener: false,
      );

      await repository.syncNow();

      expect((await local.loadHeroById('h-1'))?.name, 'Remote Alrik');
      final storedMetadata = await metadata.load(
        const SyncObjectKey(type: SyncObjectType.hero, id: 'h-1'),
      );
      expect(storedMetadata?.remoteRevision, isNotEmpty);
    });

    test(
      'keeps local save local and opens conflict when remote changed',
      () async {
        final local = FakeRepository.empty();
        final remote = FakeRemoteHeroSyncGateway();
        final metadata = InMemorySyncMetadataStore();
        final baseHero = hero('h-1', 'Alrik');
        await remote.saveHero(baseHero, previousRevision: null);

        final repository = SyncingHeroRepository(
          local: local,
          remote: remote,
          metadataStore: metadata,
          accountId: 'user-1',
          startRemoteListener: false,
        );
        await repository.syncNow();

        await remote.saveHero(
          hero('h-1', 'Remote Alrik'),
          previousRevision: null,
        );
        await repository.saveHero(hero('h-1', 'Lokaler Alrik'));

        expect((await local.loadHeroById('h-1'))?.name, 'Lokaler Alrik');
        expect((await remote.loadHero('h-1'))?.hero?.name, 'Remote Alrik');
        expect(repository.currentStatus.openConflicts, hasLength(1));
        expect(repository.currentStatus.openConflicts.single.objectId, 'h-1');
      },
    );

    test(
      'resolving a hero conflict with keepBoth preserves both versions',
      () async {
        final local = FakeRepository.empty();
        final remote = FakeRemoteHeroSyncGateway();
        final metadata = InMemorySyncMetadataStore();
        await remote.saveHero(
          hero('h-1', 'Alrik remote'),
          previousRevision: null,
        );

        final repository = SyncingHeroRepository(
          local: local,
          remote: remote,
          metadataStore: metadata,
          accountId: 'user-1',
          startRemoteListener: false,
        );
        await repository.syncNow();

        await remote.saveHero(
          hero('h-1', 'Alrik online'),
          previousRevision: null,
        );
        await repository.saveHero(hero('h-1', 'Alrik lokal'));
        final conflictId = repository.currentStatus.openConflicts.single.id;

        await repository.resolveConflict(
          conflictId,
          SyncResolutionChoice.keepBoth,
        );

        final localHeroes = await local.listHeroes();
        final remoteHeroes = await remote.loadAllHeroes();
        expect(localHeroes.map((item) => item.name), contains('Alrik online'));
        expect(
          localHeroes.any((item) => item.name.startsWith('Alrik lokal')),
          isTrue,
        );
        expect(remoteHeroes, hasLength(2));
        expect(repository.currentStatus.openConflicts, isEmpty);
      },
    );

    test('queues offline profile heroes as account merge conflicts', () async {
      final local = FakeRepository(heroes: <HeroSheet>[hero('h-1', 'Online')]);
      final remote = FakeRemoteHeroSyncGateway();
      final metadata = InMemorySyncMetadataStore();
      final repository = SyncingHeroRepository(
        local: local,
        remote: remote,
        metadataStore: metadata,
        accountId: 'user-1',
        startRemoteListener: false,
      );

      await repository.queueOfflineProfileConflicts(
        offlineHeroes: <HeroSheet>[hero('offline-1', 'Offline Alrik')],
      );

      expect(repository.currentStatus.openConflicts, hasLength(1));
      expect(
        repository.currentStatus.openConflicts.single.localSummary,
        'Offline Alrik',
      );
    });

    test('skips offline profile heroes identical to the account version', () async {
      final local = FakeRepository(
        heroes: <HeroSheet>[hero('h-1', 'Alrik'), hero('h-2', 'Konto Layariel')],
      );
      final remote = FakeRemoteHeroSyncGateway();
      final metadata = InMemorySyncMetadataStore();
      final repository = SyncingHeroRepository(
        local: local,
        remote: remote,
        metadataStore: metadata,
        accountId: 'user-1',
        startRemoteListener: false,
      );

      await repository.queueOfflineProfileConflicts(
        offlineHeroes: <HeroSheet>[
          // Identisch zur Konto-Version: darf keinen Konflikt erzeugen.
          hero('h-1', 'Alrik'),
          // Abweichender Name: Konflikt bleibt noetig.
          hero('h-2', 'Offline Layariel'),
        ],
      );

      expect(repository.currentStatus.openConflicts, hasLength(1));
      expect(repository.currentStatus.openConflicts.single.objectId, 'h-2');
    });

    test('conflictDiff liefert Feldunterschiede fuer Heldenkonflikte', () async {
      final local = FakeRepository.empty();
      final remote = FakeRemoteHeroSyncGateway();
      final metadata = InMemorySyncMetadataStore();
      await remote.saveHero(hero('h-1', 'Alrik'), previousRevision: null);

      final repository = SyncingHeroRepository(
        local: local,
        remote: remote,
        metadataStore: metadata,
        accountId: 'user-1',
        startRemoteListener: false,
      );
      await repository.syncNow();

      await remote.saveHero(
        hero('h-1', 'Alrik online'),
        previousRevision: null,
      );
      await repository.saveHero(hero('h-1', 'Alrik lokal'));
      final conflictId = repository.currentStatus.openConflicts.single.id;

      final diff = repository.conflictDiff(conflictId);

      expect(diff, isNotNull);
      expect(diff!.remoteMissing, isFalse);
      final nameEntry = diff.entries.singleWhere(
        (entry) => entry.path.join('.') == 'name',
      );
      expect(nameEntry.kind, SyncDiffKind.changed);
      expect(nameEntry.localValue, 'Alrik lokal');
      expect(nameEntry.remoteValue, 'Alrik online');

      expect(repository.conflictDiff('unbekannt'), isNull);

      await repository.resolveConflict(
        conflictId,
        SyncResolutionChoice.keepLocal,
      );
      expect(repository.conflictDiff(conflictId), isNull);
    });

    test('conflictDiff markiert geloeschte Online-Version', () async {
      final local = FakeRepository.empty();
      final remote = FakeRemoteHeroSyncGateway();
      final metadata = InMemorySyncMetadataStore();
      await remote.saveHero(hero('h-1', 'Alrik'), previousRevision: null);

      final repository = SyncingHeroRepository(
        local: local,
        remote: remote,
        metadataStore: metadata,
        accountId: 'user-1',
        startRemoteListener: false,
      );
      await repository.syncNow();

      // Lokale Aenderung am Repository vorbei, damit nichts gepusht wird.
      await local.saveHero(hero('h-1', 'Alrik lokal'));
      await remote.deleteHero('h-1', previousRevision: null);
      await repository.syncNow();

      final conflictId = repository.currentStatus.openConflicts.single.id;
      final diff = repository.conflictDiff(conflictId);

      expect(diff, isNotNull);
      expect(diff!.remoteMissing, isTrue);
      expect(diff.entries, isEmpty);
    });

    test('conflictDiff vergleicht Laufzeitzustaende', () async {
      final localState = const HeroState.empty().copyWith(currentLep: 20);
      final local = FakeRepository(
        heroes: <HeroSheet>[hero('h-1', 'Alrik')],
        states: <String, HeroState>{'h-1': localState},
      );
      final remote = FakeRemoteHeroAndStateSyncGateway();
      final metadata = InMemorySyncMetadataStore();
      await remote.saveHero(hero('h-1', 'Alrik'), previousRevision: null);
      await remote.saveHeroState(
        'h-1',
        const HeroState.empty().copyWith(currentLep: 12),
        previousRevision: null,
      );

      final repository = SyncingHeroRepository(
        local: local,
        remote: remote,
        metadataStore: metadata,
        accountId: 'user-1',
        startRemoteListener: false,
      );
      await repository.syncNow();

      final conflict = repository.currentStatus.openConflicts.singleWhere(
        (entry) => entry.objectType == SyncObjectType.heroState,
      );
      final diff = repository.conflictDiff(conflict.id);

      expect(diff, isNotNull);
      final lepEntry = diff!.entries.singleWhere(
        (entry) => entry.path.join('.') == 'currentLep',
      );
      expect(lepEntry.kind, SyncDiffKind.changed);
      expect(lepEntry.localValue, 20);
      expect(lepEntry.remoteValue, 12);
    });

    test('conflictDiff vergleicht Offline-Helden mit Konto-Version', () async {
      final local = FakeRepository(
        heroes: <HeroSheet>[hero('h-1', 'Konto Alrik')],
      );
      final remote = FakeRemoteHeroSyncGateway();
      final metadata = InMemorySyncMetadataStore();
      final repository = SyncingHeroRepository(
        local: local,
        remote: remote,
        metadataStore: metadata,
        accountId: 'user-1',
        startRemoteListener: false,
      );

      await repository.queueOfflineProfileConflicts(
        offlineHeroes: <HeroSheet>[hero('h-1', 'Offline Alrik')],
      );

      final conflictId = repository.currentStatus.openConflicts.single.id;
      final diff = repository.conflictDiff(conflictId);

      expect(diff, isNotNull);
      final nameEntry = diff!.entries.singleWhere(
        (entry) => entry.path.join('.') == 'name',
      );
      expect(nameEntry.localValue, 'Offline Alrik');
      expect(nameEntry.remoteValue, 'Konto Alrik');
    });

    test(
      'opens a conflict when a concurrent writer races the push',
      () async {
        final local = FakeRepository.empty();
        final remote = _RacingRemoteHeroSyncGateway();
        final metadata = InMemorySyncMetadataStore();
        await remote.saveHero(hero('h-1', 'Alrik'), previousRevision: null);

        final repository = SyncingHeroRepository(
          local: local,
          remote: remote,
          metadataStore: metadata,
          accountId: 'user-1',
          startRemoteListener: false,
        );
        await repository.syncNow();

        // Der parallele Schreiber schlaegt genau zwischen dem Pre-Read des
        // Pushs und dem eigentlichen Write zu.
        remote.concurrentWrite = hero('h-1', 'Remote Racer');
        await repository.saveHero(hero('h-1', 'Lokaler Racer'));

        expect(repository.currentStatus.openConflicts, hasLength(1));
        expect((await remote.loadHero('h-1'))?.hero?.name, 'Remote Racer');
        expect((await local.loadHeroById('h-1'))?.name, 'Lokaler Racer');
      },
    );

    test('keeps local save and records failure when push is offline', () async {
      final local = FakeRepository.empty();
      final remote = _OfflineRemoteHeroSyncGateway();
      final metadata = InMemorySyncMetadataStore();
      final repository = SyncingHeroRepository(
        local: local,
        remote: remote,
        metadataStore: metadata,
        accountId: 'user-1',
        startRemoteListener: false,
      );

      remote.offline = true;
      await repository.saveHero(hero('h-1', 'Alrik'));

      expect((await local.loadHeroById('h-1'))?.name, 'Alrik');
      expect(
        repository.currentStatus.lastFailure?.kind,
        SyncErrorKind.network,
      );

      remote.offline = false;
      expect(await remote.loadAllHeroes(), isEmpty);
      await repository.syncNow();

      expect((await remote.loadHero('h-1'))?.hero?.name, 'Alrik');
      expect(repository.currentStatus.lastFailure, isNull);
    });

    test('completes an offline delete on next sync instead of resurrecting',
        () async {
      final local = FakeRepository.empty();
      final remote = _OfflineRemoteHeroSyncGateway();
      final metadata = InMemorySyncMetadataStore();
      await remote.saveHero(hero('h-1', 'Alrik'), previousRevision: null);

      final repository = SyncingHeroRepository(
        local: local,
        remote: remote,
        metadataStore: metadata,
        accountId: 'user-1',
        startRemoteListener: false,
      );
      await repository.syncNow();

      remote.offline = true;
      await repository.deleteHero('h-1');

      expect(await local.loadHeroById('h-1'), isNull);
      expect(
        repository.currentStatus.lastFailure?.kind,
        SyncErrorKind.network,
      );

      remote.offline = false;
      await repository.syncNow();

      expect(await local.loadHeroById('h-1'), isNull);
      expect((await remote.loadHero('h-1'))?.isDeleted, isTrue);
      expect(repository.currentStatus.openConflicts, isEmpty);
      expect(repository.currentStatus.lastFailure, isNull);
    });

    test(
      'opens a deletion conflict when remote changed after offline delete',
      () async {
        final local = FakeRepository.empty();
        final remote = _OfflineRemoteHeroSyncGateway();
        final metadata = InMemorySyncMetadataStore();
        await remote.saveHero(hero('h-1', 'Alrik'), previousRevision: null);

        final repository = SyncingHeroRepository(
          local: local,
          remote: remote,
          metadataStore: metadata,
          accountId: 'user-1',
          startRemoteListener: false,
        );
        await repository.syncNow();

        remote.offline = true;
        await repository.deleteHero('h-1');
        remote.offline = false;
        await remote.saveHero(
          hero('h-1', 'Remote Neu'),
          previousRevision: null,
        );

        await repository.syncNow();

        expect(await local.loadHeroById('h-1'), isNull);
        expect((await remote.loadHero('h-1'))?.hero?.name, 'Remote Neu');
        final conflict = repository.currentStatus.openConflicts.single;
        expect(conflict.localSummary, 'Lokal gelöscht');
        expect(conflict.supportsKeepBoth, isFalse);

        await repository.resolveConflict(
          conflict.id,
          SyncResolutionChoice.keepRemote,
        );

        expect((await local.loadHeroById('h-1'))?.name, 'Remote Neu');
        expect(repository.currentStatus.openConflicts, isEmpty);
      },
    );

    test('deletion conflict resolved with keepLocal enforces the delete',
        () async {
      final local = FakeRepository.empty();
      final remote = _OfflineRemoteHeroSyncGateway();
      final metadata = InMemorySyncMetadataStore();
      await remote.saveHero(hero('h-1', 'Alrik'), previousRevision: null);

      final repository = SyncingHeroRepository(
        local: local,
        remote: remote,
        metadataStore: metadata,
        accountId: 'user-1',
        startRemoteListener: false,
      );
      await repository.syncNow();

      remote.offline = true;
      await repository.deleteHero('h-1');
      remote.offline = false;
      await remote.saveHero(hero('h-1', 'Remote Neu'), previousRevision: null);
      await repository.syncNow();
      final conflict = repository.currentStatus.openConflicts.single;

      await repository.resolveConflict(
        conflict.id,
        SyncResolutionChoice.keepLocal,
      );

      expect(await local.loadHeroById('h-1'), isNull);
      expect((await remote.loadHero('h-1'))?.isDeleted, isTrue);
      expect(repository.currentStatus.openConflicts, isEmpty);
    });

    test('isolates broken remote records instead of aborting the batch',
        () async {
      final local = _RejectingRepository(rejectedHeroId: 'h-2');
      final remote = FakeRemoteHeroSyncGateway();
      final metadata = InMemorySyncMetadataStore();
      await remote.saveHero(hero('h-1', 'Alrik'), previousRevision: null);
      await remote.saveHero(hero('h-2', 'Kaputt'), previousRevision: null);
      await remote.saveHero(hero('h-3', 'Yasinde'), previousRevision: null);

      final repository = SyncingHeroRepository(
        local: local,
        remote: remote,
        metadataStore: metadata,
        accountId: 'user-1',
        startRemoteListener: false,
      );

      await repository.syncNow();

      expect((await local.loadHeroById('h-1'))?.name, 'Alrik');
      expect(await local.loadHeroById('h-2'), isNull);
      expect((await local.loadHeroById('h-3'))?.name, 'Yasinde');
      final failure = repository.currentStatus.lastFailure;
      expect(failure, isNotNull);
      expect(failure!.kind, SyncErrorKind.decode);
      expect(failure.message, contains('h-2'));
      expect(repository.currentStatus.lastSuccessfulSync, isNull);
    });

    test('classifies network errors during syncNow in the status', () async {
      final local = FakeRepository.empty();
      final remote = _FailingRemoteHeroSyncGateway(
        const SyncNetworkException('Cloud nicht erreichbar'),
      );
      final metadata = InMemorySyncMetadataStore();
      final repository = SyncingHeroRepository(
        local: local,
        remote: remote,
        metadataStore: metadata,
        accountId: 'user-1',
        startRemoteListener: false,
      );

      await repository.syncNow();

      final failure = repository.currentStatus.lastFailure;
      expect(failure, isNotNull);
      expect(failure!.kind, SyncErrorKind.network);
      expect(failure.message, 'Cloud nicht erreichbar');
      expect(repository.currentStatus.lastError, 'Cloud nicht erreichbar');
      expect(repository.currentStatus.isSyncing, isFalse);
    });
  });
}

class _FailingRemoteHeroSyncGateway extends FakeRemoteHeroSyncGateway {
  _FailingRemoteHeroSyncGateway(this.error);

  final Object error;

  @override
  Future<List<RemoteHeroRecord>> loadAllHeroes() async {
    throw error;
  }
}

/// Lehnt das Speichern eines bestimmten Helden ab (kaputter Datensatz).
class _RejectingRepository extends FakeRepository {
  _RejectingRepository({required this.rejectedHeroId});

  final String rejectedHeroId;

  @override
  Future<void> saveHero(HeroSheet hero) {
    if (hero.id == rejectedHeroId) {
      throw StateError('Datensatz $rejectedHeroId ist nicht speicherbar.');
    }
    return super.saveHero(hero);
  }
}

/// Simuliert einen parallelen Schreiber zwischen Pre-Read und Write.
class _RacingRemoteHeroSyncGateway extends FakeRemoteHeroSyncGateway {
  HeroSheet? concurrentWrite;

  @override
  Future<RemoteHeroRecord> saveHero(
    HeroSheet hero, {
    required String? previousRevision,
  }) async {
    final pending = concurrentWrite;
    if (pending != null) {
      concurrentWrite = null;
      await super.saveHero(pending, previousRevision: null);
    }
    return super.saveHero(hero, previousRevision: previousRevision);
  }
}

/// Simuliert einen Offline-Zustand fuer alle Remote-Zugriffe.
class _OfflineRemoteHeroSyncGateway extends FakeRemoteHeroSyncGateway {
  bool offline = false;

  @override
  Future<List<RemoteHeroRecord>> loadAllHeroes() {
    _failIfOffline();
    return super.loadAllHeroes();
  }

  @override
  Future<RemoteHeroRecord?> loadHero(String heroId) {
    _failIfOffline();
    return super.loadHero(heroId);
  }

  @override
  Future<RemoteHeroRecord> saveHero(
    HeroSheet hero, {
    required String? previousRevision,
  }) {
    _failIfOffline();
    return super.saveHero(hero, previousRevision: previousRevision);
  }

  @override
  Future<RemoteHeroRecord> deleteHero(
    String heroId, {
    required String? previousRevision,
  }) {
    _failIfOffline();
    return super.deleteHero(heroId, previousRevision: previousRevision);
  }

  void _failIfOffline() {
    if (offline) {
      throw const SyncNetworkException('Cloud nicht erreichbar');
    }
  }
}

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
      contentHash: stableContentHash(hero.toJson()),
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
    final revision = 's-${++_stateRevisionCounter}';
    final record = RemoteHeroStateRecord(
      heroId: heroId,
      state: state,
      revision: revision,
      contentHash: stableContentHash(state.toJson()),
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
}
