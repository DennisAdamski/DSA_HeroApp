import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_reiseroute.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import '../shell/karto_test_support.dart';

const _nebel = HeroAdventureEntry(
  id: 'nebel',
  title: 'Die Spuren im Nebel',
  currentAventurianDate: HeroAdventureDateValue(
    day: '7',
    month: 'boron',
    year: '1043',
  ),
);

const _gareth = HeroReiseStation(
  id: 's1',
  ort: 'Gareth',
  datum: HeroAdventureDateValue(day: '1', month: 'boron', year: '1043'),
  notiz: 'Aufbruch am Südtor.',
  adventureId: 'nebel',
);

HeroSheet _held({List<HeroReiseStation> stationen = const []}) =>
    testHero().copyWith(adventures: const [_nebel], reiseStationen: stationen);

void main() {
  late FakeRepository repo;

  Future<void> zeige(
    WidgetTester tester, {
    HeroSheet? held,
    bool planOffen = false,
    KartoKachelGroesse? groesse,
    double breite = 900,
    double skalierung = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = FakeRepository(
      heroes: [held ?? _held()],
      states: {'rondra': const HeroState.empty().copyWith(standort: 'Punin')},
    );
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      ],
    );
    addTearDown(container.dispose);
    if (planOffen) {
      container
          .read(advancementSessionProvider('rondra').notifier)
          .start(hero: held ?? _held(), catalog: testCatalog);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildKartoTheme(
            brightness: Brightness.light,
            centerAppBarTitle: false,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(skalierung)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Consumer(
                builder: (context, ref, _) {
                  final werte = ref
                      .watch(heroComputedProvider('rondra'))
                      .asData
                      ?.value;
                  if (werte == null) return const SizedBox.shrink();
                  final kachel = KartoReiserouteKachel(
                    heroId: 'rondra',
                    stationen: werte.hero.reiseStationen,
                  );
                  // Wie in der Spielansicht liegt sie in einer Kachel.
                  return groesse == null
                      ? kachel
                      : KartoKachelSteuerung(
                          kennung: 'reiseroute',
                          groesse: groesse,
                          child: kachel,
                        );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder key(String name) => find.byKey(ValueKey<String>(name));

  Future<List<HeroReiseStation>> gespeichert() async =>
      (await repo.loadHeroById('rondra'))!.reiseStationen;

  testWidgets('leer lädt die Kachel zur ersten Station ein', (tester) async {
    await zeige(tester);
    expect(find.textContaining('Keine Station erfasst'), findsOneWidget);
    expect(key('karto-reise-alle'), findsNothing);
  });

  testWidgets('eine neue Station übernimmt Standort, Datum und Abenteuer', (
    tester,
  ) async {
    await zeige(tester, held: _held(stationen: const [_gareth]));
    await tester.tap(key('karto-reise-station-neu'));
    await tester.pumpAndSettle();

    // Vorbelegt aus dem laufenden Spiel.
    expect(find.widgetWithText(TextField, 'Punin'), findsOneWidget);
    await tester.enterText(key('karto-reise-notiz'), 'Bei der Akademie.');
    await tester.pump();
    await tester.tap(key('karto-reise-speichern'));
    await tester.pumpAndSettle();

    final stationen = await gespeichert();
    expect(stationen.map((s) => s.ort), ['Gareth', 'Punin']);
    final neu = stationen.last;
    expect(neu.id, isNotEmpty);
    expect(
      [neu.datum.day, neu.datum.month, neu.datum.year],
      ['7', 'boron', '1043'],
    );
    expect(neu.adventureId, 'nebel');
    expect(neu.lastModified, isNotNull);
    // Zeitleiste zeigt den Abstand zur vorigen Station.
    expect(find.text('+6 Tage'), findsOneWidget);
    expect(find.text('Bei der Akademie.'), findsOneWidget);
  });

  testWidgets('eine Station lässt sich bearbeiten und löschen', (tester) async {
    await zeige(tester, held: _held(stationen: const [_gareth]));
    await tester.tap(key('karto-reise-station-s1'));
    await tester.pumpAndSettle();
    await tester.enterText(key('karto-reise-notiz'), 'Aufbruch im Regen.');
    await tester.pump();
    await tester.tap(key('karto-reise-speichern'));
    await tester.pumpAndSettle();
    expect((await gespeichert()).single.notiz, 'Aufbruch im Regen.');

    await tester.tap(key('karto-reise-station-s1'));
    await tester.pumpAndSettle();
    await tester.tap(key('karto-reise-loeschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
    await tester.pumpAndSettle();
    expect(await gespeichert(), isEmpty);
  });

  testWidgets('das Blatt zeigt die ganze Route mit Übersicht', (tester) async {
    await zeige(
      tester,
      held: _held(
        stationen: [
          _gareth,
          _gareth.copyWith(
            id: 's2',
            ort: 'Punin',
            datum: const HeroAdventureDateValue(
              day: '11',
              month: 'boron',
              year: '1043',
            ),
          ),
        ],
      ),
    );
    await tester.tap(key('karto-reise-alle'));
    await tester.pumpAndSettle();
    expect(find.text('2 Stationen · 10 Tage unterwegs'), findsOneWidget);
    expect(find.text('Die Spuren im Nebel'), findsOneWidget);
    expect(find.byTooltip('Auf Avesmaps zeigen'), findsNWidgets(2));
  });

  testWidgets('während einer Planung ist das Anlegen gesperrt', (tester) async {
    await zeige(tester, planOffen: true);
    final knopf = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Station'),
        matching: find.byWidgetPredicate((w) => w is TextButton),
      ),
    );
    expect(knopf.onPressed, isNull);
  });

  group('Größenstufen (SPIEL-07)', () {
    // Sieben Stationen mit langen Notizen, zeitlich geordnet.
    final stationen = [
      for (var i = 1; i <= 7; i++)
        HeroReiseStation(
          id: 's$i',
          ort: 'Ort $i',
          datum: HeroAdventureDateValue(
            day: '$i',
            month: 'boron',
            year: '1043',
          ),
          notiz:
              'Eine lange Notiz zu Station $i, die sich über mehrere Zeilen '
              'erstreckt und deshalb gekürzt werden muss, wenn nicht genug '
              'Platz da ist. Noch mehr Text, damit es sicher mehr als vier '
              'Zeilen werden, auch in einer breiten Kachel mit großer Schrift.',
          adventureId: 'nebel',
        ),
    ];
    final held = _held(stationen: stationen);

    int notizZeilen(WidgetTester tester, String ort) {
      final text = find.descendant(
        of: key('karto-reise-station-s${ort.substring(4)}'),
        matching: find.textContaining('Eine lange Notiz'),
      );
      return tester.widget<Text>(text).maxLines!;
    }

    for (final (groesse, anzahl, zeilen, link) in [
      (
        KartoKachelGroesse.kompakt,
        kReiserouteKurz,
        kReiserouteNotizKurz,
        false,
      ),
      (KartoKachelGroesse.normal, kReiserouteKurz, kReiserouteNotizKurz, false),
      (KartoKachelGroesse.weit, kReiserouteWeit, kReiserouteNotizWeit, true),
    ]) {
      testWidgets('${groesse.name}: $anzahl Stationen, $zeilen Notizzeilen', (
        tester,
      ) async {
        await zeige(tester, held: held, groesse: groesse);
        // Gezeigt werden die jüngsten Stationen, die ältesten fehlen.
        final sichtbar = [
          for (var i = 1; i <= 7; i++)
            if (key('karto-reise-station-s$i').evaluate().isNotEmpty) i,
        ];
        expect(sichtbar, [for (var i = 8 - anzahl; i <= 7; i++) i]);
        expect(notizZeilen(tester, 'Ort 7'), zeilen);
        expect(
          find.byTooltip('Auf Avesmaps zeigen'),
          link ? findsNWidgets(anzahl) : findsNothing,
        );
        expect(find.text('Ganze Route (7)'), findsOneWidget);
      });
    }

    testWidgets('ohne Kachel gilt die gewohnte Darstellung', (tester) async {
      await zeige(tester, held: held);
      expect(key('karto-reise-station-s4').evaluate(), isEmpty);
      expect(key('karto-reise-station-s5'), findsOneWidget);
      expect(find.byTooltip('Auf Avesmaps zeigen'), findsNothing);
    });

    testWidgets('bis zur Obergrenze steht kein Zähler am Knopf', (
      tester,
    ) async {
      await zeige(
        tester,
        held: _held(stationen: stationen.take(kReiserouteWeit).toList()),
        groesse: KartoKachelGroesse.weit,
      );
      expect(find.text('Ganze Route'), findsOneWidget);
      expect(find.textContaining('Ganze Route ('), findsNothing);
    });

    testWidgets('eine Station lässt sich in der weiten Kachel bearbeiten', (
      tester,
    ) async {
      await zeige(tester, held: held, groesse: KartoKachelGroesse.weit);
      await tester.tap(key('karto-reise-station-s7'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsWidgets);
    });

    for (final breite in [360.0, 744.0, 1280.0]) {
      testWidgets('weit bei $breite dp und Schrift 2 ohne Überlauf', (
        tester,
      ) async {
        await zeige(
          tester,
          held: held,
          groesse: KartoKachelGroesse.weit,
          breite: breite,
          skalierung: 2,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
