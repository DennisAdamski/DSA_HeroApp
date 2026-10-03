import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import '../shell/karto_test_support.dart';
import '../theme/karto_test_fonts.dart';
import 'gefecht_test_support.dart';

void main() {
  setUpAll(() async {
    await ladeKartoSchriften();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final breite in [390.0, 820.0, 1200.0, 1440.0]) {
    for (final helligkeit in Brightness.values) {
      testWidgets('Gefecht mit INI 40+ und Popups: $breite $helligkeit', (
        tester,
      ) async {
        tester.view.physicalSize = Size(breite, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final katalog = RulesCatalog(
          version: 'test',
          source: 'test',
          talents: [],
          spells: [],
          weapons: [],
          maneuvers: [
            for (final name in ['Finte', 'Wuchtschlag', 'Hammerschlag'])
              ManeuverDef.fromJson({
                'id': 'man_${name.toLowerCase()}',
                'name': name,
                'muss_separat_erlernt_werden': name == 'Hammerschlag',
              }),
          ],
        );
        final snapshot = buildHeroComputedSnapshot(
          hero: testHero().copyWith(
            talents: {
              'tal_schwerter': const HeroTalentEntry(
                talentValue: 12,
                atValue: 7,
                paValue: 5,
              ),
            },
            combatConfig: const CombatConfig(
              weapons: [
                MainWeaponSlot(
                  id: 'w1',
                  name: 'Langschwert',
                  talentId: 'tal_schwerter',
                  distanceClass: 'NS',
                  tpFlat: 4,
                  kkBase: 12,
                  kkThreshold: 4,
                ),
                MainWeaponSlot(id: 'w2', name: 'Dolch', distanceClass: 'H'),
              ],
              armor: ArmorConfig(
                pieces: [
                  ArmorPiece(
                    id: 'a1',
                    name: 'Kettenhemd',
                    isActive: true,
                    be: 2,
                    rs: 4,
                  ),
                ],
              ),
              manualMods: CombatManualMods(iniMod: 35),
            ),
          ),
          state: const HeroState(
            currentLep: 30,
            currentAsp: 0,
            currentKap: 0,
            currentAu: 30,
          ),
          epicAdvantagesActive: false,
          catalog: katalog,
        );
        final container = ProviderContainer(
          overrides: [
            heroComputedProvider('rondra')
                .overrideWith((ref) => AsyncData(snapshot)),
            rulesCatalogProvider.overrideWith((ref) async => katalog),
          ],
        );
        addTearDown(container.dispose);
        container.read(gefechtProvider('rondra').notifier).beginnen(6);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: buildKartoTheme(
                  brightness: helligkeit,
                  centerAppBarTitle: false,
                ),
                home: GefechtAnsicht(
                  heroId: 'rondra',
                  bestand: GefechtsTestBestand(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await captureGefechtsTestbild(
          tester,
          boundary,
          '${breite.toInt()}-${helligkeit.name}',
        );
        await tester.ensureVisible(find.text('Wechseln'));
        await tester.tap(find.text('Wechseln'));
        await tester.pumpAndSettle();
        expect(find.text('Ausrüstung wechseln'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await captureGefechtsTestbild(
          tester,
          boundary,
          '${breite.toInt()}-${helligkeit.name}-ausruestung',
        );
        await tester.tap(find.text('Schließen'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Angreifen'));
        await tester.tap(find.text('Angreifen'));
        await tester.pumpAndSettle();
        expect(find.text('Aktuelle Distanzklasse'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await captureGefechtsTestbild(
          tester,
          boundary,
          '${breite.toInt()}-${helligkeit.name}-aktion',
        );
      });
    }
  }
}

/// Opt-in Rasteraufnahmen für Gefechtsszenen ohne produktiven Exportpfad.
Future<void> captureGefechtsTestbild(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  const pfad = String.fromEnvironment('GEFECHT_SCREENSHOT_DIR');
  if (pfad.isEmpty) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(pfad).create(recursive: true);
      await File('$pfad/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
