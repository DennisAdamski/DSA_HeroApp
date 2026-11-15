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

const _ausgabe = String.fromEnvironment('HELDENSIEGEL_PREVIEW_DIR');

/// Prüft alle Motiv-/Befähigungskombinationen und exportiert optional die Vorschau.
void main() {
  setUpAll(ladeKartoSchriften);

  testWidgets(
    'alle Grundmotive bleiben auch ohne übernatürliche Befähigung sichtbar',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bild = GlobalKey();
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
                      'Heldensiegel',
                      style: TextStyle(fontSize: 28, fontFamily: 'Spectral'),
                    ),
                    const Text('Jeweils: profan · astral · karmal · beides'),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final motiv in KartoSiegelMotiv.values)
                          SizedBox(
                            width: 252,
                            height: 188,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _namen[motiv]!,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontFamily: 'Spectral',
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        for (final flags in [
                                          (false, false),
                                          (true, false),
                                          (false, true),
                                          (true, true),
                                        ])
                                          KartoHeldensiegel(
                                            groesse: 50,
                                            profil: KartoSiegelProfil(
                                              motiv: motiv,
                                              magisch: flags.$1,
                                              karmal: flags.$2,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
      await tester.pumpAndSettle();
      expect(find.byType(KartoHeldensiegel), findsNWidgets(32));
      expect(tester.takeException(), isNull);
      if (_ausgabe.isNotEmpty) {
        final boundary =
            bild.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(_ausgabe).create(recursive: true);
            await File('$_ausgabe/motive.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }
    },
  );
}

const _namen = {
  KartoSiegelMotiv.neutral: 'Neutral',
  KartoSiegelMotiv.mensch: 'Menschen',
  KartoSiegelMotiv.elf: 'Elfen',
  KartoSiegelMotiv.halbelf: 'Halbelfen',
  KartoSiegelMotiv.zwerg: 'Zwerge',
  KartoSiegelMotiv.echse: 'Echsenwesen',
  KartoSiegelMotiv.ork: 'Orks',
  KartoSiegelMotiv.goblin: 'Goblins',
};
