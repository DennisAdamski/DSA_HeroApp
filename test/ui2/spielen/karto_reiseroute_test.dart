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
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
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
          home: Scaffold(
            body: SingleChildScrollView(
              child: Consumer(
                builder: (context, ref, _) {
                  final werte = ref
                      .watch(heroComputedProvider('rondra'))
                      .asData
                      ?.value;
                  if (werte == null) return const SizedBox.shrink();
                  return KartoReiserouteKachel(
                    heroId: 'rondra',
                    stationen: werte.hero.reiseStationen,
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
}
