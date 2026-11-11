import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/ort_loader.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/kraeuter_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_base_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/kraeuter_providers.dart';
import 'package:dsa_heldenverwaltung/state/ort_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/wildnis/karto_wildnis_kachel.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

// Wildnis-Kachel (Kräuter suchen, Wege des Entdeckers S. 113 f.): Landschaft,
// Jahreszeit, Geländekunde und Ortskenntnis kommen aus dem Helden, die Probe
// läuft über die Gefechtsbrücke, die Ausbeute rechnet die Regelfunktion.

const String _id = 'rondra';

/// Reichsforst als Regenwald-Region: ergibt genau einen Landschaftsvorschlag.
final OrtKatalog _orte = OrtKatalog(
  orte: <OrtEintrag>[
    OrtEintrag(name: 'Regenwald', art: OrtArt.region, unterart: 'Regenwald'),
    OrtEintrag(name: 'Reichsforst', art: OrtArt.region, unterart: 'Wald'),
  ],
);

/// Ein Kraut im Dschungel: Suchschwierigkeit 1 + 2 = 3.
const KraeuterKatalog _kraeuter = KraeuterKatalog(
  kraeuter: <KrautEintrag>[
    KrautEintrag(
      name: 'Donf',
      bestimmung: 1,
      vorkommen: <KrautVorkommen>[
        KrautVorkommen(
          landschaft: Kraeuterlandschaft.dschungel,
          haeufigkeit: Kraeuterhaeufigkeit.haeufig,
        ),
      ],
    ),
  ],
);

HeroAdventureEntry _abenteuer(String monat) => HeroAdventureEntry(
  id: 'a',
  title: 'Der lange Weg',
  currentAventurianDate: HeroAdventureDateValue(
    day: '5',
    month: monat,
    year: '1043',
  ),
);

HeroSheet _held({
  List<String> sonderfertigkeiten = const <String>[],
  String? monat = 'praios',
}) => testHero(_id).copyWith(
  talents: const <String, HeroTalentEntry>{
    'tal_sinnesschaerfe': HeroTalentEntry(talentValue: 10),
    'tal_wildnisleben': HeroTalentEntry(talentValue: 8),
    'tal_pflanzenkunde': HeroTalentEntry(talentValue: 9),
  },
  talentSpecialAbilities: <TalentSpecialAbility>[
    for (final name in sonderfertigkeiten) TalentSpecialAbility(name: name),
  ],
  adventures: <HeroAdventureEntry>[if (monat != null) _abenteuer(monat)],
);

