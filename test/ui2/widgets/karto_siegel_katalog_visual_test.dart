import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/theme/karto_heldensiegel_profil.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_heldensiegel.dart';

import '../theme/karto_test_fonts.dart';

const _ausgabe = String.fromEnvironment('SIEGEL_ASSET_PREVIEW_DIR');

/// Prüft und exportiert den vollständigen produktiven Bildsatz in Anzeigegrößen.
void main() {
  setUpAll(ladeKartoSchriften);

  testWidgets('alle Bildmotive passen auf helle und dunkle Flächen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1120, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bild = GlobalKey();
    final profile = [
      for (final kultur in KartoSiegelKultur.values)
        KartoSiegelProfil(motiv: KartoSiegelMotiv.mensch, kultur: kultur),
      for (final motiv in KartoSiegelMotiv.values)
        KartoSiegelProfil(motiv: motiv),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKartoTheme(
          brightness: Brightness.light,
          centerAppBarTitle: false,
        ),
        home: Scaffold(
          body: RepaintBoundary(
            key: bild,
            child: Container(
              color: kartoHell.blatt,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vollständiger Siegelsatz',
                    style: TextStyle(fontSize: 28, fontFamily: 'Spectral'),
                  ),
                  const Text(
                    'Zwölf Kulturen und acht Grundmotive · darunter jeweils 40 Pixel auf hell und dunkel',
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final profil in profile)
                        SizedBox(
                          width: 204,
                          height: 228,
                          child: _Katalogkarte(profil: profil),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final context = tester.element(find.byType(Scaffold));
    final bilder = tester.widgetList<Image>(find.byType(Image));
    final quellen = bilder.map((bild) => bild.image).toSet();
    await tester.runAsync(
      () => Future.wait([
        for (final quelle in quellen) precacheImage(quelle, context),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.byType(KartoHeldensiegel), findsNWidgets(60));
    expect(tester.takeException(), isNull);
    if (_ausgabe.isNotEmpty) {
      final boundary =
          bild.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(_ausgabe).create(recursive: true);
          await File('$_ausgabe/alle-siegel.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }
  });
}

// Dieselbe Darstellung pro Motiv macht kleine Silhouetten und Kontraste vergleichbar.
class _Katalogkarte extends StatelessWidget {
  const _Katalogkarte({required this.profil});

  final KartoSiegelProfil profil;

  @override
  Widget build(BuildContext context) {
    final grundname = switch (profil.motiv) {
      KartoSiegelMotiv.neutral => 'Neutral',
      KartoSiegelMotiv.mensch => 'Menschen',
      KartoSiegelMotiv.elf => 'Elfen',
      KartoSiegelMotiv.halbelf => 'Halbelfen',
      KartoSiegelMotiv.zwerg => 'Zwerge',
      KartoSiegelMotiv.echse => 'Achaz',
      KartoSiegelMotiv.ork => 'Orks',
      KartoSiegelMotiv.goblin => 'Goblins',
    };
    final beschriftung =
        profil.kultur?.beschreibung.replaceFirst(' Kultursiegel', '') ??
        grundname;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            SizedBox(
              height: 36,
              child: Text(
                beschriftung,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontFamily: 'Spectral'),
              ),
            ),
            KartoHeldensiegel(profil: profil, groesse: 112),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                KartoHeldensiegel(profil: profil, groesse: 40),
                ColoredBox(
                  color: kartoHell.navigation,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: KartoHeldensiegel(profil: profil, groesse: 40),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
