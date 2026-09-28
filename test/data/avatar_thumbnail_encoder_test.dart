import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/avatar_thumbnail_encoder.dart';
import 'package:dsa_heldenverwaltung/domain/held_visitenkarte.dart';

import '../test_support/avatar_test_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AvatarThumbnailEncoder', () {
    test('creates a compact thumbnail below the Firestore limit', () async {
      final sourceBytes = await createNoisyPngBytes();
      final encoder = const AvatarThumbnailEncoder();

      final originalBase64 = base64Encode(sourceBytes);
      final thumbnailBase64 = await encoder.createThumbnailBase64(
        imageBytes: sourceBytes,
      );

      expect(
        originalBase64.length,
        greaterThan(HeldVisitenkarte.avatarThumbnailBase64MaxLength),
      );
      expect(thumbnailBase64, isNotNull);
      expect(
        thumbnailBase64!.length,
        lessThanOrEqualTo(HeldVisitenkarte.avatarThumbnailBase64MaxLength),
      );
      expect(thumbnailBase64, isNot(originalBase64));

      final thumbnailImage = await decodePngBytes(
        base64Decode(thumbnailBase64),
      );
      addTearDown(thumbnailImage.dispose);
      expect(thumbnailImage.width, lessThanOrEqualTo(128));
      expect(thumbnailImage.height, lessThanOrEqualTo(128));
    });

    test('crops the centre square instead of squashing the image', () async {
      // Links rot, Mitte gruen, rechts blau: ein gestauchtes Bild zeigte alle
      // drei Streifen, das mittige Quadrat nur Gruen.
      final sourceBytes = await createStripedPngBytes(
        width: 300,
        height: 100,
        stripes: const [0xFFFF0000, 0xFF00FF00, 0xFF0000FF],
      );
      final encoder = const AvatarThumbnailEncoder();

      final thumbnailBase64 = await encoder.createThumbnailBase64(
        imageBytes: sourceBytes,
      );

      final thumbnail = await decodePngBytes(base64Decode(thumbnailBase64!));
      addTearDown(thumbnail.dispose);
      expect(thumbnail.width, 128);
      expect(thumbnail.height, 128);
      final pixels = await readRgbaPixels(thumbnail);
      for (final x in const [4, 64, 123]) {
        final color = pixelAt(pixels, thumbnail.width, x, 64);
        expect(color, 0xFF00FF00, reason: 'Spalte $x');
      }
    });

    test('uses the given face crop', () async {
      final sourceBytes = await createStripedPngBytes(
        width: 300,
        height: 100,
        stripes: const [0xFFFF0000, 0xFF00FF00, 0xFF0000FF],
      );
      final encoder = const AvatarThumbnailEncoder();

      final thumbnailBase64 = await encoder.createThumbnailBase64(
        imageBytes: sourceBytes,
        ausschnitt: (links: 0.7, oben: 0.0, breite: 0.3, hoehe: 0.9),
      );

      final thumbnail = await decodePngBytes(base64Decode(thumbnailBase64!));
      addTearDown(thumbnail.dispose);
      final pixels = await readRgbaPixels(thumbnail);
      expect(pixelAt(pixels, thumbnail.width, 64, 64), 0xFF0000FF);
    });

    test('returns null for invalid image bytes', () async {
      final encoder = const AvatarThumbnailEncoder();

      final thumbnailBase64 = await encoder.createThumbnailBase64(
        imageBytes: const <int>[1, 2, 3, 4],
      );

      expect(thumbnailBase64, isNull);
    });
  });
}
