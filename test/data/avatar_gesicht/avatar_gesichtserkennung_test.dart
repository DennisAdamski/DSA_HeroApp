import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/avatar_gesicht/avatar_gesichtserkennung.dart';
import 'package:dsa_heldenverwaltung/data/avatar_gesicht/blazeface_modell.dart';

import '../../test_support/avatar_test_image.dart';

/// Ende-zu-Ende: echtes JPEG → Dekoder → Letterbox → Netz → Befund.
///
/// Die Vorlagen sind gemeinfreie Gemaelde, siehe
/// `tool/avatar_gesicht/README.md`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fixtures = 'test/fixtures/avatar_gesicht';

  BlazeFaceGesichtserkennung erkennung() => BlazeFaceGesichtserkennung(
    ladeModell: () async => File(kBlazeFaceModellAsset).readAsBytesSync(),
  );

  test('findet das Gesicht eines Nahportraets im ersten Durchlauf', () async {
    final befund = await erkennung().erkenne(
      File('$fixtures/mona_lisa.jpg').readAsBytesSync(),
    );

    expect(befund.bildBreite, 240);
    expect(befund.bildHoehe, 358);
    final gesicht = befund.gesicht!;
    // Referenz der LiteRT-Laufzeit: (0.359, 0.191) bis (0.613, 0.361).
    expect(gesicht.links, closeTo(0.359, 0.02));
    expect(gesicht.oben, closeTo(0.191, 0.02));
    expect(gesicht.links + gesicht.breite, closeTo(0.613, 0.02));
    expect(gesicht.oben + gesicht.hoehe, closeTo(0.361, 0.02));
    expect(befund.konfidenz, greaterThan(0.85));
  });

  test('findet ein kleines Gesicht im Ganzkoerperbild ueber Kacheln', () async {
    final befund = await erkennung().erkenne(
      File('$fixtures/ludwig_xiv.jpg').readAsBytesSync(),
    );

    final gesicht = befund.gesicht!;
    // Kopf Ludwigs XIV. bei etwa (141, 116) von 300 x 426 Pixeln.
    expect(gesicht.mitteX, closeTo(141 / 300, 0.03));
    expect(gesicht.mitteY, closeTo(116 / 426, 0.03));
    expect(gesicht.breite, lessThan(0.15));
  });

  test('liefert fuer ein Bild ohne Gesicht nur die Bildgroesse', () async {
    final rauschen = await createNoisyPngBytes(width: 320, height: 200);

    final befund = await erkennung().erkenne(Uint8List.fromList(rauschen));

    expect(befund.bildBreite, 320);
    expect(befund.bildHoehe, 200);
    expect(befund.gesicht, isNull);
  });

  test('wirft bei nicht dekodierbaren Bytes', () async {
    await expectLater(
      erkennung().erkenne(Uint8List.fromList(const [1, 2, 3, 4])),
      throwsA(anything),
    );
  });

  test('das Modell-Asset ist im Bundle registriert', () async {
    final daten = await rootBundle.load(kBlazeFaceModellAsset);
    expect(daten.lengthInBytes, File(kBlazeFaceModellAsset).lengthSync());
  });
}
