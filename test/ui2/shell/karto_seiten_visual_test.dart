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
import 'package:dsa_heldenverwaltung/data/auth_service.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_compat_theme.dart';
import 'package:dsa_heldenverwaltung/ui/screens/auth/open_sign_in.dart';
import 'package:dsa_heldenverwaltung/ui/screens/auth/sign_in_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/settings_screen.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';
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
              ((brightness == Brightness.light && width == 1440) ||
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
  for (final width in [390.0, 1024.0, 1440.0]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'Dialoge am Spieltisch $width dp, ${brightness.name}, Text $scale',
          (tester) async {
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
            final capture =
                scale == 1 &&
                ((brightness == Brightness.light && width == 1440) ||
                    (brightness == Brightness.dark && width == 1024));
            final suffix = '${width.toInt()}-${brightness.name}';

            // Probe: vor und nach dem Wurf.
            final mut = find.byKey(const ValueKey('inspector-probe-attr-MU'));
            await tester.ensureVisible(mut);
            await tester.tap(mut);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'Probe');
            if (capture) await _capture(tester, screenshotKey, 'probe-$suffix');
            await tester.tap(find.text('Würfeln').first);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'Wurf');
            if (capture) {
              await _capture(tester, screenshotKey, 'probe-wurf-$suffix');
            }
            await tester.tap(find.text('Schließen').last);
            await tester.pumpAndSettle();

            // Rast.
            final rast = find.text('Rast').first;
            await tester.ensureVisible(rast);
            await tester.tap(rast);
            await tester.pumpAndSettle();
            expect(find.byKey(const ValueKey('rest-dialog')), findsOneWidget);
            expect(tester.takeException(), isNull, reason: 'Rast');
            if (capture) await _capture(tester, screenshotKey, 'rast-$suffix');
            await tester.tap(find.byKey(const ValueKey('rest-dialog-close')));
            await tester.pumpAndSettle();

            // Ressourcenblatt.
            final lep = find.byTooltip('Lebenspunkte ändern');
            await tester.ensureVisible(lep);
            await tester.tap(lep);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'Ressource');
            if (capture) {
              await _capture(tester, screenshotKey, 'ressource-$suffix');
            }
            await tester.tap(
              find.byKey(const ValueKey('karto-ressource-schliessen')),
            );
            await tester.pumpAndSettle();
          },
          tags: ['r3-acceptance'],
        );
      }
    }
  }

  for (final width in [390.0, 1024.0, 1440.0]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'Aufgelegte Seiten $width dp, ${brightness.name}, Text $scale',
          (tester) async {
            final screenshotKey = GlobalKey();
            final hero = held();
            await pumpAcceptanceWorkspace(
              tester,
              repository: AcceptanceRepository(
                heroes: [hero, testHero('alrik', 'Alrik Feuerstein')],
              ),
              selectedHeroId: hero.id,
              size: Size(width, 1000),
              textScale: scale,
              brightness: brightness,
              screenshotKey: screenshotKey,
            );
            final capture =
                scale == 1 &&
                ((brightness == Brightness.light && width == 1440) ||
                    (brightness == Brightness.dark && width == 1024));
            final suffix = '${width.toInt()}-${brightness.name}';

            Future<void> menue(String eintrag) async {
              await tester.tap(find.byTooltip('Workspace-Menü').first);
              await tester.pumpAndSettle();
              await tester.tap(find.text(eintrag).last);
              await tester.pumpAndSettle();
            }

            await menue('Einstellungen');
            expect(find.byType(SettingsScreen), findsOneWidget);
            expect(tester.takeException(), isNull, reason: 'Einstellungen');
            if (capture) {
              await _capture(tester, screenshotKey, 'einstellungen-$suffix');
            }
            await tester.pageBack();
            await tester.pumpAndSettle();

            await menue('Helden verwalten');
            expect(find.byType(HeroesHomeScreen), findsOneWidget);
            expect(tester.takeException(), isNull, reason: 'Heldenliste');
            if (capture) {
              await _capture(tester, screenshotKey, 'heldenliste-$suffix');
            }
            await tester.pageBack();
            await tester.pumpAndSettle();
          },
          tags: ['r3-acceptance'],
        );
      }
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('Anmeldung ${brightness.name}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 900);
      addTearDown(tester.view.reset);
      final screenshotKey = GlobalKey();
      final wurzel = buildKartoTheme(
        brightness: brightness,
        centerAppBarTitle: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: wurzel,
          builder: (context, child) =>
              RepaintBoundary(key: screenshotKey, child: child),
          home: Theme(
            data: buildKartoCompatTheme(wurzel),
            child: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => openSignInScreen(context, _AuthAttrappe()),
                  child: const Text('Öffnen'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Öffnen'));
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(
        tester,
        screenshotKey,
        'anmeldung-1024-${brightness.name}',
      );
    }, tags: ['r3-acceptance']);
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

class _AuthAttrappe implements AuthService {
  @override
  AuthUser? get currentUser => null;

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
  }) async => AuthUser(uid: email, email: email);

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async => AuthUser(uid: email, email: email);

  @override
  Stream<AuthUser?> watchUser() => const Stream<AuthUser?>.empty();
}
