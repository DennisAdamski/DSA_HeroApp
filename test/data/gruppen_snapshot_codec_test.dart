import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/gruppen_snapshot_codec.dart';
import 'package:dsa_heldenverwaltung/domain/gruppen_snapshot.dart';

void main() {
  const codec = GruppenSnapshotCodec();

  group('GruppenSnapshotCodec', () {
    test('encode/decode Roundtrip', () {
      final original = GruppenSnapshot(
        gruppenName: 'Testgruppe',
        exportedAt: DateTime.utc(2026, 3, 30, 10, 0),
        helden: [
          HeldVisitenkarte(
            heroId: 'h1',
            name: 'Held 1',
            rasse: 'Mensch',
            kultur: 'Mittelreich',
            profession: 'Krieger',
            level: 3,
            maxLep: 28,
            maxAsp: 0,
            maxAu: 24,
            iniBase: 9,
            exportedAt: DateTime.utc(2026, 3, 30, 10, 0),
          ),
        ],
      );

      final jsonString = codec.encode(original);
      final restored = codec.decode(jsonString);

      expect(restored.gruppenName, 'Testgruppe');
      expect(restored.helden, hasLength(1));
      expect(restored.helden.first.name, 'Held 1');
      expect(restored.helden.first.maxLep, 28);
    });

    test('decode wirft bei ungueltigem JSON', () {
      expect(
        () => codec.decode('keine json daten'),
        throwsFormatException,
      );
    });

    test('decode wirft bei JSON-Array statt Objekt', () {
      expect(
        () => codec.decode('[1, 2, 3]'),
        throwsFormatException,
      );
    });

    test('decode wirft bei falschem kind-Feld', () {
      expect(
        () => codec.decode('{"kind": "dsa.hero.export"}'),
        throwsFormatException,
      );
    });

    test('encode erzeugt lesbares JSON', () {
      final snapshot = GruppenSnapshot(
        gruppenName: 'G',
        exportedAt: DateTime.utc(2026),
        helden: const [],
      );
      final json = codec.encode(snapshot);
      expect(json, contains('"kind": "dsa.gruppe.snapshot"'));
      expect(json, contains('"gruppenName": "G"'));
    });
  });
}
