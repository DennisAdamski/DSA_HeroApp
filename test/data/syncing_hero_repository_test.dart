import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/sync/in_memory_sync_metadata_store.dart';
import 'package:dsa_heldenverwaltung/data/sync/remote_hero_sync_gateway.dart';
import 'package:dsa_heldenverwaltung/data/syncing_hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
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
  });
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
