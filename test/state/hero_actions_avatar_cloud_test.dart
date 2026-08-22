import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/cloud_avatar_storage.dart';
import 'package:dsa_heldenverwaltung/data/syncing_avatar_storage.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/avatar_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/test_support/in_memory_avatar_file_storage.dart';
import 'package:dsa_heldenverwaltung/test_support/in_memory_cloud_avatar_storage.dart';

void main() {
  late InMemoryAvatarFileStorage local;
  late InMemoryCloudAvatarStorage cloud;
  late FakeRepository repo;

  const attributes = Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  );
  final bytes = Uint8List.fromList(<int>[1, 2, 3]);

  HeroSheet buildHero({HeroAppearance appearance = const HeroAppearance()}) {
    return HeroSheet(
      id: 'demo',
      name: 'Rondra',
      level: 1,
      attributes: attributes,
      appearance: appearance,
    );
  }

  ProviderContainer buildContainer(HeroSheet hero) {
    repo = FakeRepository(heroes: [hero]);
    local = InMemoryAvatarFileStorage();
    cloud = InMemoryCloudAvatarStorage();
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        cloudAvatarStorageProvider.overrideWithValue(cloud),
        avatarFileStorageProvider.overrideWithValue(
          SyncingAvatarStorage(local: local, cloud: cloud),
        ),
        heroStorageLocationProvider.overrideWith(
          (ref) async => const HeroStorageLocation(
            defaultPath: '/helden',
            effectivePath: '/helden',
            customPathSupported: false,
            usesCustomPath: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('uploadHeroImage laedt auch Upload-Bilder in die Cloud', () async {
    final container = buildContainer(buildHero());

    await container
        .read(heroActionsProvider)
        .uploadHeroImage(heroId: 'demo', imageBytes: bytes);

    final hero = (await repo.loadHeroById('demo'))!;
    final entry = hero.appearance.avatarGallery.single;
    expect(entry.quelle, 'upload');
    expect(cloud.objects[entry.fileName], bytes);
  });

  test('schreibt kein Legacy-Hauptbild mehr', () async {
    final container = buildContainer(buildHero());

    await container
        .read(heroActionsProvider)
        .uploadHeroImage(heroId: 'demo', imageBytes: bytes);

    expect(local.files.keys, isNot(contains('demo.png')));
    expect(cloud.objects.keys, isNot(contains('demo.png')));
    final hero = (await repo.loadHeroById('demo'))!;
    expect(hero.appearance.avatarFileName, isEmpty);
    expect(hero.appearance.hatBild, isTrue);
  });

  test('weist ein zu grosses Bild mit Hinweis ab', () async {
    final container = buildContainer(buildHero());
    final tooLarge = Uint8List(maxAvatarBildBytes + 1);

    await expectLater(
      container
          .read(heroActionsProvider)
          .uploadHeroImage(heroId: 'demo', imageBytes: tooLarge),
      throwsA(
        isA<Exception>().having((e) => e.toString(), 'Meldung', contains('MB')),
      ),
    );
    expect(local.files, isEmpty);
  });

  test('legt ohne gueltigen Dateinamen keinen Galerie-Eintrag an', () async {
    final container = buildContainer(buildHero());
    local.failSaves = true;

    await expectLater(
      container
          .read(heroActionsProvider)
          .uploadHeroImage(heroId: 'demo', imageBytes: bytes),
      throwsA(isA<Exception>()),
    );

    final hero = (await repo.loadHeroById('demo'))!;
    expect(hero.appearance.avatarGallery, isEmpty);
  });

  test('removeGalleryImage loescht auch Upload-Bilder in der Cloud', () async {
    final container = buildContainer(buildHero());
    await container
        .read(heroActionsProvider)
        .uploadHeroImage(heroId: 'demo', imageBytes: bytes);
    final entryId = (await repo.loadHeroById(
      'demo',
    ))!.appearance.avatarGallery.single.id;

    await container
        .read(heroActionsProvider)
        .removeGalleryImage(heroId: 'demo', galleryEntryId: entryId);

    expect(cloud.objects, isEmpty);
    expect(local.files, isEmpty);
  });

  test('setActiveAvatar kopiert keine Bytes mehr', () async {
    final container = buildContainer(
      buildHero(
        appearance: const HeroAppearance(
          aktivesBildId: 'a',
          avatarGallery: [
            AvatarGalleryEntry(id: 'a', fileName: 'demo_a.png'),
            AvatarGalleryEntry(id: 'b', fileName: 'demo_b.png'),
          ],
        ),
      ),
    );

    await container
        .read(heroActionsProvider)
        .setActiveAvatar(heroId: 'demo', galleryEntryId: 'b');

    final hero = (await repo.loadHeroById('demo'))!;
    expect(hero.appearance.aktivesBildId, 'b');
    expect(local.savedFileNames, isEmpty);
  });

  test('speichert lokal weiter, wenn die Cloud nicht erreichbar ist', () async {
    final container = buildContainer(buildHero());
    cloud.failUploads = true;

    await container
        .read(heroActionsProvider)
        .uploadHeroImage(heroId: 'demo', imageBytes: bytes);

    final hero = (await repo.loadHeroById('demo'))!;
    final entry = hero.appearance.avatarGallery.single;
    expect(local.files[entry.fileName], bytes);
    expect(cloud.objects, isEmpty);
  });
}
