import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/ort_loader.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/karten_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseroute_rules.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/ort_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karte.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_blatt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/standort/karto_standort_kachel.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import '../shell/karto_test_support.dart';

// Die Karte ohne Kartenbild (kein Manifest, also keine Kachelanfragen):
// Orte, Route, Treffer und das Vollbild mit Infotafel.

const String _garethId = '80558060-4299-54aa-b520-814b10819885';

const List<AvesmapsOrt> _orte = <AvesmapsOrt>[
  AvesmapsOrt(
    id: _garethId,
    name: 'Gareth',
    art: 'metropole',
    x: 551.625,
    y: 532.969,
  ),
  AvesmapsOrt(id: 'punin', name: 'Punin', art: 'metropole', x: 470, y: 380),
  AvesmapsOrt(id: 'fehring', name: 'Fehring', art: 'dorf', x: 553, y: 536),
  AvesmapsOrt(id: 'burg', name: 'Burg Feste', art: 'gebaeude', x: 548, y: 530),
];

const List<HeroReiseStation> _stationen = <HeroReiseStation>[
  HeroReiseStation(
    id: 's1',
    ort: 'Gareth',
    ortId: _garethId,
    kartenX: 551.625,
    kartenY: 532.969,
    datum: HeroAdventureDateValue(day: '1', month: 'boron', year: '1043'),
    notiz: 'Aufbruch am Südtor.',
  ),
  HeroReiseStation(
    id: 's2',
    ort: 'Punin',
    ortId: 'punin',
    kartenX: 470,
    kartenY: 380,
    datum: HeroAdventureDateValue(day: '9', month: 'boron', year: '1043'),
  ),
];

Finder _k(String schluessel) => find.byKey(ValueKey<String>(schluessel));

Widget _rahmen(Widget kind, {Brightness helligkeit = Brightness.light}) =>
    MaterialApp(
      theme: buildKartoTheme(brightness: helligkeit, centerAppBarTitle: false),
      home: Scaffold(body: kind),
    );

