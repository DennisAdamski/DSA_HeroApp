import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prüft, dass die vorbereiteten UI-Assets gebündelt und transparent lesbar sind.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const names = <String>[
    'hero',
    'combat',
    'talents',
    'magic',
    'liturgies',
    'inventory',
    'companion',
    'adventure',
    'notes',
    'advancement',
    'vitality',
    'dice',
    'hero_crest',
    'chapter_ornament',
    'adventure_book',
  ];

  for (final name in names) {
    test(
      'Fantasy-Asset $name lädt mit sichtbarem Motiv und Transparenz',
      () async {
        final data = await rootBundle.load('assets/ui/fantasy_v1/$name.png');
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final image = frame.image;

        try {
          expect(image.width, greaterThanOrEqualTo(256));
          expect(image.height, greaterThanOrEqualTo(256));
          final pixels = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          expect(pixels, isNotNull);
          final rgba = pixels!.buffer.asUint8List(
            pixels.offsetInBytes,
            pixels.lengthInBytes,
          );
          var transparent = 0;
          var visible = 0;
          for (var offset = 3; offset < rgba.length; offset += 4) {
            final alpha = rgba[offset];
            if (alpha == 0) transparent++;
            if (alpha > 0) visible++;
          }
          // Ein transparenter Rand allein genügt nicht: das Motiv muss Inhalt tragen.
          expect(transparent, greaterThan(rgba.length ~/ 40));
          expect(visible, greaterThan(rgba.length ~/ 400));
        } finally {
          image.dispose();
          codec.dispose();
        }
      },
    );
  }
}
