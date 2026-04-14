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
    'setPrimaerbild sets primaerbildId and leaves aktivesBildId untouched',
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
              avatarFileName: 'demo.png',
              aktivesBildId: 'bild-aktiv',
              avatarGallery: [
                AvatarGalleryEntry(id: 'bild-aktiv', fileName: 'demo.png'),
                AvatarGalleryEntry(id: 'bild-neu', fileName: 'demo_neu.png'),
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
          .setPrimaerbild(heroId: 'demo', galleryEntryId: 'bild-neu');

      final hero = await repo.loadHeroById('demo');
      expect(hero, isNotNull);
      expect(hero!.appearance.primaerbildId, 'bild-neu');
      expect(hero.appearance.aktivesBildId, 'bild-aktiv');
      expect(hero.appearance.avatarFileName, 'demo.png');
      expect(hero.appearance.avatarSnapshot, isNotNull);
    },
  );
}
