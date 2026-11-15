import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/theme/karto_heldensiegel_profil.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_heldensiegel.dart';

/// Die produktiven Siegel sind gebündelte Bilder mit echten Alphakanten.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pfade = {
    for (final motiv in KartoSiegelMotiv.values)
      KartoSiegelProfil(motiv: motiv).assetPfad!,
    for (final kultur in KartoSiegelKultur.values)
      KartoSiegelProfil(
        motiv: KartoSiegelMotiv.mensch,
        kultur: kultur,
      ).assetPfad!,
  };
  test('zwölf Kulturen und acht Grundmotive haben eindeutige Bilddateien', () {
    expect(pfade, hasLength(20));
  });
  for (final pfad in pfade) {
    final name = pfad.split('/').last;
    test(
      '$name ist gebündelt, ausreichend groß und wirklich transparent',
      () async {
        final data = await rootBundle.load(pfad);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        try {
          final frame = await codec.getNextFrame();
          try {
            expect(frame.image.width, greaterThanOrEqualTo(512));
            expect(frame.image.height, greaterThanOrEqualTo(512));
            final rgba = await frame.image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final bytes = rgba!.buffer.asUint8List();
            var transparent = 0;
            var sichtbar = 0;
            for (var i = 3; i < bytes.length; i += 4) {
              if (bytes[i] == 0) transparent++;
              if (bytes[i] > 0) sichtbar++;
            }
            final pixel = frame.image.width * frame.image.height;
            expect(transparent / pixel, greaterThan(0.03));
            expect(sichtbar / pixel, greaterThan(0.3));
            expect(bytes[3], 0, reason: 'Keine rechteckige Hintergrundfläche');
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
      },
    );
  }

  testWidgets(
    'unterstützte Kulturen werden als farbiges Bild statt Linienmotiv angezeigt',
    (tester) async {
      final profil = KartoSiegelProfil.ausAngaben(
        rasse: 'Mensch',
        kultur: 'Thorwal',
        magisch: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: KartoHeldensiegel(profil: profil, groesse: 48)),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
      final bild = tester.widget<Image>(find.byType(Image));
      expect(bild.fit, BoxFit.contain);
      expect(bild.color, isNull);
      expect(bild.excludeFromSemantics, isTrue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
