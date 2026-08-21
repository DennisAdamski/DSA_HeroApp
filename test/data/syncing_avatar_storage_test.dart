import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/avatar_load_failure.dart';
import 'package:dsa_heldenverwaltung/data/syncing_avatar_storage.dart';
import 'package:dsa_heldenverwaltung/test_support/in_memory_avatar_file_storage.dart';
import 'package:dsa_heldenverwaltung/test_support/in_memory_cloud_avatar_storage.dart';

void main() {
  late InMemoryAvatarFileStorage local;
  late InMemoryCloudAvatarStorage cloud;
  late SyncingAvatarStorage storage;

  const heroPath = '/helden';
  final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

  setUp(() {
    local = InMemoryAvatarFileStorage();
    cloud = InMemoryCloudAvatarStorage();
    storage = SyncingAvatarStorage(local: local, cloud: cloud);
  });

  Future<String> saveGallery({String entryId = 'e1'}) {
    return storage.saveGalleryImage(
      heroStoragePath: heroPath,
      heroId: 'held-1',
      entryId: entryId,
      pngBytes: bytes,
    );
  }

  group('Speichern', () {
    test('schreibt lokal und in die Cloud', () async {
      final fileName = await saveGallery();

      expect(fileName, 'held-1_e1.png');
      expect(local.files[fileName], bytes);
      expect(cloud.objects[fileName], bytes);
    });

    test('ueberlebt einen Cloud-Fehler ohne Rethrow', () async {
      cloud.failUploads = true;

      final fileName = await saveGallery();

      expect(fileName, 'held-1_e1.png');
      expect(local.files[fileName], bytes, reason: 'lokaler Write zaehlt');
      expect(cloud.objects, isEmpty);
    });

    test('laedt ohne angemeldeten Nutzer nicht hoch', () async {
      cloud.available = false;

      await saveGallery();

      expect(cloud.uploadCalls, 0);
    });
  });

  group('Laden', () {
    test('nutzt bei lokalem Treffer keine Cloud', () async {
      await saveGallery();
      cloud.downloadCalls = 0;

      final loaded = await storage.loadGalleryImageBytes(
        heroStoragePath: heroPath,
        fileName: 'held-1_e1.png',
      );

      expect(loaded, bytes);
      expect(cloud.downloadCalls, 0);
    });

    test('faellt auf die Cloud zurueck und legt lokal ab', () async {
      cloud.objects['held-1_e1.png'] = bytes;

      final loaded = await storage.loadGalleryImageBytes(
        heroStoragePath: heroPath,
        fileName: 'held-1_e1.png',
      );

      expect(loaded, bytes);
      expect(cloud.downloadCalls, 1);
      expect(
        local.files['held-1_e1.png'],
        bytes,
        reason: 'heruntergeladene Bytes werden lokal gecacht',
      );

      // Zweiter Zugriff trifft den lokalen Cache.
      await storage.loadGalleryImageBytes(
        heroStoragePath: heroPath,
        fileName: 'held-1_e1.png',
      );
      expect(cloud.downloadCalls, 1);
    });

    test('cacht Legacy-Dateinamen unveraendert', () async {
      cloud.objects['held-1.png'] = bytes;

      final loaded = await storage.loadGalleryImageBytes(
        heroStoragePath: heroPath,
        fileName: 'held-1.png',
      );

      expect(loaded, bytes);
      expect(local.files.keys, contains('held-1.png'));
    });

    test('liefert null wenn beide Seiten leer sind', () async {
      final loaded = await storage.loadGalleryImageBytes(
        heroStoragePath: heroPath,
        fileName: 'fehlt.png',
      );

      expect(loaded, isNull);
    });

    test('reicht einen Download-Fehler als Grund durch', () async {
      cloud.objects['held-1_e1.png'] = bytes;
      cloud.failDownloads = true;

      // Bewusst anders als beim Schreiben: Ein Lesefehler darf nicht wie ein
      // fehlendes Bild aussehen, sonst ist im Web nicht feststellbar, warum
      // die Galerie leer bleibt.
      await expectLater(
        storage.loadGalleryImageBytes(
          heroStoragePath: heroPath,
          fileName: 'held-1_e1.png',
        ),
        throwsA(
          isA<AvatarLoadException>().having(
            (e) => e.grund,
            'grund',
            AvatarLoadFailure.unbekannt,
          ),
        ),
      );
    });

    test('lokaler Treffer maskiert einen Cloud-Fehler', () async {
      await saveGallery();
      cloud.failDownloads = true;

      final loaded = await storage.loadGalleryImageBytes(
        heroStoragePath: heroPath,
        fileName: 'held-1_e1.png',
      );

      expect(loaded, bytes, reason: 'die Cloud wird gar nicht erst gefragt');
    });
  });

  group('Loeschen', () {
    test('entfernt lokal und in der Cloud', () async {
      await saveGallery();

      await storage.deleteGalleryImage(
        heroStoragePath: heroPath,
        fileName: 'held-1_e1.png',
      );

      expect(local.files, isEmpty);
      expect(cloud.objects, isEmpty);
    });

    test('loescht lokal auch ohne Cloud-Zugriff', () async {
      await saveGallery();
      cloud.available = false;

      await storage.deleteGalleryImage(
        heroStoragePath: heroPath,
        fileName: 'held-1_e1.png',
      );

      expect(local.files, isEmpty);
      expect(cloud.deleteCalls, 0);
    });
  });

  test('ist ohne Cloud-Zugriff ein reiner Passthrough', () async {
    cloud.available = false;

    await saveGallery();
    await storage.loadGalleryImageBytes(
      heroStoragePath: heroPath,
      fileName: 'fehlt.png',
    );

    expect(cloud.uploadCalls, 0);
    expect(cloud.downloadCalls, 0);
    expect(cloud.deleteCalls, 0);
  });
}