void main() {
  group('KartoKarte', () {
    for (final helligkeit in Brightness.values) {
      testWidgets('zeichnet Orte und Route ohne Fehler ($helligkeit)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _rahmen(
            SizedBox(
              width: 400,
              height: 300,
              child: KartoKarte(
                orte: _orte,
                routenPunkte: kartenRoutenPunkte(reiseEtappen(_stationen)),
                standort: _orte.first,
              ),
            ),
            helligkeit: helligkeit,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(KartoKarte), findsOneWidget);
      });
    }

    testWidgets('Tipps treffen Station und Ort, ins Leere nichts', (
      tester,
    ) async {
      final schluessel = GlobalKey<KartoKarteState>();
      final treffer = <KartenTreffer?>[];
      await tester.pumpWidget(
        _rahmen(
          Center(
            child: SizedBox(
              width: 400,
              height: 300,
              child: KartoKarte(
                key: schluessel,
                orte: _orte,
                routenPunkte: kartenRoutenPunkte(
                  reiseEtappen(_stationen.sublist(1)),
                ),
                start: KartenRechteck.um(551, 533, 20),
                onTreffer: treffer.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final kamera = schluessel.currentState!.kamera!;
      final ecke = tester.getTopLeft(find.byType(KartoKarte));
      Future<void> tippe(double x, double y) async {
        await tester.tapAt(
          ecke + kamera.zuBildschirm(x, y, const Size(400, 300)),
        );
        // Der Doppeltipp hält den einfachen Tipp kurz zurück.
        await tester.pump(const Duration(milliseconds: 400));
      }

      await tippe(551.625, 532.969);
      await tippe(553, 536);
      await tippe(540, 545);
      expect((treffer[0]! as KartenTrefferOrt).ort.name, 'Gareth');
      expect((treffer[1]! as KartenTrefferOrt).ort.name, 'Fehring');
      expect(treffer[2], isNull);

      // Zur Station zoomen und sie treffen.
      schluessel.currentState!.zeige(470, 380, zoom: 4);
      await tester.pump();
      final nah = schluessel.currentState!.kamera!;
      await tester.tapAt(
        ecke + nah.zuBildschirm(470, 380, const Size(400, 300)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final station = treffer.last! as KartenTrefferStation;
      expect(station.station.id, 's2');
      expect(station.nummer, 1);
    });

    testWidgets('Zoomknöpfe und Einpassen bewegen die Kamera', (tester) async {
      final schluessel = GlobalKey<KartoKarteState>();
      await tester.pumpWidget(
        _rahmen(
          SizedBox(
            width: 400,
            height: 300,
            child: KartoKarte(key: schluessel, orte: _orte),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final start = schluessel.currentState!.kamera!.zoom;
      schluessel.currentState!.zoomeUm(1);
      await tester.pump();
      expect(schluessel.currentState!.kamera!.zoom, closeTo(start + 1, 1e-9));
      schluessel.currentState!.einpassen();
      await tester.pump();
      expect(schluessel.currentState!.kamera!.zoom, closeTo(start, 1e-9));
    });
  });

  group('Vollbild', () {
    late FakeRepository repo;

    Future<ProviderContainer> zeige(
      WidgetTester tester, {
      bool planOffen = false,
      Widget Function(String heroId)? start,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final held = testHero().copyWith(reiseStationen: _stationen);
      repo = FakeRepository(
        heroes: <HeroSheet>[held],
        states: <String, HeroState>{
          'rondra': const HeroState.empty().copyWith(standort: 'Punin'),
        },
      );
      final container = ProviderContainer(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => testCatalog),
          ortKatalogProvider.overrideWith((ref) async => const OrtKatalog()),
          avesmapsOrteProvider.overrideWith((ref) async => _orte),
        ],
      );
      addTearDown(container.dispose);
      if (planOffen) {
        container
            .read(advancementSessionProvider('rondra').notifier)
            .start(hero: held, catalog: testCatalog);
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildKartoTheme(
              brightness: Brightness.light,
              centerAppBarTitle: false,
            ),
            home:
                start?.call('rondra') ??
                const KartoKartenBlatt(heroId: 'rondra'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    Future<void> tippeStation(WidgetTester tester, String id) async {
      final state = tester.state<KartoKarteState>(find.byType(KartoKarte));
      final station = _stationen.firstWhere((s) => s.id == id);
      final groesse = tester.getSize(find.byType(KartoKarte));
      final ecke = tester.getTopLeft(find.byType(KartoKarte));
      await tester.tapAt(
        ecke +
            state.kamera!.zuBildschirm(
              station.kartenX!,
              station.kartenY!,
              groesse,
            ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    testWidgets('eine Station zeigt Infotafel mit Bearbeiten', (tester) async {
      await zeige(tester);
      expect(_k('karto-karte-nennung'), findsOneWidget);
      expect(_k('karto-karte-standort'), findsOneWidget);

      await tippeStation(tester, 's1');
      expect(find.text('Aufbruch am Südtor.'), findsOneWidget);
      final knopf = tester.widget<ButtonStyleButton>(
        find.descendant(
          of: _k('karto-karte-info-bearbeiten'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(knopf.onPressed, isNotNull);

      await tester.tap(_k('karto-karte-info-schliessen'));
      await tester.pumpAndSettle();
      expect(_k('karto-karte-info-name'), findsNothing);
    });

    testWidgets('während einer Planung ist Bearbeiten gesperrt', (
      tester,
    ) async {
      await zeige(tester, planOffen: true);
      await tippeStation(tester, 's1');
      final knopf = tester.widget<ButtonStyleButton>(
        find.descendant(
          of: _k('karto-karte-info-bearbeiten'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(knopf.onPressed, isNull);
      expect(await repo.loadHeroById('rondra'), isNotNull);
    });

    testWidgets('die Lageskizze der Standort-Kachel öffnet das Vollbild', (
      tester,
    ) async {
      await zeige(
        tester,
        start: (heroId) => Scaffold(
          body: SingleChildScrollView(
            child: Consumer(
              builder: (context, ref, _) {
                final werte = ref
                    .watch(heroComputedProvider(heroId))
                    .asData
                    ?.value;
                if (werte == null) return const SizedBox.shrink();
                return KartoStandortKachel(
                  standort: werte.state.standort,
                  heroId: heroId,
                  stationen: werte.hero.reiseStationen,
                  onSpeichern: (_) async {},
                );
              },
            ),
          ),
        ),
      );
      expect(_k('karto-standort-skizze'), findsOneWidget);
      await tester.tap(_k('karto-standort-skizze'));
      await tester.pumpAndSettle();
      expect(find.byType(KartoKartenBlatt), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
