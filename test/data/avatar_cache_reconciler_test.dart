import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/avatar_blob_cache.dart';
import 'package:dsa_heldenverwaltung/data/avatar_cache_reconciler.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

void main() {
  late InMemoryAvatarBlobCache cache;
  late AvatarCacheReconciler reconciler;

  final bytes = Uint8List.fromList(<int>[1, 2, 3]);

  setUp(() {
    cache = InMemoryAvatarBlobCache();
    reconciler = AvatarCacheReconciler(cache: cache);
  });

  HeroSheet heroWith(List<String> fileNames) {
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
        avatarGallery: [
          for (var i = 0; i < fileNames.length; i++)
            AvatarGalleryEntry(id: 'e$i', fileName: fileNames[i]),
        ],
      ),
    );
  }

  test('behaelt referenzierte Dateien', () async {
    cache.eintraege['held-1_e0.png'] = bytes;

    final entfernt = await reconciler.run(
      heroes: [
        heroWith(['held-1_e0.png']),
      ],
    );

    expect(entfernt, 0);
    expect(cache.eintraege.keys, contains('held-1_e0.png'));
  });

  test('entfernt nur nicht referenzierte Dateien', () async {
    cache.eintraege['held-1_e0.png'] = bytes;
    cache.eintraege['geloescht.png'] = bytes;

    final entfernt = await reconciler.run(
      heroes: [
        heroWith(['held-1_e0.png']),
      ],
    );

    expect(entfernt, 1);
    expect(cache.eintraege.keys, ['held-1_e0.png']);
  });

  test('raeumt bei leerer Heldenliste alles ab', () async {
    cache.eintraege['a.png'] = bytes;
    cache.eintraege['b.png'] = bytes;

    final entfernt = await reconciler.run(heroes: const []);

    expect(entfernt, 2);
    expect(cache.eintraege, isEmpty);
  });

  test('beruecksichtigt alle Helden, nicht nur den ersten', () async {
    cache.eintraege['a.png'] = bytes;
    cache.eintraege['b.png'] = bytes;

    final zweiterHeld = heroWith(['b.png']).copyWith(id: 'held-2');
    final entfernt = await reconciler.run(
      heroes: [
        heroWith(['a.png']),
        zweiterHeld,
      ],
    );

    expect(entfernt, 0);
  });

  test('ist ohne Cache-Inhalt ein No-Op', () async {
    final entfernt = await reconciler.run(
      heroes: [
        heroWith(['held-1_e0.png']),
      ],
    );

    expect(entfernt, 0);
  });
}
