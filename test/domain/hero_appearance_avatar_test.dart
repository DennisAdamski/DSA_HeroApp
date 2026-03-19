import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HeroAppearance avatarFileName', () {
    test('roundtrip mit avatarFileName', () {
      const appearance = HeroAppearance(
        geschlecht: 'maennlich',
        haarfarbe: 'schwarz',
        avatarFileName: 'abc-123.png',
      );
      final json = appearance.toJson();
      final restored = HeroAppearance.fromJson(json);

      expect(restored.avatarFileName, 'abc-123.png');
      expect(restored.geschlecht, 'maennlich');
      expect(restored.haarfarbe, 'schwarz');
    });

    test('fromJson ohne avatarFileName liefert leeren String', () {
      final appearance = HeroAppearance.fromJson(const {
        'geschlecht': 'weiblich',
        'haarfarbe': 'blond',
      });

      expect(appearance.avatarFileName, '');
      expect(appearance.geschlecht, 'weiblich');
    });

    test('fromJson mit komplett leerer Map', () {
      final appearance = HeroAppearance.fromJson(const {});

      expect(appearance.avatarFileName, '');
      expect(appearance.geschlecht, '');
    });

    test('copyWith avatarFileName', () {
      const original = HeroAppearance(avatarFileName: 'alt.png');
      final updated = original.copyWith(avatarFileName: 'neu.png');

      expect(updated.avatarFileName, 'neu.png');
    });

    test('copyWith ohne avatarFileName behaelt Wert', () {
      const original = HeroAppearance(avatarFileName: 'behalten.png');
      final updated = original.copyWith(geschlecht: 'divers');

      expect(updated.avatarFileName, 'behalten.png');
      expect(updated.geschlecht, 'divers');
    });
  });
}
