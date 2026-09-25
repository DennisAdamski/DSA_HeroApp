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
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_catalog.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_papier.dart';

import '../theme/karto_test_fonts.dart';
import 'karto_acceptance_support.dart';
import 'karto_test_support.dart';

// Opt-in: echte Flutter-Rasterbilder, keine fragilen Pixel-Golden-Vergleiche.
const _screenshotDirectory = String.fromEnvironment('R3_SCREENSHOT_DIR');

void main() {
  setUpAll(() async {
    await ladeKartoSchriften();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final width in [320.0, 390.0, 744.0, 768.0, 1024.0, 1366.0, 1440.0]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('R3 Raster $width dp, ${brightness.name}, Text $scale', (
          tester,
        ) async {
          final screenshotKey = GlobalKey();
          final hero = testHero().copyWith(
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
                anzahl: '1',
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
          final repository = AcceptanceRepository(
            heroes: [hero],
            states: {
              hero.id: const HeroState(
                currentLep: 27,
                currentAsp: 18,
                currentKap: 12,
                currentAu: 22,
              ),
            },
          );
          await pumpAcceptanceWorkspace(
            tester,
            repository: repository,
            selectedHeroId: hero.id,
            size: Size(width, 1000),
            textScale: scale,
            brightness: brightness,
            screenshotKey: screenshotKey,
          );
          final capture =
              scale == 1 &&
              ((brightness == Brightness.light &&
                      (width == 390 || width == 1440)) ||
                  (brightness == Brightness.dark && width == 1024));
          final suffix = '${width.toInt()}-${brightness.name}';
          expect(tester.takeException(), isNull);
          if (capture) {
            await _capture(tester, screenshotKey, 'spielen-$suffix');
          }

          await selectAcceptanceMode(tester, 'Held verwalten');
          expect(find.widgetWithText(Tab, 'Übersicht'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (capture) {
            await _capture(tester, screenshotKey, 'verwaltung-$suffix');
          }

          final inventoryTab = find.widgetWithText(Tab, 'Inventar');
          await tester.ensureVisible(inventoryTab);
          await tester.tap(inventoryTab);
          await tester.pumpAndSettle();
          expect(find.text('Reisetagebuch'), findsWidgets);
          expect(tester.takeException(), isNull);
          if (capture) {
            await _capture(tester, screenshotKey, 'inventar-$suffix');
          }

          await selectAcceptanceMode(tester, 'Entwicklung planen');
          final planAction = find.byKey(
            const ValueKey('advancement-plan-attribute-mu'),
          );
          await tester.scrollUntilVisible(
            planAction,
            220,
            scrollable: find
                .descendant(
                  of: find.byType(AdvancementCatalog),
                  matching: find.byType(Scrollable),
                )
                .last,
          );
          // scrollUntilVisible hält an, sobald der Finder greift — die ListView
          // baut aber über den sichtbaren Bereich hinaus. Ohne ensureVisible
          // läge die Aktion bei großer Schrift außerhalb des Fensters.
          await tester.ensureVisible(planAction);
          await tester.pumpAndSettle();
          await tester.tap(planAction);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Vormerken'));
          await tester.tap(find.text('Vormerken'));
          await tester.pumpAndSettle();
          expect(repository.heroWrites, isEmpty);
          expect(tester.takeException(), isNull);
          if (capture) {
            await _capture(tester, screenshotKey, 'planung-$suffix');
          }
          final details = find.text('AP und Historie');
          if (details.evaluate().isNotEmpty) {
            await tester.ensureVisible(details);
            await tester.tap(details);
            await tester.pumpAndSettle();
            expect(find.text('Laufende Runde'), findsOneWidget);
            expect(tester.takeException(), isNull);
            if (capture) {
              await _capture(tester, screenshotKey, 'plan-details-$suffix');
            }
          }
        }, tags: ['r3-acceptance']);
      }
    }
  }
}

// Rasterisiert genau den gezeichneten Flutter-Frame samt Navigator und Dialogen.
Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String name,
) async {
  if (_screenshotDirectory.isEmpty) return;
  // Die Papiertextur laedt als Asset asynchron; ohne echtes Warten fehlte
  // sie im Rasterbild, obwohl sie in der App sichtbar ist.
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
