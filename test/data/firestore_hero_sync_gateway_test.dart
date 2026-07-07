import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/firestore_hero_sync_gateway.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';

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

  group('FirestoreHeroSyncGateway', () {
    test('saves and loads a hero without previousRevision', () async {
      final firestore = FakeFirebaseFirestore();
      final gateway = FirestoreHeroSyncGateway(
        userId: 'user-1',
        firestore: firestore,
      );

      final saved = await gateway.saveHero(
        hero('h-1', 'Alrik'),
        previousRevision: null,
      );

      expect(saved.revision, isNotEmpty);
      final loaded = await gateway.loadHero('h-1');
      expect(loaded?.hero?.name, 'Alrik');
      expect(loaded?.revision, saved.revision);
    });

    test('accepts a save when previousRevision matches', () async {
      final firestore = FakeFirebaseFirestore();
      final gateway = FirestoreHeroSyncGateway(
        userId: 'user-1',
        firestore: firestore,
      );
      final first = await gateway.saveHero(
        hero('h-1', 'Alrik'),
        previousRevision: null,
      );

      final second = await gateway.saveHero(
        hero('h-1', 'Alrik 2'),
        previousRevision: first.revision,
      );

      expect(second.revision, isNot(first.revision));
      expect((await gateway.loadHero('h-1'))?.hero?.name, 'Alrik 2');
    });

    test(
      'rejects a save with SyncPreconditionException on stale revision',
      () async {
        final firestore = FakeFirebaseFirestore();
        final gateway = FirestoreHeroSyncGateway(
          userId: 'user-1',
          firestore: firestore,
        );
        await gateway.saveHero(hero('h-1', 'Alrik'), previousRevision: null);

        await expectLater(
          gateway.saveHero(
            hero('h-1', 'Verlierer'),
            previousRevision: 'r-veraltet',
          ),
          throwsA(isA<SyncPreconditionException>()),
        );

        expect((await gateway.loadHero('h-1'))?.hero?.name, 'Alrik');
      },
    );

    test('rejects a delete on stale revision', () async {
      final firestore = FakeFirebaseFirestore();
      final gateway = FirestoreHeroSyncGateway(
        userId: 'user-1',
        firestore: firestore,
      );
      await gateway.saveHero(hero('h-1', 'Alrik'), previousRevision: null);

      await expectLater(
        gateway.deleteHero('h-1', previousRevision: 'r-veraltet'),
        throwsA(isA<SyncPreconditionException>()),
      );

      expect((await gateway.loadHero('h-1'))?.isDeleted, isFalse);
    });

    test('writes a tombstone with matching previousRevision', () async {
      final firestore = FakeFirebaseFirestore();
      final gateway = FirestoreHeroSyncGateway(
        userId: 'user-1',
        firestore: firestore,
      );
      final saved = await gateway.saveHero(
        hero('h-1', 'Alrik'),
        previousRevision: null,
      );

      final deleted = await gateway.deleteHero(
        'h-1',
        previousRevision: saved.revision,
      );

      expect(deleted.isDeleted, isTrue);
      final loaded = await gateway.loadHero('h-1');
      expect(loaded?.isDeleted, isTrue);
      expect(loaded?.revision, deleted.revision);
    });
  });
}
