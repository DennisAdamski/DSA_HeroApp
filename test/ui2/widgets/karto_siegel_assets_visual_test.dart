import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_bewegung.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_heldenmarke.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spieltisch_siegel.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_heldensiegel_profil.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_heldensiegel.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_seitenkopf.dart';

import '../theme/karto_test_fonts.dart';

const _ausgabe = String.fromEnvironment('SIEGEL_ASSET_PREVIEW_DIR');

/// Zeigt dieselben produktiven Widgets auf beiden Flächen und in kleinen Größen.
void main() {
  setUpAll(ladeKartoSchriften);

  testWidgets('Bildsiegel passen in Header, Porträt und kleine Anzeigen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1120, 670);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bild = GlobalKey();
    final profile = {
      'Thorwaler': KartoSiegelProfil.ausAngaben(
        rasse: 'Mensch',
        kultur: 'Thorwal',
      ),
      'Norbarden': KartoSiegelProfil.ausAngaben(
        rasse: 'Mensch',
        kultur: 'Norbarden',
      ),
      'Novadis': KartoSiegelProfil.ausAngaben(
        rasse: 'Mensch',
        kultur: 'Novadis',
      ),
      'Achaz': KartoSiegelProfil.ausAngaben(rasse: 'Achaz'),
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKartoTheme(
          brightness: Brightness.light,
          centerAppBarTitle: false,
        ),
        home: KartoEffektEinstellungen(
          animationen: false,
          dekorativeEffekte: false,
          child: Scaffold(
            body: RepaintBoundary(
              key: bild,
              child: Container(
                color: kartoHell.blatt,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bildsiegel im Heldenbogen',
                      style: TextStyle(fontSize: 28, fontFamily: 'Spectral'),
                    ),
                    const Text(
                      'Produktive Widgets · darunter jeweils 32 / 40 / 48 Pixel',
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final eintrag in profile.entries) ...[
                          Expanded(
                            child: _Vorschau(
                              name: eintrag.key,
                              profil: eintrag.value,
                            ),
                          ),
                          if (eintrag.key != profile.keys.last)
                            const SizedBox(width: 12),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final context = tester.element(find.byType(Scaffold));
    await tester.runAsync(() async {
      for (final profil in profile.values) {
        await precacheImage(AssetImage(profil.assetPfad!), context);
      }
    });
    await tester.pumpAndSettle();
    expect(find.byType(KartoHeldenmarke), findsNWidgets(4));
    expect(tester.takeException(), isNull);
    if (_ausgabe.isNotEmpty) {
      final boundary =
          bild.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(_ausgabe).create(recursive: true);
          await File('$_ausgabe/erste-vier.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }
  });
}

// Pro Kultur zeigen identische Widgets die tatsächlichen Einbaugrößen.
class _Vorschau extends StatelessWidget {
  const _Vorschau({required this.name, required this.profil});

  final String name;
  final KartoSiegelProfil profil;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          name,
          style: const TextStyle(fontSize: 22, fontFamily: 'Spectral'),
        ),
        const SizedBox(height: 12),
        KartoHeldensiegel(profil: profil, groesse: 120),
        const SizedBox(height: 16),
        KartoSeitenkopf(
          titel: 'Am Spieltisch',
          kompakt: true,
          titelVorsatz: KartoSpieltischSiegel(profil: profil, groesse: 48),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final groesse in [32.0, 40.0, 48.0])
              KartoHeldensiegel(profil: profil, groesse: groesse),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          color: kartoHell.navigation,
          padding: const EdgeInsets.all(16),
          child: KartoHeldenmarke(name: 'Held', herkunft: name, siegel: profil),
        ),
      ],
    );
  }
}
