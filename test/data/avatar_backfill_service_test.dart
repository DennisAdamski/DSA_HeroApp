import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/avatar_backfill_service.dart';
import 'package:dsa_heldenverwaltung/data/hive_avatar_sync_marker_store.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/test_support/in_memory_avatar_file_storage.dart';
import 'package:dsa_heldenverwaltung/test_support/in_memory_cloud_avatar_storage.dart';

void main() {
  late InMemoryAvatarFileStorage storage;
  late InMemoryCloudAvatarStorage cloud;
  late InMemoryAvatarSyncMarkerStore markers;
  late AvatarBackfillService service;

  const heroPath = '/helden';
  final bytes = Uint8List.fromList(<int>[9, 8, 7]);

  setUp(() {
    storage = InMemoryAvatarFileStorage();
    cloud = InMemoryCloudAvatarStorage();
    markers = InMemoryAvatarSyncMarkerStore();
    service = AvatarBackfillService(
      storage: storage,
      cloud: cloud,
      markers: markers,
    );
  });

  HeroSheet heroWithGallery(List<AvatarGalleryEntry> gallery) {
    return HeroSheet(
      id: 'held-1',
      name: 'Alrik',
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
      appearance: HeroAppearance(
        avatarGallery: gallery,
        aktivesBildId: gallery.isEmpty ? '' : gallery.first.id,
      ),
    );
  }

  HeroSheet heroWithFile(String fileName, {String id = 'e1'}) {
    return heroWithGallery([
      AvatarGalleryEntry(id: id, fileName: fileName, quelle: 'upload'),
    ]);
  }

  Future<AvatarBackfillReport> run(List<HeroSheet> heroes) {
    return service.run(heroes: heroes, heroStoragePath: heroPath);
  }

  test('laedt lokal vorhandene Bilder hoch', () async {
    storage.files['held-1_e1.png'] = bytes;

    final report = await run([heroWithFile('held-1_e1.png')]);

    expect(cloud.objects['held-1_e1.png'], bytes);
    expect(report.uploaded, 1);
    expect(markers.markers.containsKey('held-1_e1.png'), isTrue);
  });

  test('ignoriert Dateien, die keine Galerie referenziert', () async {
    storage.files['held-1_e1.png'] = bytes;
    storage.files['waise.png'] = bytes;

    await run([heroWithFile('held-1_e1.png')]);

    expect(cloud.objects.keys, ['held-1_e1.png']);
  });

  test('markierte Datei loest keinen Cloud-Aufruf aus', () async {
    storage.files['held-1_e1.png'] = bytes;
    await run([heroWithFile('held-1_e1.png')]);

    cloud.uploadCalls = 0;
    cloud.existsCalls = 0;
    final report = await run([heroWithFile('held-1_e1.png')]);

    expect(cloud.uploadCalls, 0);
    expect(cloud.existsCalls, 0);
    expect(report.skipped, 1);
  });

  test('vorhandene Cloud-Datei wird nur markiert', () async {
    storage.files['held-1_e1.png'] = bytes;
    cloud.objects['held-1_e1.png'] = bytes;

    final report = await run([heroWithFile('held-1_e1.png')]);

    expect(cloud.uploadCalls, 0);
    expect(report.skipped, 1);
    expect(markers.markers.containsKey('held-1_e1.png'), isTrue);
  });

  test('Upload-Fehler setzt keinen Marker und wird wiederholt', () async {
    storage.files['held-1_e1.png'] = bytes;
    cloud.failUploads = true;

    final first = await run([heroWithFile('held-1_e1.png')]);
    expect(first.failed, 1);
    expect(markers.markers, isEmpty);

    cloud.failUploads = false;
    final second = await run([heroWithFile('held-1_e1.png')]);
    expect(second.uploaded, 1);
  });

  test('laedt fehlende Bilder aus der Cloud in den lokalen Cache', () async {
    cloud.objects['held-1_e1.png'] = bytes;

    final report = await run([heroWithFile('held-1_e1.png')]);

    expect(storage.files['held-1_e1.png'], bytes);
    expect(report.downloaded, 1);
  });

  test('zaehlt beidseitig fehlende Bilder als vermisst', () async {
    final report = await run([heroWithFile('held-1_e1.png')]);

    expect(report.missing, 1);
    expect(markers.markers, isEmpty);
  });

  test('ist ohne Cloud-Zugriff ein No-Op', () async {
    storage.files['held-1_e1.png'] = bytes;
    cloud.available = false;

    final report = await run([heroWithFile('held-1_e1.png')]);

    expect(cloud.uploadCalls, 0);
    expect(report.uploaded, 0);
  });

  test('behaelt den Legacy-Dateinamen bei', () async {
    storage.files['held-1.png'] = bytes;
    final hero = heroWithFile('held-1.png', id: 'held-1_legacy');

    await run([hero]);

    expect(
      cloud.objects.keys,
      ['held-1.png'],
      reason: 'Name darf nicht aus heroId und entryId neu gebaut werden',
    );
  });

  test('markiert den Lauf mit Zeitstempel und Beschreibung', () async {
    storage.files['held-1_e1.png'] = bytes;

    final report = await run([heroWithFile('held-1_e1.png')]);

    expect(report.zuletztGelaufen, isNotNull);
    expect(report.beschreibung, contains('1 hochgeladen'));
  });

  test('ohne Cloud-Zugriff bleibt der Zeitstempel leer', () async {
    cloud.available = false;

    final report = await run([heroWithFile('held-1_e1.png')]);

    expect(
      report.zuletztGelaufen,
      isNull,
      reason: 'ein uebersprungener Lauf darf nicht als erledigt gelten',
    );
  });

  test('meldet einen vollstaendig abgeglichenen Stand', () async {
    storage.files['held-1_e1.png'] = bytes;
    await run([heroWithFile('held-1_e1.png')]);

    final report = await run([heroWithFile('held-1_e1.png')]);

    expect(report.beschreibung, 'Alle Avatarbilder sind abgeglichen.');
  });

  test('ein Fehlschlag stoppt die uebrigen Eintraege nicht', () async {
    storage.files['held-1_e1.png'] = bytes;
    storage.files['held-1_e2.png'] = bytes;
    cloud.failExists = true;

    final report = await run([
      heroWithGallery([
        const AvatarGalleryEntry(id: 'e1', fileName: 'held-1_e1.png'),
        const AvatarGalleryEntry(id: 'e2', fileName: 'held-1_e2.png'),
      ]),
    ]);

    expect(report.failed, 2);
  });
}
