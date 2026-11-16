import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:dsa_heldenverwaltung/data/avatar_file_storage_io.dart';

void main() {
  late Directory wurzel;
  late String speicher;
  late File fremd;
  const storage = LocalAvatarFileStorage();

  setUp(() async {
    wurzel = await Directory.systemTemp.createTemp('avatar_pfad_');
    addTearDown(() async {
      if (await wurzel.exists()) {
        await wurzel.delete(recursive: true);
      }
    });
    speicher = p.join(wurzel.path, 'helden');
    Directory(p.join(speicher, 'avatare')).createSync(recursive: true);
    fremd = File(p.join(wurzel.path, 'wichtig.txt'))..writeAsStringSync('x');
  });

  group('Bildnamen mit Pfadangabe (PLAT-01)', () {
    test('Löschen entfernt nichts außerhalb des Avatar-Ordners', () async {
      for (final name in <String>['../../wichtig.txt', fremd.path]) {
        await storage.deleteGalleryImage(
          heroStoragePath: speicher,
          fileName: name,
        );
      }
      expect(fremd.existsSync(), isTrue);
    });

    test('Laden liest nichts außerhalb des Avatar-Ordners', () async {
      expect(
        await storage.loadGalleryImageBytes(
          heroStoragePath: speicher,
          fileName: '../../wichtig.txt',
        ),
        isNull,
      );
    });

    test('Speichern schreibt nicht außerhalb des Avatar-Ordners', () async {
      await expectLater(
        storage.saveGalleryImage(
          heroStoragePath: speicher,
          heroId: '../../ausbruch',
          entryId: 'e1',
          pngBytes: const <int>[1, 2, 3],
        ),
        throwsFormatException,
      );
      await expectLater(
        storage.saveGalleryImage(
          heroStoragePath: speicher,
          heroId: 'held',
          entryId: '../../../ausbruch',
          pngBytes: const <int>[1, 2, 3],
        ),
        throwsFormatException,
      );
      expect(
        wurzel.listSync(recursive: true).whereType<File>().map((f) => f.path),
        <String>[fremd.path],
      );
    });

    test('gewöhnliche Namen funktionieren weiter', () async {
      final name = await storage.saveGalleryImage(
        heroStoragePath: speicher,
        heroId: 'held',
        entryId: 'e1',
        pngBytes: const <int>[1, 2, 3],
      );
      expect(
        await storage.loadGalleryImageBytes(
          heroStoragePath: speicher,
          fileName: name,
        ),
        <int>[1, 2, 3],
      );
      await storage.deleteGalleryImage(
        heroStoragePath: speicher,
        fileName: name,
      );
      expect(File(p.join(speicher, 'avatare', name)).existsSync(), isFalse);
    });
  });
}
