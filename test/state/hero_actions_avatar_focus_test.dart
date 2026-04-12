import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

void main() {
  test(
    'setAvatarHeaderFocus stores normalized focus values on the gallery entry',
    () async {
      final repo = FakeRepository(
        heroes: [
          const HeroSheet(
            id: 'demo',
            name: 'Rondra',
            level: 1,
            attributes: Attributes(
              mu: 12,
              kl: 12,
              inn: 12,
              ch: 12,
              ff: 12,
              ge: 12,
              ko: 12,
              kk: 12,
            ),
            appearance: HeroAppearance(
              primaerbildId: 'bild-1',
              avatarGallery: [
                AvatarGalleryEntry(id: 'bild-1', fileName: 'demo_bild-1.png'),
              ],
            ),
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [heroRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container
          .read(heroActionsProvider)
          .setAvatarHeaderFocus(
            heroId: 'demo',
            galleryEntryId: 'bild-1',
            focusX: 1.3,
            focusY: -0.4,
          );

      final hero = await repo.loadHeroById('demo');
      expect(hero, isNotNull);
      final entry = hero!.appearance.avatarGallery.single;
      expect(entry.headerFocusX, 1);
      expect(entry.headerFocusY, 0);
    },
  );
}
