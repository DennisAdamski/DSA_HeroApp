import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_angriff.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_laden_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_aktionsdialog.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ladedialog.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import '../../rules/gefecht_laden_rules_test.dart' as fixture;
import '../shell/karto_test_support.dart';
import '../theme/karto_test_fonts.dart';
import 'gefecht_test_support.dart';
import 'gefecht_visual_test.dart' as bilder;

void main() {
  setUpAll(() async {
    await ladeKartoSchriften();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final breite in [390.0, 820.0, 1200.0, 1440.0]) {
    for (final hell in Brightness.values) {
      for (final tastatur in [0.0, 250.0]) {
        testWidgets(
          'Laden/Zielen/offene Ergebnisse $breite $hell Tastatur=$tastatur',
          (t) async {
            t.view.physicalSize = Size(breite, 1000);
            t.view.devicePixelRatio = 1;
            t.view.viewInsets = FakeViewPadding(bottom: tastatur);
            addTearDown(t.view.resetPhysicalSize);
            addTearDown(t.view.resetDevicePixelRatio);
            addTearDown(t.view.resetViewInsets);
            final snap = fixture.ladeSnapshot();
            const s = Gefechtszustand(
              iniWurf: 6,
              kontext: Gefechtskontext(kontakt: 'Ork', entfernung: 5),
            );
            final boundary = GlobalKey();
            Widget rahmen(Widget child) => RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                theme: buildKartoTheme(
                  brightness: hell,
                  centerAppBarTitle: false,
                ),
                home: Scaffold(body: child),
              ),
            );
            await t.pumpWidget(
              rahmen(
                GefechtLadedialog(
                  zustand: s,
                  snapshot: snap,
                  kampfmittel: fixture.mittel,
                ),
              ),
            );
            await t.pumpAndSettle();
            expect(
              t
                  .widget<FilledButton>(
                    find.byKey(const ValueKey('gefecht-laden-starten')),
                  )
                  .onPressed,
              isNull,
            );
            expect(
              find.textContaining('Anfänglichen Ladezustand'),
              findsWidgets,
            );
            expect(t.takeException(), isNull);
            await bilder.captureGefechtsTestbild(
              t,
              boundary,
              'laden-${breite.toInt()}-${hell.name}-kb${tastatur.toInt()}',
            );
            final geladen = bestaetigeGefechtsLadung(
              s,
              snap.hero.combatConfig.selectedWeapon,
              true,
            );
            await t.pumpWidget(
              rahmen(
                GefechtAktionsdialog(
                  zustand: geladen,
                  werte: snap,
                  katalog: testCatalog,
                  aktion: Gefechtsaktion.angriff,
                  titel: 'Schuss vorbereiten',
                ),
              ),
            );
            await t.pumpAndSettle();
            final ansage = find.byKey(const ValueKey('gefecht-fk-ansage'));
            await t.ensureVisible(ansage);
            await t.enterText(ansage, '5');
            await t.pumpAndSettle();
            expect(find.text('Zusatz-Zielen beginnen'), findsOneWidget);
            expect(
              t
                  .widget<FilledButton>(
                    find.byKey(const ValueKey('gefecht-auftrag-starten')),
                  )
                  .onPressed,
              isNotNull,
            );
            expect(t.takeException(), isNull);
            await bilder.captureGefechtsTestbild(
              t,
              boundary,
              'zielen-${breite.toInt()}-${hell.name}-kb${tastatur.toInt()}',
            );
            await t.enterText(ansage, 'ungültig');
            await t.pumpAndSettle();
            expect(
              t
                  .widget<FilledButton>(
                    find.byKey(const ValueKey('gefecht-auftrag-starten')),
                  )
                  .onPressed,
              isNull,
            );
            expect(
              find.textContaining('Fernkampfansage muss eine ganze Zahl sein'),
              findsWidgets,
            );
            expect(t.takeException(), isNull);
            final vorbereiten = beginneGefechtsZielen(
              geladen,
              snap,
              testCatalog,
              fixture.zielauftrag,
            );
            final c = ProviderContainer(
              overrides: [
                heroComputedProvider('rondra')
                    .overrideWith((ref) => AsyncData(snap)),
                rulesCatalogProvider.overrideWith((ref) async => testCatalog),
              ],
            );
            addTearDown(c.dispose);
            final ctl = c.read(gefechtProvider('rondra').notifier)..beginnen(6);
            ctl.setzen(
              vorbereiten.copyWith(
                angriffsergebnisse: [
                  for (var i = 0; i < 3; i++)
                    Gefechtsangriffsergebnis(
                      auftragId: 'treffer-$i',
                      kampfmittel: fixture.mittel,
                      waffenname: 'Armbrust · Treffer ${i + 1}',
                      schaden: const DiceSpec(count: 1, sides: 6),
                      abwehrmalus: 2,
                      tpBonus: 4,
                      manoevername: 'Hammerschlag',
                      hinweis:
                          'Hammerschlag: Gesamte gewürfelte TP einschließlich Schadenansage '
                          'am Spieltisch verdreifachen. Gegnerische Abwehr, RS, Wunden und '
                          'weitere Regelentscheidungen gesondert prüfen.',
                    ),
                ],
              ),
            );
            await t.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: UncontrolledProviderScope(
                  container: c,
                  child: MaterialApp(
                    theme: buildKartoTheme(
                      brightness: hell,
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
            await t.pumpAndSettle();
            await t.ensureVisible(find.text('Fortsetzen'));
            expect(find.textContaining('1 bezahlt'), findsOneWidget);
            expect(t.takeException(), isNull);
            await bilder.captureGefechtsTestbild(
              t,
              boundary,
              'zielhandlung-${breite.toInt()}-${hell.name}-kb${tastatur.toInt()}',
            );
            expect(
              find.byKey(const ValueKey('gefecht-angriffsschaden')),
              findsNWidgets(3),
            );
            for (final f
                in find
                    .byKey(const ValueKey('gefecht-angriffsschaden'))
                    .evaluate()
                    .toList()) {
              await t.ensureVisible(find.byWidget(f.widget));
              await t.pumpAndSettle();
              expect(t.takeException(), isNull);
            }
            await t.ensureVisible(
              find.text('Hammerschlag gelungen · Armbrust · Treffer 1'),
            );
            await t.pumpAndSettle();
            await bilder.captureGefechtsTestbild(
              t,
              boundary,
              'ergebnisse-${breite.toInt()}-${hell.name}-kb${tastatur.toInt()}',
            );
          },
        );
      }
    }
  }
}
