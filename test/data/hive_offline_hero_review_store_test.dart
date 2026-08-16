import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/hive_offline_hero_review_store.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

void main() {
  Future<String> createTempPath() async {
    final root = await Directory.systemTemp.createTemp(
      'dsa_offline_review_test_',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    return root.path;
  }

  OfflineHeroReview review(
    String heroId, {
    SyncResolutionChoice choice = SyncResolutionChoice.keepRemote,
    String offlineHash = 'hash-1',
  }) {
    return OfflineHeroReview(
      heroId: heroId,
      heroName: 'Alrik',
      offlineHash: offlineHash,
      choice: choice,
      decidedAt: DateTime.utc(2026, 8, 16, 12, 30),
    );
  }

  test('Beschluesse ueberdauern das Schliessen der Box', () async {
    final path = await createTempPath();

    final first = await HiveOfflineHeroReviewStore.create(storagePath: path);
    await first.save(review('h-1', choice: SyncResolutionChoice.keepBoth));
    await first.close();

    final second = await HiveOfflineHeroReviewStore.create(storagePath: path);
    addTearDown(second.close);
    final loaded = await second.loadAll();

    expect(loaded, hasLength(1));
    expect(loaded.single.heroId, 'h-1');
    expect(loaded.single.heroName, 'Alrik');
    expect(loaded.single.offlineHash, 'hash-1');
    expect(loaded.single.choice, SyncResolutionChoice.keepBoth);
    expect(loaded.single.decidedAt, DateTime.utc(2026, 8, 16, 12, 30));
  });

  test('save ersetzt den Beschluss zur selben Helden-ID', () async {
    final store = await HiveOfflineHeroReviewStore.create(
      storagePath: await createTempPath(),
    );
    addTearDown(store.close);

    await store.save(review('h-1', choice: SyncResolutionChoice.keepRemote));
    await store.save(
      review('h-1', choice: SyncResolutionChoice.keepLocal, offlineHash: 'neu'),
    );

    final loaded = await store.loadAll();
    expect(loaded, hasLength(1));
    expect(loaded.single.choice, SyncResolutionChoice.keepLocal);
    expect(loaded.single.offlineHash, 'neu');
  });

  test('delete und clear entfernen Beschluesse', () async {
    final store = await HiveOfflineHeroReviewStore.create(
      storagePath: await createTempPath(),
    );
    addTearDown(store.close);

    await store.save(review('h-1'));
    await store.save(review('h-2'));

    await store.delete('h-1');
    expect(await store.loadAll(), hasLength(1));

    await store.clear();
    expect(await store.loadAll(), isEmpty);
  });
}
