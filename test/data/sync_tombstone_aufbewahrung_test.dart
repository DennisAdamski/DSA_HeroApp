import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/sync/in_memory_sync_metadata_store.dart';
import 'package:dsa_heldenverwaltung/data/syncing_hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

import '../test_support/fake_remote_hero_sync_gateway.dart';

/// SYNC-11: Tombstones bleiben [kTombstoneAufbewahrung] lang online und
/// werden danach beim vollständigen Abgleich entfernt.
void main() {
  const held = HeroSheet(
    id: 'h-1',
    name: 'Alrik',
    level: 1,
    attributes: Attributes(
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

  // Die Fake-Cloud datiert Schreibzugriffe auf Januar 2026.
  final tombstoneZeit = DateTime.utc(2026, 1, 1, 12);

  Future<(FakeTombstoneCloud, InMemorySyncMetadataStore)> geloeschterHeld({
    required DateTime jetzt,
    FakeRepository? lokal,
  }) async {
    final cloud = FakeTombstoneCloud();
    final saved = await cloud.saveHero(held, previousRevision: null);
    await cloud.deleteHero('h-1', previousRevision: saved.revision);
    final metadata = InMemorySyncMetadataStore();
    final repository = SyncingHeroRepository(
      local: lokal ?? FakeRepository.empty(),
      remote: cloud,
      metadataStore: metadata,
      accountId: 'user-1',
      startRemoteListener: false,
      uhr: () => jetzt,
    );
    await repository.syncNow();
    return (cloud, metadata);
  }

  test('ein alter Tombstone wird entfernt, samt Sync-Metadaten', () async {
    final (cloud, metadata) = await geloeschterHeld(
      jetzt: tombstoneZeit.add(
        kTombstoneAufbewahrung + const Duration(days: 1),
      ),
    );

    expect(cloud.entfernt, contains('held:h-1'));
    expect(await cloud.loadHero('h-1'), isNull);
    expect(
      await metadata.load(
        const SyncObjectKey(type: SyncObjectType.hero, id: 'h-1'),
      ),
      isNull,
    );
  });

  test('ein junger Tombstone bleibt', () async {
    final (cloud, _) = await geloeschterHeld(
      jetzt: tombstoneZeit.add(const Duration(days: 30)),
    );

    expect(cloud.entfernt, isEmpty);
    expect((await cloud.loadHero('h-1'))?.isDeleted, isTrue);
  });

  test('liegt der Held hier noch, bleibt der Tombstone', () async {
    final (cloud, _) = await geloeschterHeld(
      jetzt: tombstoneZeit.add(kTombstoneAufbewahrung * 2),
      lokal: FakeRepository(heroes: [held]),
    );

    expect(cloud.entfernt, isNot(contains('held:h-1')));
  });
}
