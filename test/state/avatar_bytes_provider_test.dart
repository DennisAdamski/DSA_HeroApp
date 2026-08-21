import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/avatar_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/test_support/in_memory_avatar_file_storage.dart';

void main() {
  late InMemoryAvatarFileStorage storage;

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
  final bytes = Uint8List.fromList(<int>[4, 5, 6]);

  ProviderContainer buildContainer(HeroAppearance appearance) {
    storage = InMemoryAvatarFileStorage();
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(
          FakeRepository(
            heroes: [
              HeroSheet(
                id: 'demo',
                name: 'Rondra',
                level: 1,
                attributes: attributes,
                appearance: appearance,
              ),
            ],
          ),
        ),
        avatarFileStorageProvider.overrideWithValue(storage),
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

  /// Wartet, bis `heroByIdProvider` den Helden aufloesen kann.
  Future<void> awaitHeroIndex(ProviderContainer container) async {
    final sub = container.listen<AsyncValue<List<HeroSheet>>>(
      heroListProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    for (var attempt = 0; attempt < 20 && !sub.read().hasValue; attempt++) {
      await container.pump();
    }
    expect(sub.read().hasValue, isTrue);
  }

  test('liefert dieselbe Instanz bei wiederholtem Lesen', () async {
    final container = buildContainer(const HeroAppearance());
    storage.files['demo_a.png'] = bytes;

    const key = (heroId: 'demo', fileName: 'demo_a.png');
    final first = await container.read(avatarBytesProvider(key).future);
    final second = await container.read(avatarBytesProvider(key).future);

    expect(
      first,
      same(second),
      reason: 'sonst verfehlt Image.memory den Cache',
    );
  });

  test('liefert null statt zu werfen, wenn das Bild fehlt', () async {
    final container = buildContainer(const HeroAppearance());

    final loaded = await container.read(
      avatarBytesProvider((heroId: 'demo', fileName: 'fehlt.png')).future,
    );

    expect(loaded, isNull);
  });

  test('aktives Bild folgt aktivesBildId', () async {
    final container = buildContainer(
      const HeroAppearance(
        aktivesBildId: 'b',
        avatarGallery: [
          AvatarGalleryEntry(id: 'a', fileName: 'demo_a.png'),
          AvatarGalleryEntry(id: 'b', fileName: 'demo_b.png'),
        ],
      ),
    );
    storage.files['demo_b.png'] = bytes;

    await awaitHeroIndex(container);
    final loaded = await container.read(
      activeAvatarBytesProvider('demo').future,
    );

    expect(loaded, bytes);
  });

  test('faellt bei Bestandshelden auf avatarFileName zurueck', () async {
    final container = buildContainer(
      const HeroAppearance(
        avatarFileName: 'demo.png',
        avatarGallery: [
          AvatarGalleryEntry(id: 'demo_legacy', fileName: 'demo.png'),
        ],
      ),
    );
    storage.files['demo.png'] = bytes;

    await awaitHeroIndex(container);
    final loaded = await container.read(
      activeAvatarBytesProvider('demo').future,
    );

    expect(loaded, bytes);
  });

  test('faellt zuletzt auf das Primaerbild zurueck', () async {
    final container = buildContainer(
      const HeroAppearance(
        primaerbildId: 'p',
        avatarGallery: [AvatarGalleryEntry(id: 'p', fileName: 'demo_p.png')],
      ),
    );
    storage.files['demo_p.png'] = bytes;

    await awaitHeroIndex(container);
    final loaded = await container.read(
      activeAvatarBytesProvider('demo').future,
    );

    expect(loaded, bytes);
  });

  test('ohne Galerie kein aktives Bild', () async {
    final container = buildContainer(const HeroAppearance());

    await awaitHeroIndex(container);
    final loaded = await container.read(
      activeAvatarBytesProvider('demo').future,
    );

    expect(loaded, isNull);
  });
}
