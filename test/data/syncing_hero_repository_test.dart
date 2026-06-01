import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/sync/in_memory_sync_metadata_store.dart';
import 'package:dsa_heldenverwaltung/data/sync/remote_hero_sync_gateway.dart';
import 'package:dsa_heldenverwaltung/data/syncing_hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
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