void main() {
  Finder k(String schluessel) => find.byKey(ValueKey<String>(schluessel));

  Future<void> zeige(
    WidgetTester tester, {
    required HeroSheet held,
    String standort = 'Regenwald',
    KartoBestandsAdapter? bestand,
    double breite = 480,
    double skalierung = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, 3200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final werte = buildHeroComputedSnapshot(
      hero: held,
      state: const HeroState.empty().copyWith(standort: standort),
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(
          FakeRepository(heroes: [held]),
        ),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        ortKatalogProvider.overrideWith((ref) async => _orte),
        kraeuterKatalogProvider.overrideWith((ref) async => _kraeuter),
      ],
    );
    addTearDown(container.dispose);
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
              child: KartoKachelSteuerung(
                kennung: 'wildnis',
                groesse: KartoKachelGroesse.fuerBreite(breite - 32),
                dicht: false,
                child: KartoWildnisKachel(
                  heroId: held.id,
                  werte: werte,
                  bestand: bestand ?? TestBestand(),
                  aktion: (auftrag) => auftrag(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String zusammenfassung() =>
      (k('karto-wildnis-zusammenfassung').evaluate().single.widget as Text)
          .data!;

  group('Vorbelegung aus dem Helden', () {
    testWidgets(
      'Standort, Datum und Sonderfertigkeiten ergeben die Erschwernis',
      (tester) async {
        await zeige(
          tester,
          held: _held(
            sonderfertigkeiten: <String>[
              'Geländekunde (Dschungelkundig)',
              'Ortskenntnis (Regenwald)',
            ],
          ),
        );
        // Dschungel im Sommer −2, Geländekunde −3, Ortskenntnis −7.
        expect(zusammenfassung(), 'TaW 9 · Erschwernis −12');
        expect(find.text('aus Geländekunde (Dschungelkundig)'), findsOneWidget);
        expect(find.text('aus Ortskenntnis (Regenwald)'), findsOneWidget);
      },
    );

    testWidgets('Eigenschaften der Probe sind KL/IN/FF', (tester) async {
      await zeige(tester, held: _held());
      expect(find.textContaining('KL 12 · IN 13 · FF 10'), findsOneWidget);
    });

    testWidgets('ohne Sonderfertigkeiten gilt nur die Landschaft', (
      tester,
    ) async {
      await zeige(tester, held: _held());
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −2');
      expect(find.text('keine passende Sonderfertigkeit'), findsOneWidget);
      expect(
        find.text('keine Ortskenntnis für diesen Standort'),
        findsOneWidget,
      );
    });

    testWidgets('Ortskenntnis gilt nur am eigenen Standort', (tester) async {
      await zeige(
        tester,
        held: _held(sonderfertigkeiten: <String>['Ortskenntnis (Gareth)']),
      );
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −2');
    });

    testWidgets('mehrdeutiger Standort verlangt eine Landschaftswahl', (
      tester,
    ) async {
      await zeige(tester, held: _held(), standort: 'Reichsforst');
      expect(
        find.text('Mehrere passen zum Standort: bitte wählen.'),
        findsOneWidget,
      );
      expect(k('karto-wildnis-zusammenfassung'), findsNothing);
      final wuerfeln = tester.widget<FilledButton>(k('karto-wildnis-wuerfeln'));
      expect(wuerfeln.onPressed, isNull);
    });

    testWidgets('ohne Datum im Abenteuer wählt man die Jahreszeit selbst', (
      tester,
    ) async {
      await zeige(tester, held: _held(monat: null));
      expect(
        find.text('Kein Datum im Abenteuer: bitte wählen.'),
        findsOneWidget,
      );
      expect(k('karto-wildnis-zusammenfassung'), findsNothing);
    });
  });

  group('Handeingaben', () {
    testWidgets('Geländekunde lässt sich von Hand setzen', (tester) async {
      await zeige(tester, held: _held());
      await tester.tap(k('karto-wildnis-gelaende-passend'));
      await tester.pumpAndSettle();
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −5');
      expect(find.text('von Hand gesetzt'), findsOneWidget);
      await tester.tap(k('karto-wildnis-gelaende-aehnlich'));
      await tester.pumpAndSettle();
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −3');
    });

    testWidgets('Ortskenntnis lässt sich von Hand schalten', (tester) async {
      await zeige(tester, held: _held());
      await tester.tap(k('karto-wildnis-ortskenntnis'));
      await tester.pumpAndSettle();
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −9');
    });

    testWidgets('AsP und situative Erschwernis gehen ein', (tester) async {
      await zeige(tester, held: _held());
      for (var i = 0; i < 6; i++) {
        await tester.tap(k('karto-wildnis-asp-plus'));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(k('karto-wildnis-asp-wert'), findsOneWidget);
      // 6 AsP senken die Erschwernis um 2.
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −4');
      await tester.tap(k('karto-wildnis-situativ-plus'));
      await tester.pumpAndSettle();
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −3');
    });

    testWidgets('zwei Stunden steigern den TaW um die Hälfte', (tester) async {
      await zeige(tester, held: _held());
      await tester.tap(k('karto-wildnis-dauer-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 Stunden').last);
      await tester.pumpAndSettle();
      // TaW 9 steigt auf 13,5, kaufmännisch gerundet 14.
      expect(zusammenfassung(), 'TaW 14 · Erschwernis −2');
    });
  });

  group('Würfeln', () {
    testWidgets('ohne Gefechtsbrücke bleibt der Knopf gesperrt', (
      tester,
    ) async {
      await zeige(tester, held: _held());
      final wuerfeln = tester.widget<FilledButton>(k('karto-wildnis-wuerfeln'));
      expect(wuerfeln.onPressed, isNull);
    });

    testWidgets('die Probe geht an die Brücke und zeigt die Ausbeute', (
      tester,
    ) async {
      final bestand = GefechtsTestBestand()..w20Wert = 5;
      await zeige(
        tester,
        held: _held(
          sonderfertigkeiten: <String>['Geländekunde (Dschungelkundig)'],
        ),
        bestand: bestand,
      );
      await tester.tap(k('karto-wildnis-wuerfeln'));
      await tester.pumpAndSettle();

      final anfrage = bestand.anfragen.single;
      expect(anfrage.title, 'Kräuter suchen');
      expect(anfrage.subtitle, 'KL/IN/FF');
      expect(anfrage.basePool, 9);
      // Erschwernis −5 (Dschungel −2, Geländekunde −3) = +5 auf den Pool.
      expect(anfrage.initialSituationalModifier, 5);

      expect(k('karto-wildnis-ergebnis'), findsOneWidget);
      expect(find.textContaining('Gelungen'), findsOneWidget);
      expect(
        find.descendant(
          of: k('karto-wildnis-ergebnis'),
          matching: find.textContaining('Donf'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('abgebrochene Probe zeigt kein Ergebnis', (tester) async {
      final bestand = GefechtsTestBestand()..abbrechen = true;
      await zeige(tester, held: _held(), bestand: bestand);
      await tester.tap(k('karto-wildnis-wuerfeln'));
      await tester.pumpAndSettle();
      expect(bestand.anfragen, hasLength(1));
      expect(k('karto-wildnis-ergebnis'), findsNothing);
    });

    testWidgets('eine neue Eingabe verwirft das Ergebnis', (tester) async {
      final bestand = GefechtsTestBestand()..w20Wert = 5;
      await zeige(tester, held: _held(), bestand: bestand);
      await tester.tap(k('karto-wildnis-wuerfeln'));
      await tester.pumpAndSettle();
      expect(k('karto-wildnis-ergebnis'), findsOneWidget);
      await tester.tap(k('karto-wildnis-asp-plus'));
      await tester.pumpAndSettle();
      expect(k('karto-wildnis-ergebnis'), findsNothing);
    });

    testWidgets('misslungene Probe nennt keinen Fund', (tester) async {
      final bestand = GefechtsTestBestand()..w20Wert = 20;
      await zeige(tester, held: _held(), bestand: bestand);
      await tester.tap(k('karto-wildnis-wuerfeln'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Misslungen'), findsOneWidget);
      expect(
        find.descendant(
          of: k('karto-wildnis-ergebnis'),
          matching: find.textContaining('Donf'),
        ),
        findsNothing,
      );
    });
  });

  group('Größenstufen', () {
    for (final breite in [320.0, 480.0, 700.0, 1100.0]) {
      for (final skalierung in [1.0, 2.0]) {
        testWidgets('bei $breite dp, Schrift $skalierung, ohne Überlauf', (
          tester,
        ) async {
          final bestand = GefechtsTestBestand()..w20Wert = 5;
          await zeige(
            tester,
            held: _held(
              sonderfertigkeiten: <String>['Geländekunde (Dschungelkundig)'],
            ),
            bestand: bestand,
            breite: breite,
            skalierung: skalierung,
          );
          await tester.tap(k('karto-wildnis-wuerfeln'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('die Vorschau nennt die möglichen Funde', (tester) async {
      await zeige(tester, held: _held(), breite: 1100);
      expect(
        find.descendant(
          of: k('karto-wildnis-vorschau'),
          matching: find.textContaining('Donf'),
        ),
        findsOneWidget,
      );
    });
  });
}
