import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/gruppen_snapshot.dart';

void main() {
  group('HeldVisitenkarte', () {
    test('toJson/fromJson Roundtrip', () {
      final original = HeldVisitenkarte(
        heroId: 'test-id-123',
        name: 'Alrik',
        rasse: 'Mensch',
        kultur: 'Mittelreich',
        profession: 'Krieger',
        level: 5,
        maxLep: 30,
        maxAsp: 0,
        maxAu: 28,
        iniBase: 10,
        avatarThumbnailBase64: 'abc123==',
        exportedAt: DateTime.utc(2026, 3, 30, 12, 0),
      );

      final json = original.toJson();
      final restored = HeldVisitenkarte.fromJson(json);

      expect(restored.heroId, 'test-id-123');
      expect(restored.name, 'Alrik');
      expect(restored.rasse, 'Mensch');
      expect(restored.kultur, 'Mittelreich');
      expect(restored.profession, 'Krieger');
      expect(restored.level, 5);
      expect(restored.maxLep, 30);
      expect(restored.maxAsp, 0);
      expect(restored.maxAu, 28);
      expect(restored.iniBase, 10);
      expect(restored.avatarThumbnailBase64, 'abc123==');
      expect(restored.exportedAt, DateTime.utc(2026, 3, 30, 12, 0));
    });

    test('fromJson mit fehlenden Feldern gibt Defaults', () {
      final minimal = HeldVisitenkarte.fromJson(const <String, dynamic>{});
      expect(minimal.heroId, '');
      expect(minimal.name, '');
      expect(minimal.rasse, '');
      expect(minimal.level, 0);
      expect(minimal.maxLep, 0);
      expect(minimal.avatarThumbnailBase64, isNull);
    });

    test('toJson laesst optionale Felder weg wenn null', () {
      final held = HeldVisitenkarte(
        heroId: 'id',
        name: 'Name',
        exportedAt: DateTime.utc(2026),
      );
      final json = held.toJson();
      expect(json.containsKey('avatarThumbnailBase64'), isFalse);
    });

    test(
      'toFirestoreJson entfernt uebergrosse Thumbnails und behaelt Rest',
      () {
        final held = HeldVisitenkarte(
          heroId: 'id',
          name: 'Name',
          avatarThumbnailBase64:
              'a' * (HeldVisitenkarte.avatarThumbnailBase64MaxLength + 1),
          exportedAt: DateTime.utc(2026),
          istManuell: true,
        );

        final json = held.toFirestoreJson();

        expect(json['heroId'], 'id');
        expect(json['name'], 'Name');
        expect(json['istManuell'], isTrue);
        expect(json.containsKey('avatarThumbnailBase64'), isFalse);
      },
    );
  });

  group('GruppenSnapshot', () {
    test('toJson/fromJson Roundtrip', () {
      final original = GruppenSnapshot(
        gruppenName: 'Reisegruppe Aventurien',
        exportedAt: DateTime.utc(2026, 3, 30, 14, 30),
        helden: [
          HeldVisitenkarte(
            heroId: 'hero-1',
            name: 'Alrik',
            rasse: 'Mensch',
            kultur: 'Mittelreich',
            profession: 'Krieger',
            level: 5,
            maxLep: 30,
            maxAsp: 0,
            maxAu: 28,
            iniBase: 10,
            exportedAt: DateTime.utc(2026, 3, 30, 14, 0),
          ),
          HeldVisitenkarte(
            heroId: 'hero-2',
            name: 'Lysandra',
            rasse: 'Elf',
            kultur: 'Auelf',
            profession: 'Magierin',
            level: 7,
            maxLep: 22,
            maxAsp: 40,
            maxAu: 20,
            iniBase: 12,
            exportedAt: DateTime.utc(2026, 3, 30, 14, 0),
          ),
        ],
      );

      final json = original.toJson();
      final restored = GruppenSnapshot.fromJson(json);

      expect(restored.gruppenName, 'Reisegruppe Aventurien');
      expect(restored.exportedAt, DateTime.utc(2026, 3, 30, 14, 30));
      expect(restored.helden, hasLength(2));
      expect(restored.helden[0].name, 'Alrik');
      expect(restored.helden[1].name, 'Lysandra');
      expect(restored.helden[1].maxAsp, 40);
    });

    test('fromJson wirft bei falschem kind', () {
      expect(
        () => GruppenSnapshot.fromJson({'kind': 'wrong'}),
        throwsFormatException,
      );
    });

    test('fromJson wirft bei unbekannter Version', () {
      expect(
        () => GruppenSnapshot.fromJson({
          'kind': 'dsa.gruppe.snapshot',
          'snapshotSchemaVersion': 99,
        }),
        throwsFormatException,
      );
    });

    test('toJson enthaelt kind und Version', () {
      final snapshot = GruppenSnapshot(
        gruppenName: 'Test',
        exportedAt: DateTime.utc(2026),
        helden: const [],
      );
      final json = snapshot.toJson();
      expect(json['kind'], 'dsa.gruppe.snapshot');
      expect(json['snapshotSchemaVersion'], 1);
    });
  });
}
