import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_papier.dart';

import '../theme/karto_test_fonts.dart';
import 'karto_acceptance_support.dart';
import 'karto_test_support.dart';

// Opt-in wie das R3-Raster: echte Rasterbilder, keine Pixelvergleiche.
const _screenshotDirectory = String.fromEnvironment('R3_SCREENSHOT_DIR');

/// Abnahmeraster der uebrigen Seiten: alle Tabs der Verwaltung.
///
/// Laeuft ueber Breiten, Helligkeiten und Schriftgroessen und prueft, dass
/// nichts ueberlaeuft. Mit `--dart-define=R3_SCREENSHOT_DIR=...` legt es fuer
/// die Sichtpruefung Aufnahmen ab.
void main() {
  setUpAll(() async {
    await ladeKartoSchriften();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  HeroSheet held() => testHero().copyWith(
    name: 'Rondra Alrike von Gareth und den Silberquellen',
    apAvailable: 1375,
    apTotal: 1875,
    background: const HeroBackground(
      rasse: 'Mittelländer',
      kultur: 'Mittelreich',
      profession: 'Reisende Gelehrte',
      familieHerkunftHintergrund:
          'Eine Chronistin auf dem Weg durch das Mittelreich.',
    ),
    vorteileText: 'Gutes Gedächtnis',
    nachteileText: 'Neugier',
    resourceActivationConfig: const HeroResourceActivationConfig(
      magicEnabledOverride: true,
      divineEnabledOverride: true,
    ),
    inventoryEntries: const [
      HeroInventoryEntry(
        gegenstand: 'Reisetagebuch',
        anzahl: '1',
        woGetragen: 'Rucksack',
        beschreibung: 'Notizen, Karten und Begegnungen.',
      ),
      HeroInventoryEntry(
        gegenstand: 'Wolldecke',
        anzahl: '12',
        woGetragen: 'Rucksack',
      ),
    ],
    notes: const [
      HeroNoteEntry(
        title: 'Ankunft in Gareth',
        description: 'Am Praiostag treffen wir die Reisegruppe.',
      ),
    ],
  );

  const tabs = <String>[
    'Übersicht',
    'Talente',
    'Kampf',
    'Magie',
    'Inventar',
    'Chroniken, Kontakte & Abenteuer',
    'Reisebericht',
    'Begleiter',
    'Gruppe',
  ];

  for (final width in [390.0, 1024.0, 1440.0]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Verwaltung $width dp, ${brightness.name}, Text $scale', (
          tester,
        ) async {
          final screenshotKey = GlobalKey();
          final hero = held();
          await pumpAcceptanceWorkspace(
            tester,
            repository: AcceptanceRepository(
              heroes: [hero],
              states: {
                hero.id: const HeroState(
                  currentLep: 27,
                  currentAsp: 18,
                  currentKap: 12,
                  currentAu: 22,
                ),
              },
            ),
            selectedHeroId: hero.id,
            size: Size(width, 1000),
            textScale: scale,
            brightness: brightness,
            screenshotKey: screenshotKey,
          );
          await selectAcceptanceMode(tester, 'Held verwalten');
          final capture =
              scale == 1 &&
              ((brightness == Brightness.light &&
                      (width == 390 || width == 1440)) ||
                  (brightness == Brightness.dark && width == 1024));
          for (final tab in tabs) {
            final reiter = find.widgetWithText(Tab, tab);
            expect(reiter, findsOneWidget, reason: tab);
            await tester.ensureVisible(reiter);
            await tester.tap(reiter);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: tab);
            if (capture) {
              await _capture(
                tester,
                screenshotKey,
                'verwalten-${_dateiname(tab)}-${width.toInt()}-'
                '${brightness.name}',
              );
            }
          }
        }, tags: ['r3-acceptance']);
      }
    }
  }
}

String _dateiname(String tab) => tab
    .toLowerCase()
    .replaceAll('ü', 'ue')
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll(RegExp('[^a-z]+'), '-')
    .replaceAll(RegExp(r'-+$'), '');

// Rasterisiert genau den gezeichneten Flutter-Frame samt Navigator und Dialogen.
Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String name,
) async {
  if (_screenshotDirectory.isEmpty) return;
  await tester.runAsync(
    () => precacheImage(KartoPapier.textur, boundaryKey.currentContext!),
  );
  await tester.pumpAndSettle();
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory(_screenshotDirectory);
      await directory.create(recursive: true);
      await File('${directory.path}/$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
