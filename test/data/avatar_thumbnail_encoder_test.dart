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

    test('returns null for invalid image bytes', () async {
      final encoder = const AvatarThumbnailEncoder();

      final thumbnailBase64 = await encoder.createThumbnailBase64(
        imageBytes: const <int>[1, 2, 3, 4],
      );

      expect(thumbnailBase64, isNull);
    });
  });
}
