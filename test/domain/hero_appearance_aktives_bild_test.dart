import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';

void main() {
  group('HeroAppearance.aktivesBildId', () {
    test('roundtrip via toJson/fromJson', () {
      const appearance = HeroAppearance(
        avatarFileName: 'demo.png',
        avatarGallery: [
          AvatarGalleryEntry(id: 'bild-1', fileName: 'demo_bild-1.png'),
          AvatarGalleryEntry(id: 'bild-2', fileName: 'demo_bild-2.png'),
        ],
        primaerbildId: 'bild-1',
        aktivesBildId: 'bild-2',
      );

      final restored = HeroAppearance.fromJson(appearance.toJson());

      expect(restored.aktivesBildId, 'bild-2');
      expect(restored.primaerbildId, 'bild-1');
    });

    test('migration: avatarFileName matches gallery entry sets aktivesBildId',
        () {
      final restored = HeroAppearance.fromJson({
        'avatarFileName': 'demo_bild-2.png',
        'avatarGallery': [
          {'id': 'bild-1', 'fileName': 'demo_bild-1.png'},
          {'id': 'bild-2', 'fileName': 'demo_bild-2.png'},
        ],
      });

      expect(restored.aktivesBildId, 'bild-2');
    });

    test(
        'migration: no avatarFileName match falls back to primaerbildId',
        () {
      final restored = HeroAppearance.fromJson({
        'avatarFileName': 'fremd.png',
        'avatarGallery': [
          {'id': 'bild-1', 'fileName': 'demo_bild-1.png'},
          {'id': 'bild-2', 'fileName': 'demo_bild-2.png'},
        ],
        'primaerbildId': 'bild-2',
      });

      expect(restored.aktivesBildId, 'bild-2');
    });

    test('migration: no match anywhere falls back to first gallery entry', () {
      final restored = HeroAppearance.fromJson({
        'avatarGallery': [
          {'id': 'bild-1', 'fileName': 'demo_bild-1.png'},
          {'id': 'bild-2', 'fileName': 'demo_bild-2.png'},
        ],
      });

      expect(restored.aktivesBildId, 'bild-1');
    });

    test('empty gallery keeps aktivesBildId empty', () {
      final restored = HeroAppearance.fromJson(const {});
      expect(restored.aktivesBildId, '');
      expect(restored.avatarGallery, isEmpty);
    });
  });
}
