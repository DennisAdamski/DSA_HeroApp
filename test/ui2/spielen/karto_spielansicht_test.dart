import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_base_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_karten.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

import '../shell/karto_test_support.dart';

/// Weltlicher Held: weder Magie noch göttliche Ressourcen aktiviert.
HeroSheet weltlich() => testHero('praiodan', 'Praiodan');

/// Magischer Held über den ausdrücklichen Aktivierungs-Override.
HeroSheet magisch() => testHero('liora', 'Liora').copyWith(
  resourceActivationConfig: const HeroResourceActivationConfig(
    magicEnabledOverride: true,
  ),
);

/// Geweihter Held über den ausdrücklichen Aktivierungs-Override.
HeroSheet geweiht() => testHero('tsaiane', 'Tsaiane').copyWith(
  resourceActivationConfig: const HeroResourceActivationConfig(
    divineEnabledOverride: true,
  ),
);

/// Held mit den übergebenen Abenteuern.
HeroSheet mitAbenteuern(List<HeroAdventureEntry> abenteuer) =>
    weltlich().copyWith(adventures: abenteuer);

const _nebel = HeroAdventureEntry(
  id: 'nebel',
  title: 'Die Spuren im Nebel',
  summary: 'Die Gruppe folgt der Spur des Nebelreiters.',
  startAventurianDate: HeroAdventureDateValue(
    day: '1',
    month: 'phex',
    year: '1043',
  ),
  currentAventurianDate: HeroAdventureDateValue(
    day: '12',
    month: 'phex',
    year: '1043',
  ),
  notes: [
    HeroNoteEntry(
      title: 'Der Nebelreiter',
      description: 'Reitet nur bei Neumond und meidet die Straße nach Gareth.',
    ),
  ],
  people: [
    HeroAdventurePersonEntry(
      id: 'p1',
      name: 'Alrik vom Blautann',
      description: 'Wirt des „Grünen Krugs“, weiß mehr als er sagt.',
    ),
  ],
);

