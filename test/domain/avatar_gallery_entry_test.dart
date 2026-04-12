import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';

void main() {
  test('roundtrip stores optional header focus values', () {
    const entry = AvatarGalleryEntry(
      id: 'bild-1',
      fileName: 'bild.png',
      quelle: 'upload',
      headerFocusX: 0.2,
      headerFocusY: 0.8,
    );

    final restored = AvatarGalleryEntry.fromJson(entry.toJson());

    expect(restored.headerFocusX, 0.2);
    expect(restored.headerFocusY, 0.8);
  });

  test('fromJson clamps header focus values into normalized range', () {
    final restored = AvatarGalleryEntry.fromJson(const {
      'id': 'bild-1',
      'fileName': 'bild.png',
      'headerFocusX': -3,
      'headerFocusY': 9,
    });

    expect(restored.headerFocusX, 0);
    expect(restored.headerFocusY, 1);
  });
}
