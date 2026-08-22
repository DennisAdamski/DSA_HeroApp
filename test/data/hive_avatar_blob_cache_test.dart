import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:dsa_heldenverwaltung/data/hive_avatar_blob_cache.dart';

void main() {
  late Directory root;
  late HiveAvatarBlobCache cache;

  final bytes = Uint8List.fromList(<int>[10, 20, 30]);

  setUp(() async {
    // Der Cache oeffnet seine Box ohne Pfad, weil er im Web gegen IndexedDB
    // laeuft. Fuer den Test bekommt Hive deshalb ein temporaeres Wurzelverzeichnis.
    root = await Directory.systemTemp.createTemp('dsa_avatar_blob_cache_');
    Hive.init(root.path);
    cache = HiveAvatarBlobCache();
  });

  tearDown(() async {
    await cache.close();
    await Hive.deleteBoxFromDisk('avatar_blobs_v1');
    await Hive.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('legt Bytes ab und liest sie zurueck', () async {
    await cache.write('held_a.png', bytes);

    expect(await cache.read('held_a.png'), bytes);
  });

  test('liefert null fuer unbekannte Dateien', () async {
    expect(await cache.read('fehlt.png'), isNull);
  });

  test('ignoriert leere Dateinamen', () async {
    await cache.write('', bytes);

    expect(await cache.read(''), isNull);
  });

  test('entfernt einen einzelnen Eintrag', () async {
    await cache.write('held_a.png', bytes);

    await cache.remove('held_a.png');

    expect(await cache.read('held_a.png'), isNull);
  });

  test('entfernt nur verwaiste Eintraege', () async {
    await cache.write('behalten.png', bytes);
    await cache.write('verwaist.png', bytes);

    final entfernt = await cache.entferneVerwaiste({'behalten.png'});

    expect(entfernt, 1);
    expect(await cache.read('behalten.png'), bytes);
    expect(await cache.read('verwaist.png'), isNull);
  });

  test('ist ein No-Op, wenn nichts verwaist ist', () async {
    await cache.write('behalten.png', bytes);

    expect(await cache.entferneVerwaiste({'behalten.png'}), 0);
  });

  test('ueberlebt das Schliessen und Wiederoeffnen der Box', () async {
    await cache.write('held_a.png', bytes);
    await cache.close();

    final wieder = HiveAvatarBlobCache();
    addTearDown(wieder.close);

    expect(
      await wieder.read('held_a.png'),
      bytes,
      reason: 'sonst waere der Cache nach einem Reload wertlos',
    );
  });
}