void main() {
  Future<ProviderContainer> zeige(
    WidgetTester tester, {
    required HeroSheet held,
    FakeRepository? repository,
    Map<String, HeroState>? zustaende,
    TestBestand? bestand,
    double breite = 390,
    double skalierung = 1,
    Brightness helligkeit = Brightness.light,
    Future<bool> Function()? vorAbenteuer,
    bool regelnFreigeschaltet = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(
          repository ?? FakeRepository(heroes: [held], states: zustaende),
        ),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        if (regelnFreigeschaltet)
          catalogContentVisibleProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildKartoTheme(
            brightness: helligkeit,
            centerAppBarTitle: false,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(skalierung)),
            child: child!,
          ),
          home: Scaffold(
            body: KartoSpielansicht(
              heroId: held.id,
              bestand: bestand ?? TestBestand(),
              aktion: (auftrag) => auftrag(),
              vorHeldenbearbeitung: vorAbenteuer ?? () async => true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder ressource(KartoRessource art) =>
      find.byKey(ValueKey<String>('karto-ressource-${art.name}'));

  testWidgets('weltlicher Held zeigt nur LeP und AuP', (tester) async {
    await zeige(tester, held: weltlich());
    expect(ressource(KartoRessource.lebensenergie), findsOneWidget);
    expect(ressource(KartoRessource.ausdauer), findsOneWidget);
    expect(ressource(KartoRessource.astralenergie), findsNothing);
    expect(ressource(KartoRessource.karma), findsNothing);
    expect(find.text('Astralpunkte'), findsNothing);
  });

  testWidgets('magischer Held zeigt zusätzlich AsP, aber kein KaP', (
    tester,
  ) async {
    await zeige(tester, held: magisch());
    expect(ressource(KartoRessource.astralenergie), findsOneWidget);
    expect(ressource(KartoRessource.karma), findsNothing);
  });

  testWidgets('geweihter Held zeigt zusätzlich KaP, aber kein AsP', (
    tester,
  ) async {
    await zeige(tester, held: geweiht());
    expect(ressource(KartoRessource.karma), findsOneWidget);
    expect(ressource(KartoRessource.astralenergie), findsNothing);
  });

  testWidgets('Bearbeiten reicht genau die angetippte Ressource weiter', (
    tester,
  ) async {
    final bestand = TestBestand();
    await zeige(tester, held: magisch(), bestand: bestand);
    await tester.tap(find.byTooltip('Astralpunkte ändern'));
    await tester.pumpAndSettle();
    expect(bestand.aufrufe, ['ressource:liora:astralenergie']);
  });

  testWidgets('gelöschter Held führt in einen erklärten Zustand', (
    tester,
  ) async {
    final repo = FakeRepository(heroes: [weltlich()]);
    await zeige(tester, held: weltlich(), repository: repo);
    await repo.deleteHero('praiodan');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Spielwerte konnten nicht geladen werden'),
      findsOneWidget,
    );
    expect(find.text('Wiederholen'), findsOneWidget);
  });

  testWidgets('Ladefehler bietet einen Rückweg statt einer leeren Fläche', (
    tester,
  ) async {
    await zeige(
      tester,
      held: weltlich(),
      repository: _LesefehlerRepository(weltlich()),
    );
    expect(
      find.textContaining('Spielwerte konnten nicht geladen werden'),
      findsOneWidget,
    );
  });

  testWidgets('gespeicherter Zustand erscheint unverkürzt in der Anzeige', (
    tester,
  ) async {
    await zeige(
      tester,
      held: weltlich(),
      zustaende: {'praiodan': const HeroState.empty().copyWith(currentLep: -3)},
    );
    expect(find.textContaining('-3 /'), findsOneWidget);
  });

  testWidgets('Ressourcenänderung im Repository schlägt in der Anzeige durch', (
    tester,
  ) async {
    final repo = FakeRepository(heroes: [weltlich()]);
    await zeige(tester, held: weltlich(), repository: repo);
    final vorher = await repo.loadHeroState('praiodan');
    await repo.saveHeroState(
      'praiodan',
      (vorher ?? const HeroState.empty()).copyWith(currentLep: 7),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('7 /'), findsOneWidget);
  });

  group('laufendes Abenteuer im Abenteuerabschnitt', () {
    testWidgets('Titel, Datum und Kurzbeschreibung stehen im Abschnitt', (
      tester,
    ) async {
      await zeige(tester, held: mitAbenteuern([_nebel]), breite: 1024);
      // Der Seitenkopf bleibt schlicht und wiederholt nichts.
      final theme = Theme.of(tester.element(find.text('Am Spieltisch')));
      expect(
        tester.widget<Text>(find.text('Am Spieltisch')).style!.fontSize,
        theme.textTheme.titelGross.fontSize,
      );
      expect(find.text('Die Spuren im Nebel'), findsOneWidget);
      expect(find.text('12. Phex 1043 BF'), findsOneWidget);
      expect(
        find.text('Die Gruppe folgt der Spur des Nebelreiters.'),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text('Am Spieltisch')).dy,
        lessThan(tester.getTopLeft(find.text('Die Spuren im Nebel')).dy),
      );
    });

    testWidgets('ohne aktuellen Stand gilt das Startdatum', (tester) async {
      await zeige(
        tester,
        held: mitAbenteuern([
          _nebel.copyWith(
            currentAventurianDate: const HeroAdventureDateValue(),
          ),
        ]),
      );
      expect(find.text('1. Phex 1043 BF'), findsOneWidget);
    });

    testWidgets('abgeschlossene Abenteuer bleiben aus dem Abschnitt', (
      tester,
    ) async {
      await zeige(
        tester,
        held: mitAbenteuern([
          _nebel.copyWith(status: HeroAdventureStatus.completed),
        ]),
      );
      expect(find.text('Die Spuren im Nebel'), findsNothing);
      expect(find.textContaining('Phex'), findsNothing);
    });
  });

  for (final breite in [320.0, 390.0, 744.0, 1024.0, 1440.0]) {
    testWidgets('Spielansicht bei $breite dp ohne Überlauf', (tester) async {
      // Mit Abenteuerkopf: Titel, Datum und Zusammenfassung sind die
      // laengsten Zeilen der Ansicht.
      await zeige(
        tester,
        held: magisch().copyWith(adventures: const [_nebel]),
        breite: breite,
        skalierung: 2,
      );
      expect(ressource(KartoRessource.lebensenergie), findsOneWidget);
      expect(find.text('Ressourcen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  group('Regelnachschlag (SPIEL-04)', () {
    testWidgets('wird erst nach dem Entsperren der Katalog-Inhalte angeboten', (
      tester,
    ) async {
      await zeige(tester, held: weltlich(), breite: 1024);
      expect(
        find.byKey(const ValueKey<String>('karto-spiel-regeln')),
        findsNothing,
      );
      // Die übrigen Schnellaktionen bleiben unberührt.
      expect(find.text('Probe suchen'), findsOneWidget);
    });

    testWidgets('nach dem Entsperren steht der Knopf da', (tester) async {
      await zeige(
        tester,
        held: weltlich(),
        breite: 1024,
        regelnFreigeschaltet: true,
      );
      expect(
        find.byKey(const ValueKey<String>('karto-spiel-regeln')),
        findsOneWidget,
      );
    });

    testWidgets(
      'ohne Regelindex auf der Plattform bleibt er auch entsperrt weg',
      (tester) async {
        final bestand = TestBestand()..regelnVerfuegbar = false;
        await zeige(
          tester,
          held: weltlich(),
          breite: 1024,
          bestand: bestand,
          regelnFreigeschaltet: true,
        );
        expect(
          find.byKey(const ValueKey<String>('karto-spiel-regeln')),
          findsNothing,
        );
      },
    );
  });

  group('Abenteuerabschnitt', () {
    Finder schluessel(String name) => find.byKey(ValueKey<String>(name));

    testWidgets(
      'Schnellaktionen stehen vor den Ressourcen, dann das Abenteuer',
      (tester) async {
        await zeige(tester, held: mitAbenteuern([_nebel]));
        final aktionen = tester.getTopLeft(find.text('Schnellaktionen')).dy;
        final ressourcen = tester.getTopLeft(find.text('Ressourcen')).dy;
        final abenteuer = tester
            .getTopLeft(find.text('Die Spuren im Nebel'))
            .dy;
        final eigenschaften = tester.getTopLeft(find.text('Eigenschaften')).dy;
        expect(aktionen, lessThan(ressourcen));
        expect(ressourcen, lessThan(abenteuer));
        expect(abenteuer, lessThan(eigenschaften));
        expect(find.text('Alrik vom Blautann'), findsOneWidget);
        expect(find.text('Der Nebelreiter'), findsOneWidget);
      },
    );

    testWidgets('ohne laufendes Abenteuer bleibt der Standort', (tester) async {
      await zeige(
        tester,
        held: mitAbenteuern([
          _nebel.copyWith(status: HeroAdventureStatus.completed),
        ]),
      );
      expect(schluessel('karto-spiel-abenteuer-oeffnen'), findsNothing);
      expect(schluessel('karto-spiel-abenteuer-leer'), findsOneWidget);
      expect(schluessel('karto-spiel-standort-aendern'), findsOneWidget);
      expect(find.text('Der Nebelreiter'), findsNothing);
      expect(schluessel('karto-spiel-abenteuer-schnellnotiz'), findsNothing);
    });

    testWidgets('der Standort steht im Abschnitt, nicht in der Seitenspalte', (
      tester,
    ) async {
      await zeige(
        tester,
        held: mitAbenteuern([_nebel]),
        zustaende: {
          'praiodan': const HeroState.empty().copyWith(standort: 'Gareth'),
        },
        breite: 1440,
      );
      expect(find.text('Gareth'), findsOneWidget);
      expect(find.text('Standort'), findsNothing);
      final standort = tester.getTopLeft(find.text('Gareth')).dx;
      final kampf = tester.getTopLeft(find.text('Kampf')).dx;
      expect(standort, lessThan(kampf));
    });

    testWidgets('Standort speichert über die Brücke', (tester) async {
      final bestand = TestBestand();
      await zeige(tester, held: mitAbenteuern([_nebel]), bestand: bestand);
      await tester.ensureVisible(schluessel('karto-spiel-standort-aendern'));
      await tester.tap(schluessel('karto-spiel-standort-aendern'));
      await tester.pumpAndSettle();
      await tester.enterText(schluessel('karto-spiel-standort-feld'), 'Havena');
      await tester.tap(schluessel('karto-spiel-standort-speichern'));
      await tester.pumpAndSettle();
      expect(bestand.aufrufe, contains('standort:praiodan:Havena'));
    });

    testWidgets('Öffnen prüft zuerst die Verwaltung', (tester) async {
      var geprueft = 0;
      await zeige(
        tester,
        held: mitAbenteuern([_nebel]),
        vorAbenteuer: () async {
          geprueft++;
          return false;
        },
      );
      await tester.ensureVisible(schluessel('karto-spiel-abenteuer-oeffnen'));
      await tester.tap(schluessel('karto-spiel-abenteuer-oeffnen'));
      await tester.pumpAndSettle();
      expect(geprueft, 1);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('Öffnen zeigt das Abenteuerblatt', (tester) async {
      await zeige(tester, held: mitAbenteuern([_nebel]), breite: 1024);
      await tester.ensureVisible(schluessel('karto-spiel-abenteuer-oeffnen'));
      await tester.tap(schluessel('karto-spiel-abenteuer-oeffnen'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('eine Karte bearbeitet direkt, ohne Blatt', (tester) async {
      await zeige(tester, held: mitAbenteuern([_nebel]), breite: 1024);
      await tester.ensureVisible(find.text('Der Nebelreiter'));
      await tester.tap(find.text('Der Nebelreiter'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Notiz bearbeiten'), findsOneWidget);
    });

    testWidgets('Schnellnotiz wird gespeichert und erscheint sofort', (
      tester,
    ) async {
      final repo = FakeRepository(
        heroes: [
          mitAbenteuern([_nebel]),
        ],
      );
      await zeige(
        tester,
        held: mitAbenteuern([_nebel]),
        repository: repo,
        breite: 1024,
      );
      final feld = schluessel('karto-spiel-abenteuer-schnellnotiz');
      await tester.ensureVisible(feld);
      await tester.enterText(feld, 'Brücke ist gesperrt');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      final abenteuer = (await repo.loadHeroById('praiodan'))!
          .adventures
          .single;
      expect(abenteuer.notes.map((n) => n.title), [
        'Der Nebelreiter',
        'Brücke ist gesperrt',
      ]);
      expect(find.text('Brücke ist gesperrt'), findsOneWidget);
      // Das Feld ist für die nächste Notiz wieder leer.
      expect(tester.widget<TextField>(feld).controller!.text, isEmpty);
    });

    testWidgets('leere Schnellnotiz schreibt nichts', (tester) async {
      final repo = FakeRepository(
        heroes: [
          mitAbenteuern([_nebel]),
        ],
      );
      await zeige(tester, held: mitAbenteuern([_nebel]), repository: repo);
      final feld = schluessel('karto-spiel-abenteuer-schnellnotiz');
      await tester.ensureVisible(feld);
      await tester.enterText(feld, '   ');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      final abenteuer = (await repo.loadHeroById('praiodan'))!
          .adventures
          .single;
      expect(abenteuer.notes, hasLength(1));
    });

    testWidgets('Schnellnotiz übernimmt Standort und Datum des Abenteuers', (
      tester,
    ) async {
      final repo = FakeRepository(
        heroes: [
          mitAbenteuern([_nebel]),
        ],
        states: {
          'praiodan': const HeroState.empty().copyWith(standort: 'Gareth'),
        },
      );
      await zeige(
        tester,
        held: mitAbenteuern([_nebel]),
        repository: repo,
        breite: 1024,
      );
      final feld = schluessel('karto-spiel-abenteuer-schnellnotiz');
      await tester.ensureVisible(feld);
      await tester.enterText(feld, 'Brücke ist gesperrt');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      final notiz = (await repo.loadHeroById('praiodan'))!
          .adventures
          .single
          .notes
          .last;
      expect(notiz.ort, 'Gareth');
      expect(notiz.datum, '12. Phex 1043 BF');
      expect(find.text('Gareth · 12. Phex 1043 BF'), findsOneWidget);
    });

    testWidgets('ohne Standort und Datum bleiben Ort und Datum leer', (
      tester,
    ) async {
      final ohneDatum = mitAbenteuern([
        _nebel.copyWith(
          currentAventurianDate: const HeroAdventureDateValue(),
          startAventurianDate: const HeroAdventureDateValue(),
        ),
      ]);
      final repo = FakeRepository(heroes: [ohneDatum]);
      await zeige(tester, held: ohneDatum, repository: repo, breite: 1024);
      final feld = schluessel('karto-spiel-abenteuer-schnellnotiz');
      await tester.ensureVisible(feld);
      await tester.enterText(feld, 'Nur ein Hinweis');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      final notiz = (await repo.loadHeroById('praiodan'))!
          .adventures
          .single
          .notes
          .last;
      expect(notiz.ort, isEmpty);
      expect(notiz.datum, isEmpty);
      // Ohne beides keine leere Kontextzeile und kein Eintrag im JSON.
      expect(notiz.toJson().containsKey('ort'), isFalse);
      expect(notiz.toJson().containsKey('datum'), isFalse);
    });

    group('Suche', () {
      const alt = HeroAdventureEntry(
        id: 'alt',
        title: 'Die alte Fracht',
        status: HeroAdventureStatus.completed,
        notes: [
          HeroNoteEntry(
            title: 'Nebelpass',
            description: 'Zoll am Pass.',
            ort: 'Punin',
            datum: '3. Rahja 1040 BF',
          ),
        ],
        people: [
          HeroAdventurePersonEntry(
            id: 'p9',
            name: 'Zöllner Bero',
            description: 'Kennt den Nebelpass.',
          ),
        ],
      );

      Future<void> suche(WidgetTester tester, String text) async {
        // Beim zweiten Aufruf ist das Feld schon offen.
        if (schluessel('karto-abenteuer-suche').evaluate().isEmpty) {
          final knopf = schluessel('karto-abenteuer-suche-knopf');
          await tester.ensureVisible(knopf);
          await tester.tap(knopf);
          await tester.pumpAndSettle();
        }
        await tester.enterText(schluessel('karto-abenteuer-suche'), text);
        await tester.pumpAndSettle();
      }

      testWidgets('findet Treffer aller Abenteuer, das laufende steht vorn', (
        tester,
      ) async {
        await zeige(tester, held: mitAbenteuern([alt, _nebel]), breite: 1024);
        await suche(tester, 'nebel');

        expect(schluessel('karto-abenteuer-suche-anzahl'), findsOneWidget);
        expect(find.text('3 Treffer in 2 Abenteuern'), findsOneWidget);
        expect(find.text('Laufendes Abenteuer'), findsOneWidget);
        expect(find.text('Abgeschlossen'), findsOneWidget);
        // Das laufende Abenteuer steht vor dem abgeschlossenen, obwohl es in
        // der Liste des Helden hinten steht.
        expect(
          tester.getTopLeft(find.text('Der Nebelreiter')).dy,
          lessThan(tester.getTopLeft(find.text('Nebelpass')).dy),
        );
        // Ort und Datum stehen an der Karte.
        expect(find.text('Punin · 3. Rahja 1040 BF'), findsOneWidget);
      });

      testWidgets('sucht in Ort und Datum und ohne Rücksicht auf Umlaute', (
        tester,
      ) async {
        await zeige(tester, held: mitAbenteuern([alt, _nebel]), breite: 1024);
        await suche(tester, 'punin');
        expect(find.text('Nebelpass'), findsOneWidget);
        expect(find.text('Der Nebelreiter'), findsNothing);

        await suche(tester, 'zollner');
        expect(find.text('Zöllner Bero'), findsOneWidget);
      });

      testWidgets('ein Treffer im laufenden Abenteuer bearbeitet direkt', (
        tester,
      ) async {
        await zeige(tester, held: mitAbenteuern([alt, _nebel]), breite: 1024);
        await suche(tester, 'reiter');
        await tester.tap(find.text('Der Nebelreiter'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text('Notiz bearbeiten'), findsOneWidget);
      });

      testWidgets(
        'ein Treffer in einem anderen Abenteuer öffnet dessen Blatt',
        (tester) async {
          await zeige(tester, held: mitAbenteuern([alt, _nebel]), breite: 1024);
          await suche(tester, 'zoll');
          await tester.tap(find.text('Nebelpass'));
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget);
          // Das Blatt des abgeschlossenen Abenteuers hat seine eigene
          // Anlege-Kachel; der Titel steht jetzt auch im Blatt.
          expect(schluessel('karto-abenteuer-notiz-neu'), findsOneWidget);
          expect(find.text('Die alte Fracht'), findsNWidgets(2));
        },
      );

      testWidgets('ohne Treffer sagt die Suche das, und Schließen räumt auf', (
        tester,
      ) async {
        await zeige(tester, held: mitAbenteuern([alt, _nebel]), breite: 1024);
        await suche(tester, 'drachenhort');
        expect(schluessel('karto-abenteuer-suche-leer'), findsOneWidget);
        expect(find.byType(KartoNotizkarte), findsNothing);

        await tester.tap(schluessel('karto-abenteuer-suche-schliessen'));
        await tester.pumpAndSettle();
        expect(schluessel('karto-abenteuer-suche'), findsNothing);
        expect(find.text('Der Nebelreiter'), findsOneWidget);
      });

      testWidgets(
        'ohne laufendes Abenteuer durchsucht sie die abgeschlossenen',
        (tester) async {
          await zeige(tester, held: mitAbenteuern([alt]), breite: 1024);
          await suche(tester, 'bero');
          expect(find.text('Zöllner Bero'), findsOneWidget);
          expect(find.text('Laufendes Abenteuer'), findsNothing);
          expect(find.text('Abgeschlossen'), findsOneWidget);
        },
      );
    });

    testWidgets('weitere Karten klappen inline auf', (tester) async {
      final viele = _nebel.copyWith(
        notes: [
          for (var i = 1; i <= 6; i++)
            HeroNoteEntry(title: 'Notiz $i', description: ''),
        ],
      );
      await zeige(tester, held: mitAbenteuern([viele]), breite: 1024);
      expect(find.byType(KartoNotizkarte), findsNWidgets(4));
      final alle = schluessel('karto-spiel-abenteuer-alle');
      await tester.ensureVisible(alle);
      await tester.tap(alle);
      await tester.pumpAndSettle();
      expect(find.byType(KartoNotizkarte), findsNWidgets(6));
      await tester.ensureVisible(alle);
      await tester.tap(alle);
      await tester.pumpAndSettle();
      expect(find.byType(KartoNotizkarte), findsNWidgets(4));
    });

    testWidgets('eine offene Planung schützt das Abenteuer', (tester) async {
      final container = await zeige(tester, held: mitAbenteuern([_nebel]));
      container
          .read(advancementSessionProvider('praiodan').notifier)
          .start(hero: mitAbenteuern([_nebel]), catalog: testCatalog);
      await tester.pumpAndSettle();
      expect(schluessel('karto-spiel-abenteuer-gesperrt'), findsOneWidget);
      expect(schluessel('karto-spiel-abenteuer-schnellnotiz'), findsNothing);
      expect(schluessel('karto-spiel-abenteuer-person-neu'), findsNothing);
      // Lesen bleibt möglich; Karten sind nur nicht mehr antippbar.
      expect(find.text('Der Nebelreiter'), findsOneWidget);
    });

    testWidgets('lange Kurzbeschreibung lässt sich aufklappen', (tester) async {
      final lang = _nebel.copyWith(summary: List.filled(40, 'Nebel').join(' '));
      await zeige(tester, held: mitAbenteuern([lang]));
      final text = schluessel('karto-spiel-abenteuer-zusammenfassung');
      expect(tester.widget<Text>(text).maxLines, 3);
      await tester.ensureVisible(schluessel('karto-spiel-abenteuer-mehr'));
      await tester.tap(schluessel('karto-spiel-abenteuer-mehr'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(text).maxLines, isNull);
    });
  });

  group('Vor- und Nachteile', () {
    testWidgets('stehen nach den Eigenschaften und vor dem Kampf', (
      tester,
    ) async {
      await zeige(
        tester,
        held: weltlich().copyWith(
          vorteileText: 'Flink',
          nachteileText: 'Goldgier 6',
        ),
      );
      final titel = find.text('Vor- und Nachteile');
      expect(titel, findsOneWidget);
      expect(find.textContaining('Flink'), findsOneWidget);
      expect(find.textContaining('Goldgier 6'), findsOneWidget);
      final oben = tester.getTopLeft(find.text('Eigenschaften')).dy;
      final mitte = tester.getTopLeft(titel).dy;
      final unten = tester.getTopLeft(find.text('Kampf')).dy;
      expect(oben < mitte && mitte < unten, isTrue);
    });

    testWidgets('Bearbeiten prüft zuerst die Verwaltung', (tester) async {
      var geprueft = 0;
      await zeige(
        tester,
        held: weltlich(),
        breite: 1024,
        vorAbenteuer: () async {
          geprueft++;
          return false;
        },
      );
      await tester.tap(find.byKey(const ValueKey('karto-spiel-merkmale')));
      await tester.pumpAndSettle();
      expect(geprueft, 1);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('Bearbeiten öffnet das Merkmalsblatt', (tester) async {
      await zeige(tester, held: weltlich(), breite: 1024);
      await tester.tap(find.byKey(const ValueKey('karto-spiel-merkmale')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.byKey(const ValueKey('karto-merkmal-neu-vorteile')),
        findsOneWidget,
      );
    });
  });

  testWidgets('dunkle Palette rendert dieselbe Anordnung', (tester) async {
    await zeige(
      tester,
      held: geweiht(),
      breite: 1440,
      helligkeit: Brightness.dark,
    );
    expect(ressource(KartoRessource.karma), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Repository, dessen Zustandsstrom fehlschlägt.
class _LesefehlerRepository extends FakeRepository {
  _LesefehlerRepository(HeroSheet held) : super(heroes: [held]);

  @override
  Stream<HeroState> watchHeroState(String heroId) =>
      Stream<HeroState>.error(StateError('Lesefehler'));
}
