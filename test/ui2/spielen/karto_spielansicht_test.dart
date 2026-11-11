import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spielansicht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_base_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_karten.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelraster.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_wuerfelprotokoll.dart';
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

const _viele = HeroAdventureEntry(
  id: 'viele',
  title: 'Der lange Weg',
  summary: 'Eine Reise mit vielen Begegnungen.',
  startAventurianDate: HeroAdventureDateValue(
    day: '1',
    month: 'phex',
    year: '1043',
  ),
  currentAventurianDate: HeroAdventureDateValue(
    day: '5',
    month: 'phex',
    year: '1043',
  ),
  notes: [
    HeroNoteEntry(title: 'Die Furt', description: 'Nur bei Niedrigwasser.'),
    HeroNoteEntry(title: 'Der Zoll', description: 'Zwei Dukaten je Karren.'),
    HeroNoteEntry(title: 'Das Gerücht', description: 'Ein Schatz im Moor.'),
  ],
  people: [
    HeroAdventurePersonEntry(
      id: 'p1',
      name: 'Alrik vom Blautann',
      description: 'Wirt des „Grünen Krugs“.',
    ),
    HeroAdventurePersonEntry(
      id: 'p2',
      name: 'Thesia',
      description: 'Fährfrau an der Furt.',
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
    double hoehe = 1000,
    double skalierung = 1,
    Brightness helligkeit = Brightness.light,
    Future<bool> Function()? vorAbenteuer,
    bool regelnFreigeschaltet = false,
    HiveSettingsRepository? einstellungen,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, hoehe);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(
          repository ?? FakeRepository(heroes: [held], states: zustaende),
        ),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        if (einstellungen != null)
          settingsRepositoryProvider.overrideWithValue(einstellungen),
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
      // Das Datum des Abschnitts; die Wildnis-Kachel nennt den Monat der
      // Jahreszeit, daher nicht der Monatsname allein.
      expect(find.textContaining('1043 BF'), findsNothing);
    });
  });

  for (final breite in [320.0, 390.0, 744.0, 840.0, 1024.0, 1440.0, 1920.0]) {
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

  group('Würfelprotokoll', () {
    List<DiceLogEntry> wuerfe(int anzahl) => [
      for (var i = 0; i < anzahl; i++)
        DiceLogEntry(
          timestamp: DateTime.utc(2026, 9, 20, 20, i),
          type: ProbeType.attribute,
          title: 'Wurf $i',
          subtitle: 'MU',
          success: true,
          diceValues: const [5],
        ),
    ];

    testWidgets('zeigt knapp fünf und öffnet die ganze Historie', (
      tester,
    ) async {
      final bestand = TestBestand();
      await zeige(
        tester,
        held: weltlich(),
        bestand: bestand,
        zustaende: {
          'praiodan': const HeroState.empty().copyWith(diceLog: wuerfe(7)),
        },
      );
      expect(bestand.protokollGrenzen, everyElement(5));
      final alle = find.byKey(
        const ValueKey<String>('karto-spiel-protokoll-alle'),
      );
      expect(find.text('Alle anzeigen (7)'), findsOneWidget);
      await tester.ensureVisible(alle);
      await tester.tap(alle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('karto-spiel-protokoll-blatt')),
        findsOneWidget,
      );
      expect(bestand.protokollGrenzen.last, isNull);
      await tester.tap(find.byTooltip('Schließen'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('karto-spiel-protokoll-blatt')),
        findsNothing,
      );
    });

    testWidgets('bis fünf Würfe gibt es nichts zu öffnen', (tester) async {
      await zeige(
        tester,
        held: weltlich(),
        zustaende: {
          'praiodan': const HeroState.empty().copyWith(diceLog: wuerfe(5)),
        },
      );
      expect(
        find.byKey(const ValueKey<String>('karto-spiel-protokoll-alle')),
        findsNothing,
      );
    });

    group('weite Stufe (SPIEL-07)', () {
      HeroSheet mitBreite(SpielkachelBreite? breite) => weltlich().copyWith(
        spielansicht: breite == null
            ? null
            : HeroSpielansicht(
                kacheln: [HeroSpielkachel(id: 'protokoll', breite: breite)],
              ),
      );

      Map<String, HeroState> zustand(int anzahl) => {
        'praiodan': const HeroState.empty().copyWith(diceLog: wuerfe(anzahl)),
      };

      testWidgets('mittel baut acht Würfe und öffnet erst ab neun', (
        tester,
      ) async {
        final bestand = TestBestand();
        await zeige(
          tester,
          held: mitBreite(SpielkachelBreite.mittel),
          bestand: bestand,
          zustaende: zustand(9),
          breite: 1280,
        );
        expect(bestand.protokollGrenzen, everyElement(kProtokollWeit));
        expect(find.text('Alle anzeigen (9)'), findsOneWidget);

        await zeige(
          tester,
          held: mitBreite(SpielkachelBreite.mittel),
          zustaende: zustand(8),
          breite: 1280,
        );
        expect(
          find.byKey(const ValueKey<String>('karto-spiel-protokoll-alle')),
          findsNothing,
        );
      });

      testWidgets('die Standardbreite bleibt bei fünf Würfen', (tester) async {
        final bestand = TestBestand();
        await zeige(
          tester,
          held: mitBreite(null),
          bestand: bestand,
          zustaende: zustand(9),
          breite: 390,
        );
        expect(bestand.protokollGrenzen, everyElement(kProtokollKurz));
        expect(find.text('Alle anzeigen (9)'), findsOneWidget);
      });

      testWidgets('der Vergrößern-Dialog baut die weite Fassung', (
        tester,
      ) async {
        final bestand = TestBestand();
        await zeige(
          tester,
          held: mitBreite(null),
          bestand: bestand,
          zustaende: zustand(9),
          breite: 1280,
        );
        bestand.protokollGrenzen.clear();
        final vergroessern = find.byKey(
          const ValueKey<String>('karto-kachel-protokoll-vergroessern'),
        );
        await tester.ensureVisible(vergroessern);
        await tester.tap(vergroessern);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('karto-kachel-protokoll-popup')),
          findsOneWidget,
        );
        expect(bestand.protokollGrenzen.last, kProtokollWeit);
      });

      for (final breite in [744.0, 1024.0, 1440.0, 1920.0]) {
        for (final skalierung in [1.0, 2.0]) {
          testWidgets('mittel bei $breite dp, Schrift $skalierung, ohne '
              'Überlauf, auch im Anordnen', (tester) async {
            await zeige(
              tester,
              held: mitBreite(SpielkachelBreite.mittel),
              zustaende: zustand(12),
              breite: breite,
              skalierung: skalierung,
            );
            expect(tester.takeException(), isNull);
            await tester.tap(
              find.byKey(const ValueKey<String>('karto-spiel-anordnen')),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          });
        }
      }
    });
  });

  group('Zuletzt gewürfelt', () {
    DiceLogEntry talent(String name, int minute) => DiceLogEntry(
      timestamp: DateTime.utc(2026, 10, 24, 20, minute),
      type: ProbeType.talent,
      title: 'Talentprobe: $name',
      subtitle: 'MU/KL/GE',
      success: true,
      diceValues: const [5, 8, 12],
    );

    Finder marke(String name) => find.byKey(
      ValueKey<String>('karto-spiel-zuletzt-talent-Talentprobe: $name'),
    );

    testWidgets('zeigt jede Probe einmal und wiederholt sie per Tipp', (
      tester,
    ) async {
      final bestand = TestBestand();
      await zeige(
        tester,
        held: weltlich(),
        bestand: bestand,
        zustaende: {
          'praiodan': const HeroState.empty().copyWith(
            diceLog: [
              talent('Klettern', 1),
              talent('Schleichen', 2),
              talent('Klettern', 3),
            ],
          ),
        },
      );
      expect(find.text('Zuletzt gewürfelt'), findsOneWidget);
      expect(marke('Klettern'), findsOneWidget);
      expect(marke('Schleichen'), findsOneWidget);
      await tester.ensureVisible(marke('Schleichen'));
      await tester.tap(marke('Schleichen'));
      await tester.pumpAndSettle();
      expect(
        bestand.aufrufe,
        contains('probeWiederholen:praiodan:Talentprobe: Schleichen'),
      );
    });

    testWidgets('bleibt ohne wiederholbaren Wurf unsichtbar', (tester) async {
      await zeige(tester, held: weltlich());
      expect(find.text('Zuletzt gewürfelt'), findsNothing);
    });
  });

  group('Kachel vergrößern', () {
    Finder k(String name) => find.byKey(ValueKey<String>(name));

    testWidgets('Klick auf den Namen öffnet die Kachel als Dialog', (
      tester,
    ) async {
      await zeige(tester, held: mitAbenteuern([_nebel]), breite: 1280);
      expect(k('karto-kachel-ressourcen-popup'), findsNothing);
      expect(find.text('Ressourcen'), findsOneWidget);

      await tester.tap(k('karto-kachel-ressourcen-vergroessern'));
      await tester.pumpAndSettle();
      expect(k('karto-kachel-ressourcen-popup'), findsOneWidget);
      // Der Inhalt steht jetzt zweimal da: in der Kachel und im Dialog.
      expect(find.text('Ressourcen'), findsNWidgets(2));
      // Der Dialog hat keine Bedienknöpfe der Kachel (Einklappen).
      expect(
        find.descendant(
          of: k('karto-kachel-ressourcen-popup'),
          matching: find.byIcon(Icons.expand_less),
        ),
        findsNothing,
      );

      await tester.tap(k('karto-kachel-popup-zu'));
      await tester.pumpAndSettle();
      expect(k('karto-kachel-ressourcen-popup'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('jede Kachel lässt sich vergrößern und schließen', (
      tester,
    ) async {
      await zeige(tester, held: mitAbenteuern([_nebel]), breite: 1280);
      for (final art in [
        'ressourcen',
        'proben',
        'eigenschaften',
        'kampf',
        'effekte',
        'zustand',
        'dabei',
        'abenteuer',
        'merkmale',
        'wildnis',
        'protokoll',
      ]) {
        await tester.ensureVisible(k('karto-kachel-$art-vergroessern'));
        await tester.tap(k('karto-kachel-$art-vergroessern'));
        await tester.pumpAndSettle();
        expect(k('karto-kachel-$art-popup'), findsOneWidget, reason: art);
        await tester.tap(k('karto-kachel-popup-zu'));
        await tester.pumpAndSettle();
        expect(k('karto-kachel-$art-popup'), findsNothing, reason: art);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('auch schmal und eingeklappt öffnet der Name den Dialog', (
      tester,
    ) async {
      await zeige(
        tester,
        held: weltlich().copyWith(
          spielansicht: const HeroSpielansicht(
            kacheln: [HeroSpielkachel(id: 'kampf', eingeklappt: true)],
          ),
        ),
        breite: 390,
      );
      await tester.ensureVisible(k('karto-kachel-kampf-vergroessern'));
      await tester.tap(k('karto-kachel-kampf-vergroessern'));
      await tester.pumpAndSettle();
      expect(k('karto-kachel-kampf-popup'), findsOneWidget);
      expect(find.text('Kampfproben praiodan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('im Anordnen-Modus gibt es keinen Vergrößern-Knopf', (
      tester,
    ) async {
      await zeige(tester, held: weltlich(), breite: 1280);
      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();
      expect(k('karto-kachel-ressourcen-vergroessern'), findsNothing);
    });
  });

  group('Schnellaktionen im Seitenkopf', () {
    Finder k(String name) => find.byKey(ValueKey<String>(name));

    testWidgets('breit: zwischen Titel und Anordnen, in einer Zeile', (
      tester,
    ) async {
      await zeige(
        tester,
        held: weltlich(),
        breite: 1600,
        regelnFreigeschaltet: true,
      );
      final titel = tester.getRect(find.text('Am Spieltisch'));
      final probe = tester.getRect(k('karto-spiel-probe'));
      final schaden = tester.getRect(k('karto-spiel-schaden'));
      final anordnen = tester.getRect(k('karto-spiel-anordnen'));
      expect(probe.left, greaterThan(titel.right));
      expect(schaden.right, lessThan(anordnen.left));
      expect(probe.center.dy, closeTo(titel.center.dy, 40));
      // Alle Knöpfe stehen in einer Reihe.
      for (final name in ['gefecht', 'regeln', 'rast', 'schaden']) {
        final knopf = tester.getRect(k('karto-spiel-$name'));
        expect(knopf.center.dy, closeTo(probe.center.dy, 1), reason: name);
      }
      // „Anordnen“ steht ganz rechts, am Rand der Kacheln (Seitenrand 36).
      expect(anordnen.right, closeTo(1600 - 36 - 12, 14));
      // Das Kürzel ist kein Chip neben den Knöpfen mehr.
      expect(find.text('Strg K'), findsNothing);
      // Keine Kachel mehr: kein Abschnitt dieses Namens, kein Raster-Eintrag.
      expect(find.text('Schnellaktionen'), findsNothing);
      expect(k('karto-kachel-schnellaktionen'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mittelbreit: Knöpfe unter Titel und Anordnen', (tester) async {
      await zeige(
        tester,
        held: weltlich(),
        breite: 1100,
        regelnFreigeschaltet: true,
      );
      final titel = tester.getRect(find.text('Am Spieltisch'));
      final anordnen = tester.getRect(k('karto-spiel-anordnen'));
      final probe = tester.getRect(k('karto-spiel-probe'));
      expect(anordnen.center.dy, closeTo(titel.center.dy, 40));
      expect(probe.top, greaterThan(titel.bottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('schmal: unter der Titelzeile, vor allen Kacheln', (
      tester,
    ) async {
      await zeige(tester, held: weltlich(), breite: 390);
      final titel = tester.getRect(find.text('Am Spieltisch'));
      final probe = tester.getRect(k('karto-spiel-probe'));
      final ressourcen = tester.getTopLeft(find.text('Ressourcen'));
      expect(probe.top, greaterThan(titel.bottom));
      expect(probe.bottom, lessThan(ressourcen.dy));
      expect(tester.takeException(), isNull);
    });

    testWidgets('bleiben im Anordnen-Modus fest stehen', (tester) async {
      await zeige(tester, held: weltlich(), breite: 1600);
      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();
      expect(k('karto-spiel-probe'), findsOneWidget);
      expect(k('karto-spiel-rast'), findsOneWidget);
      expect(k('karto-spiel-anordnen-fertig'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('jede Schnellaktion trägt ihre eigene Farbe', (tester) async {
    await zeige(
      tester,
      held: weltlich(),
      breite: 1024,
      regelnFreigeschaltet: true,
    );
    final farben = <Color?>{
      for (final name in [
        'karto-spiel-gefecht',
        'karto-spiel-probe',
        'karto-spiel-regeln',
        'karto-spiel-rast',
        'karto-spiel-schaden',
      ])
        tester
            .widget<ButtonStyleButton>(find.byKey(ValueKey<String>(name)))
            .style!
            .iconColor!
            .resolve(<WidgetState>{}),
    };
    expect(farben, hasLength(5));
    expect(farben, isNot(contains(null)));
  });

  group('Kachelraster (SPIEL-07)', () {
    Finder k(String schluessel) => find.byKey(ValueKey<String>(schluessel));

    // Gemessen wird die Breite der Ansicht; im Workspace zieht die
    // Navigation 248 dp ab.
    testWidgets('drei Spalten: Kampf steht rechts neben den Ressourcen', (
      tester,
    ) async {
      await zeige(tester, held: mitAbenteuern([_nebel]), breite: 1280);
      final ressourcen = tester.getTopLeft(find.text('Ressourcen'));
      final proben = tester.getTopLeft(find.text('Häufige Proben'));
      final kampf = tester.getTopLeft(find.text('Kampf'));
      expect(kampf.dx, greaterThan(ressourcen.dx + kRasterEinheitMin));
      expect(kampf.dy, lessThan(proben.dy));
      expect(tester.takeException(), isNull);
    });

    testWidgets('eine Spalte: Kampf folgt den Eigenschaften, vor dem '
        'Abenteuer', (tester) async {
      await zeige(tester, held: mitAbenteuern([_nebel]), breite: 390);
      final ressourcen = tester.getTopLeft(find.text('Ressourcen'));
      final kampf = tester.getTopLeft(find.text('Kampf'));
      final abenteuer = tester.getTopLeft(find.text('Die Spuren im Nebel'));
      expect(kampf.dx, lessThan(390 / 2));
      expect(kampf.dy, greaterThan(ressourcen.dy));
      expect(kampf.dy, lessThan(abenteuer.dy));
    });

    testWidgets('gespeicherte Anordnung bestimmt Reihenfolge und Ausblenden', (
      tester,
    ) async {
      await zeige(
        tester,
        held: mitAbenteuern([_nebel]).copyWith(
          spielansicht: const HeroSpielansicht(
            kacheln: [
              HeroSpielkachel(id: 'kampf'),
              HeroSpielkachel(id: 'ressourcen'),
              HeroSpielkachel(id: 'protokoll', ausgeblendet: true),
              HeroSpielkachel(id: 'zukunft_kachel'),
            ],
          ),
        ),
      );
      final kampf = tester.getTopLeft(find.text('Kampf'));
      final ressourcen = tester.getTopLeft(find.text('Ressourcen'));
      expect(kampf.dy, lessThan(ressourcen.dy));
      expect(find.text('Würfelprotokoll'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Anordnen: verschieben, Breite, ausblenden; Fertig schreibt '
        'einmal', (tester) async {
      final repo = _ZaehlendesRepository(heroes: [weltlich()]);
      await zeige(tester, held: weltlich(), repository: repo, breite: 1280);

      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();
      expect(k('karto-spiel-anordnen-fertig'), findsOneWidget);

      await tester.ensureVisible(k('karto-kachel-kampf-vor'));
      await tester.tap(k('karto-kachel-kampf-vor'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(k('karto-kachel-dabei-breite'));
      await tester.tap(k('karto-kachel-dabei-breite'));
      await tester.pumpAndSettle();
      await tester.tap(k('karto-kachel-dabei-breite-mittel').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(k('karto-kachel-protokoll-ausblenden'));
      await tester.tap(k('karto-kachel-protokoll-ausblenden'));
      await tester.pumpAndSettle();
      expect(k('karto-kachel-protokoll-einblenden'), findsOneWidget);
      expect(repo.speicherungen, 0);

      await tester.ensureVisible(k('karto-spiel-anordnen-fertig'));
      await tester.tap(k('karto-spiel-anordnen-fertig'));
      await tester.pumpAndSettle();
      expect(repo.speicherungen, 1);
      expect(k('karto-spiel-anordnen'), findsOneWidget);

      final ansicht = (await repo.loadHeroById('praiodan'))!.spielansicht!;
      final ids = ansicht.kacheln.map((k) => k.id).toList();
      expect(ids.indexOf('kampf'), lessThan(ids.indexOf('eigenschaften')));
      expect(ansicht.kachel('dabei')!.breite, SpielkachelBreite.mittel);
      expect(ansicht.kachel('protokoll')!.ausgeblendet, isTrue);
      // Standardbreiten werden nicht geschrieben.
      expect(ansicht.kachel('kampf')!.breite, isNull);
      expect(find.text('Würfelprotokoll'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // Zieht den Griff der Kachel [von] auf [ziel]; [anteil] ist die Stelle
    // in der Zielkarte (0 = linke Kante, 1 = rechte Kante).
    Future<TestGesture> ziehe(
      WidgetTester tester,
      String von,
      String ziel,
      double anteil,
    ) async {
      final griff = tester.getCenter(k('karto-kachel-$von-griff'));
      final rect = tester.getRect(k('karto-kachel-$ziel'));
      final ort = Offset(
        rect.left + rect.width * anteil,
        rect.top + rect.height / 2,
      );
      final geste = await tester.startGesture(griff);
      await geste.moveBy(const Offset(0, -20));
      await tester.pump();
      await geste.moveTo(ort);
      await tester.pump();
      return geste;
    }

    Future<List<String>> gespeicherteIds(
      WidgetTester tester,
      _ZaehlendesRepository repo,
    ) async {
      await tester.tap(k('karto-spiel-anordnen-fertig'));
      await tester.pumpAndSettle();
      return (await repo.loadHeroById('praiodan'))!.spielansicht!.kacheln
          .map((k) => k.id)
          .toList();
    }

    testWidgets('Ziehen: Linie zeigt davor, Loslassen fügt davor ein', (
      tester,
    ) async {
      final repo = _ZaehlendesRepository(heroes: [weltlich()]);
      await zeige(
        tester,
        held: weltlich(),
        repository: repo,
        breite: 1280,
        hoehe: 2400,
      );
      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();

      // Die Karte zeigt den Inhalt nur als gesperrte Vorschau.
      expect(k('karto-kachel-effekte-vorschau'), findsOneWidget);

      final geste = await ziehe(tester, 'zustand', 'ressourcen', 0.1);
      expect(k('karto-einfuegelinie-davor'), findsOneWidget);
      expect(k('karto-einfuegelinie-danach'), findsNothing);
      await geste.up();
      await tester.pumpAndSettle();
      expect(k('karto-einfuegelinie-davor'), findsNothing);

      final ids = await gespeicherteIds(tester, repo);
      expect(ids.first, 'zustand');
      expect(ids[1], 'ressourcen');
    });

    testWidgets('Ziehen: Loslassen auf der hinteren Hälfte fügt danach ein', (
      tester,
    ) async {
      final repo = _ZaehlendesRepository(heroes: [weltlich()]);
      await zeige(
        tester,
        held: weltlich(),
        repository: repo,
        breite: 1280,
        hoehe: 2400,
      );
      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();

      final geste = await ziehe(tester, 'zustand', 'ressourcen', 0.9);
      expect(k('karto-einfuegelinie-danach'), findsOneWidget);
      await geste.up();
      await tester.pumpAndSettle();

      final ids = await gespeicherteIds(tester, repo);
      expect(ids.indexOf('zustand'), ids.indexOf('ressourcen') + 1);
    });

    testWidgets('Ziehen und Wegziehen ohne Loslassen auf dem Ziel ändert '
        'nichts', (tester) async {
      final repo = _ZaehlendesRepository(heroes: [weltlich()]);
      await zeige(
        tester,
        held: weltlich(),
        repository: repo,
        breite: 1280,
        hoehe: 2400,
      );
      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();

      final geste = await ziehe(tester, 'zustand', 'ressourcen', 0.1);
      await geste.moveTo(const Offset(2, 2));
      await tester.pump();
      expect(k('karto-einfuegelinie-davor'), findsNothing);
      await geste.up();
      await tester.pumpAndSettle();
      await tester.tap(k('karto-spiel-anordnen-fertig'));
      await tester.pumpAndSettle();
      expect(repo.speicherungen, 0);
    });

    testWidgets('Abbrechen und unveränderte Anordnung schreiben nichts', (
      tester,
    ) async {
      final repo = _ZaehlendesRepository(heroes: [weltlich()]);
      await zeige(tester, held: weltlich(), repository: repo, breite: 1280);
      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();
      await tester.tap(k('karto-kachel-kampf-vor'));
      await tester.pumpAndSettle();
      await tester.tap(k('karto-spiel-anordnen-abbrechen'));
      await tester.pumpAndSettle();

      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();
      await tester.tap(k('karto-spiel-anordnen-fertig'));
      await tester.pumpAndSettle();
      expect(repo.speicherungen, 0);
      expect((await repo.loadHeroById('praiodan'))!.spielansicht, isNull);
    });

    testWidgets('ein offener Verwaltungsentwurf verhindert das Anordnen', (
      tester,
    ) async {
      await zeige(
        tester,
        held: weltlich(),
        breite: 1280,
        vorAbenteuer: () async => false,
      );
      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();
      expect(k('karto-spiel-anordnen-fertig'), findsNothing);
    });

    testWidgets('Einklappen schreibt sofort und blendet den Inhalt aus', (
      tester,
    ) async {
      final repo = _ZaehlendesRepository(heroes: [weltlich()]);
      await zeige(tester, held: weltlich(), repository: repo, breite: 1280);
      expect(find.text('Effekte verwalten'), findsOneWidget);
      // Nicht einklappbare Kacheln haben keinen Knopf.
      expect(k('karto-kachel-ressourcen-einklappen'), findsNothing);

      await tester.ensureVisible(k('karto-kachel-kampf-einklappen'));
      await tester.tap(k('karto-kachel-kampf-einklappen'));
      await tester.pumpAndSettle();
      expect(repo.speicherungen, 1);
      final held = (await repo.loadHeroById('praiodan'))!;
      expect(held.spielansicht!.kachel('kampf')!.eingeklappt, isTrue);
      expect(held.spielansicht!.kacheln, hasLength(1));

      await tester.tap(k('karto-kachel-kampf-einklappen'));
      await tester.pumpAndSettle();
      final danach = (await repo.loadHeroById('praiodan'))!.spielansicht!;
      expect(danach.kachel('kampf')!.eingeklappt, isFalse);
    });

    testWidgets('eine offene Planung sperrt Anordnen und Einklappen', (
      tester,
    ) async {
      final container = await zeige(tester, held: weltlich(), breite: 1280);
      container
          .read(advancementSessionProvider('praiodan').notifier)
          .start(hero: weltlich(), catalog: testCatalog);
      await tester.pumpAndSettle();
      final knopf = tester.widget<TextButton>(k('karto-spiel-anordnen'));
      expect(knopf.onPressed, isNull);
      expect(k('karto-kachel-kampf-einklappen'), findsNothing);
    });

    for (final breite in [360.0, 800.0, 1280.0, 1920.0]) {
      testWidgets('Anordnen-Modus bei $breite dp ohne Überlauf', (
        tester,
      ) async {
        await zeige(
          tester,
          held: magisch().copyWith(adventures: const [_nebel]),
          breite: breite,
        );
        await tester.tap(k('karto-spiel-anordnen'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Anordnen zeigt je Kachel eine Vorschau mit Größenstufe', (
      tester,
    ) async {
      await zeige(
        tester,
        held: magisch().copyWith(adventures: const [_nebel]),
        breite: 1280,
        hoehe: 4000,
      );
      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();

      for (final id in [
        'ressourcen',
        'eigenschaften',
        'zustand',
        'abenteuer',
      ]) {
        expect(k('karto-kachel-$id-vorschau'), findsOneWidget, reason: id);
        expect(k('karto-kachel-$id-vorschau-stufe'), findsOneWidget);
      }
      // Ressourcen liegen auf ganzer Breite: weit.
      expect(
        find.descendant(
          of: k('karto-kachel-ressourcen'),
          matching: find.textContaining('Vorschau: Weit'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Vorschau folgt der gewählten Breite', (tester) async {
      await zeige(tester, held: weltlich(), breite: 1280, hoehe: 4000);
      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();
      Finder stufe(String text) => find.descendant(
        of: k('karto-kachel-ressourcen'),
        matching: find.textContaining('Vorschau: $text'),
      );

      expect(stufe('Weit'), findsOneWidget);
      expect(k('karto-ressource-lebensenergie-plus-1'), findsOneWidget);

      await tester.tap(k('karto-kachel-ressourcen-breite'));
      await tester.pumpAndSettle();
      await tester.tap(k('karto-kachel-ressourcen-breite-schmal'));
      await tester.pumpAndSettle();

      expect(stufe('Weit'), findsNothing);
      expect(k('karto-ressource-lebensenergie-plus-1'), findsNothing);
    });

    testWidgets('die Vorschau ist nicht bedienbar und schreibt nichts', (
      tester,
    ) async {
      final bestand = TestBestand();
      final repo = _ZaehlendesRepository(heroes: [weltlich()]);
      await zeige(
        tester,
        held: weltlich(),
        repository: repo,
        bestand: bestand,
        breite: 1280,
        hoehe: 4000,
      );
      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();

      await tester.tap(
        k('karto-ressource-lebensenergie-plus-1'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(bestand.aufrufe, isEmpty);

      await tester.tap(k('karto-spiel-anordnen-fertig'));
      await tester.pumpAndSettle();
      expect(repo.speicherungen, 0);
    });
  });

  group('Kampf-Kachel (SPIEL-07)', () {
    Finder k(String schluessel) => find.byKey(ValueKey<String>(schluessel));

    // Held, dessen Kampf-Kachel auf die Breite [breite] gestellt ist.
    HeroSheet kampfBreite(SpielkachelBreite breite) => weltlich().copyWith(
      spielansicht: HeroSpielansicht(
        kacheln: [HeroSpielkachel(id: 'kampf', breite: breite)],
      ),
    );

    testWidgets('standardmäßig schmal zeigt sie kein Panel', (tester) async {
      for (final breite in [390.0, 1280.0, 1920.0]) {
        await zeige(tester, held: weltlich(), breite: breite);
        expect(find.text('Kampfproben praiodan'), findsOneWidget);
        expect(k('karto-kampf-werte'), findsNothing, reason: '$breite dp');
      }
    });

    for (final breite in [1024.0, 1280.0, 1440.0, 1920.0]) {
      testWidgets('mittel zeigt das Panel bei $breite dp', (tester) async {
        await zeige(
          tester,
          held: kampfBreite(SpielkachelBreite.mittel),
          breite: breite,
        );
        expect(k('karto-kampf-werte'), findsOneWidget);
        expect(k('karto-kampf-ini'), findsOneWidget);
        expect(find.text('Kampfproben praiodan'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('mittel zeigt das Panel schon bei 744 dp', (tester) async {
      await zeige(
        tester,
        held: kampfBreite(SpielkachelBreite.mittel),
        breite: 744,
      );
      expect(k('karto-kampf-werte'), findsOneWidget);
    });

    testWidgets('eine einspaltige Ansicht bleibt ohne Panel', (tester) async {
      await zeige(
        tester,
        held: kampfBreite(SpielkachelBreite.mittel),
        breite: 390,
      );
      expect(k('karto-kampf-werte'), findsNothing);
    });

    testWidgets('der Vergrößern-Dialog zeigt das Panel auch bei schmaler '
        'Kachel', (tester) async {
      await zeige(tester, held: weltlich(), breite: 1280);
      expect(k('karto-kampf-werte'), findsNothing);
      await tester.tap(k('karto-kachel-kampf-vergroessern'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: k('karto-kachel-kampf-popup'),
          matching: k('karto-kampf-werte'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Anordnen: die Vorschau zeigt das Panel in der weiten Stufe', (
      tester,
    ) async {
      await zeige(
        tester,
        held: kampfBreite(SpielkachelBreite.mittel),
        breite: 1280,
      );
      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(k('karto-kachel-kampf-vorschau-stufe')).data,
        startsWith('Vorschau: Weit'),
      );
      expect(
        find.descendant(
          of: k('karto-kachel-kampf-vorschau'),
          matching: k('karto-kampf-werte'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Anordnen: eine schmale Kachel zeigt in der Vorschau kein '
        'Panel', (tester) async {
      await zeige(tester, held: weltlich(), breite: 1280);
      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: k('karto-kachel-kampf-vorschau'),
          matching: k('karto-kampf-werte'),
        ),
        findsNothing,
      );
    });

    testWidgets('Breite im Anordnen ändern lässt die Vorschau sofort folgen', (
      tester,
    ) async {
      await zeige(tester, held: weltlich(), breite: 1280);
      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(k('karto-kachel-kampf-breite'));
      await tester.tap(k('karto-kachel-kampf-breite'));
      await tester.pumpAndSettle();
      await tester.tap(k('karto-kachel-kampf-breite-mittel').last);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: k('karto-kachel-kampf-vorschau'),
          matching: k('karto-kampf-werte'),
        ),
        findsOneWidget,
      );
    });

    for (final breite in [744.0, 1024.0, 1440.0, 1920.0]) {
      for (final skalierung in [1.0, 2.0]) {
        testWidgets('weit bei $breite dp, Schrift $skalierung, ohne '
            'Überlauf, auch im Anordnen', (tester) async {
          await zeige(
            tester,
            held: kampfBreite(SpielkachelBreite.mittel),
            breite: breite,
            skalierung: skalierung,
          );
          expect(k('karto-kampf-werte'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(k('karto-spiel-anordnen'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('Abenteuer-Kachel (SPIEL-07)', () {
    Finder k(String schluessel) => find.byKey(ValueKey<String>(schluessel));

    testWidgets('weit: Personen und Notizen stehen nebeneinander', (
      tester,
    ) async {
      await zeige(tester, held: mitAbenteuern([_viele]), breite: 1280);
      expect(k('karto-spiel-abenteuer-spalten'), findsOneWidget);
      final personen = tester.getTopLeft(find.text('Personen \u00b7 2'));
      final notizen = tester.getTopLeft(find.text('Notizen \u00b7 3'));
      expect(notizen.dx, greaterThan(personen.dx));
      expect(notizen.dy, personen.dy);
      // Beide Spalten bleiben vollständig bedienbar.
      expect(find.text('Alrik vom Blautann'), findsOneWidget);
      expect(find.text('Die Furt'), findsOneWidget);
    });

    testWidgets('eine einspaltige Ansicht stapelt Personen über Notizen', (
      tester,
    ) async {
      for (final breite in [390.0, 560.0]) {
        await zeige(tester, held: mitAbenteuern([_viele]), breite: breite);
        expect(k('karto-spiel-abenteuer-spalten'), findsNothing);
        final personen = tester.getTopLeft(find.text('Personen \u00b7 2'));
        final notizen = tester.getTopLeft(find.text('Notizen \u00b7 3'));
        expect(notizen.dy, greaterThan(personen.dy), reason: '$breite dp');
      }
    });

    testWidgets('mit nur Personen oder nur Notizen gibt es keine Spalten', (
      tester,
    ) async {
      await zeige(
        tester,
        held: mitAbenteuern([_viele.copyWith(notes: const [])]),
        breite: 1280,
      );
      expect(k('karto-spiel-abenteuer-spalten'), findsNothing);
      expect(find.text('Personen \u00b7 2'), findsOneWidget);
      await zeige(
        tester,
        held: mitAbenteuern([_viele.copyWith(people: const [])]),
        breite: 1280,
      );
      expect(k('karto-spiel-abenteuer-spalten'), findsNothing);
      expect(find.text('Notizen \u00b7 3'), findsOneWidget);
    });

    testWidgets('der Vergrößern-Dialog zeigt die Spalten', (tester) async {
      await zeige(tester, held: mitAbenteuern([_viele]), breite: 1280);
      // Die Kachel steht unter dem Block „Dabei“ und liegt außerhalb des
      // ersten Bildschirms.
      await tester.ensureVisible(k('karto-kachel-abenteuer-vergroessern'));
      await tester.tap(k('karto-kachel-abenteuer-vergroessern'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: k('karto-kachel-abenteuer-popup'),
          matching: k('karto-spiel-abenteuer-spalten'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Anordnen: die Vorschau trägt die Spalten', (tester) async {
      await zeige(tester, held: mitAbenteuern([_viele]), breite: 1280);
      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: k('karto-kachel-abenteuer-vorschau'),
          matching: k('karto-spiel-abenteuer-spalten'),
        ),
        findsOneWidget,
      );
    });

    for (final breite in [744.0, 1024.0, 1440.0, 1920.0]) {
      for (final skalierung in [1.0, 2.0]) {
        testWidgets('bei $breite dp, Schrift $skalierung, ohne Überlauf, auch '
            'im Anordnen', (tester) async {
          await zeige(
            tester,
            held: mitAbenteuern([_viele]),
            breite: breite,
            skalierung: skalierung,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(k('karto-spiel-anordnen'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('Reiseroute-Kachel (SPIEL-07)', () {
    Finder k(String schluessel) => find.byKey(ValueKey<String>(schluessel));

    HeroSheet mitStationen(SpielkachelBreite? breite) => weltlich().copyWith(
      reiseStationen: [
        for (var i = 1; i <= 7; i++)
          HeroReiseStation(
            id: 's$i',
            ort: 'Ort $i',
            datum: HeroAdventureDateValue(
              day: '$i',
              month: 'boron',
              year: '1043',
            ),
          ),
      ],
      spielansicht: breite == null
          ? null
          : HeroSpielansicht(
              kacheln: [HeroSpielkachel(id: 'reiseroute', breite: breite)],
            ),
    );

    int sichtbar() => [
      for (var i = 1; i <= 7; i++)
        if (k('karto-reise-station-s$i').evaluate().isNotEmpty) i,
    ].length;

    testWidgets('standardmäßig schmal zeigt sie die jüngsten drei', (
      tester,
    ) async {
      await zeige(tester, held: mitStationen(null), breite: 1280);
      expect(sichtbar(), 3);
    });

    testWidgets('mittel ist weit und zeigt fünf Stationen mit Kartenlink', (
      tester,
    ) async {
      await zeige(
        tester,
        held: mitStationen(SpielkachelBreite.mittel),
        breite: 1280,
      );
      expect(sichtbar(), 5);
      expect(find.byTooltip('Auf Avesmaps zeigen'), findsNWidgets(5));
    });

    testWidgets('der Vergrößern-Dialog zeigt fünf Stationen', (tester) async {
      await zeige(tester, held: mitStationen(null), breite: 1280);
      await tester.tap(k('karto-kachel-reiseroute-vergroessern'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: k('karto-kachel-reiseroute-popup'),
          matching: find.byTooltip('Auf Avesmaps zeigen'),
        ),
        findsNWidgets(5),
      );
    });

    for (final breite in [744.0, 1280.0, 1920.0]) {
      testWidgets('weit bei $breite dp mit Schrift 2 ohne Überlauf, auch im '
          'Anordnen', (tester) async {
        await zeige(
          tester,
          held: mitStationen(SpielkachelBreite.mittel),
          breite: breite,
          skalierung: 2,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(k('karto-spiel-anordnen'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Ressourcen-Schritte (SPIEL-07)', () {
    Finder k(String schluessel) => find.byKey(ValueKey<String>(schluessel));
    const namen = ['minus-5', 'minus-1', 'plus-1', 'plus-5'];

    // Held mit allen vier Ressourcen: LeP, AuP, AsP und KaP.
    HeroSheet vierRessourcen() => weltlich().copyWith(
      resourceActivationConfig: const HeroResourceActivationConfig(
        magicEnabledOverride: true,
        divineEnabledOverride: true,
      ),
    );

    testWidgets('weit: Knöpfe melden den Schritt der angetippten Ressource', (
      tester,
    ) async {
      final bestand = TestBestand();
      await zeige(tester, held: weltlich(), bestand: bestand, breite: 1280);
      await tester.tap(k('karto-ressource-lebensenergie-plus-1'));
      await tester.tap(k('karto-ressource-ausdauer-minus-5'));
      await tester.pump();
      expect(bestand.aufrufe, [
        'ressourceSchritt:praiodan:lebensenergie:1',
        'ressourceSchritt:praiodan:ausdauer:-5',
      ]);
      // Der Schritt öffnet nicht zusätzlich das Ressourcenblatt.
      expect(bestand.aufrufe.where((a) => a.startsWith('ressource:')), isEmpty);
    });

    testWidgets('schnelle Klicks gehen nicht verloren (kein Guard)', (
      tester,
    ) async {
      final bestand = TestBestand();
      await zeige(tester, held: weltlich(), bestand: bestand, breite: 1280);
      for (var i = 0; i < 5; i++) {
        await tester.tap(k('karto-ressource-lebensenergie-plus-1'));
      }
      expect(bestand.aufrufe, hasLength(5));
    });

    testWidgets('kompakt (390 dp) und ohne Kachelbreite zeigen keine Knöpfe', (
      tester,
    ) async {
      await zeige(tester, held: weltlich(), breite: 390);
      for (final name in namen) {
        expect(k('karto-ressource-lebensenergie-$name'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('schmal angeordnet bleibt die Kachel ohne Knöpfe', (
      tester,
    ) async {
      final repo = FakeRepository(
        heroes: [
          weltlich().copyWith(
            spielansicht: const HeroSpielansicht(
              kacheln: [
                HeroSpielkachel(
                  id: 'ressourcen',
                  breite: SpielkachelBreite.schmal,
                ),
              ],
            ),
          ),
        ],
      );
      await zeige(tester, held: weltlich(), repository: repo, breite: 1280);
      // Eine Rastereinheit ist unter 700 dp: nicht weit.
      expect(k('karto-ressource-lebensenergie-plus-1'), findsNothing);
    });

    testWidgets('im Vergrößern-Dialog erscheinen die Knöpfe und schreiben', (
      tester,
    ) async {
      final bestand = TestBestand();
      await zeige(tester, held: weltlich(), bestand: bestand, breite: 1280);
      await tester.tap(k('karto-kachel-ressourcen-vergroessern'));
      await tester.pumpAndSettle();
      final dialog = k('karto-kachel-ressourcen-popup');
      expect(dialog, findsOneWidget);
      final plus = find.descendant(
        of: dialog,
        matching: k('karto-ressource-lebensenergie-plus-5'),
      );
      expect(plus, findsOneWidget);
      await tester.tap(plus);
      await tester.pump();
      expect(bestand.aufrufe, ['ressourceSchritt:praiodan:lebensenergie:5']);
    });

    testWidgets('vier Ressourcen: 2×2 bei Platz für drei, eine Reihe bei '
        'Platz für vier', (tester) async {
      Offset lage(String art) => tester.getTopLeft(k('karto-ressource-$art'));

      await zeige(tester, held: vierRessourcen(), breite: 1024);
      var orte = [
        for (final art in [
          'lebensenergie',
          'ausdauer',
          'astralenergie',
          'karma',
        ])
          lage(art),
      ];
      expect(orte.map((o) => o.dx).toSet(), hasLength(2));
      expect(orte.map((o) => o.dy).toSet(), hasLength(2));

      await zeige(tester, held: vierRessourcen(), breite: 1920);
      orte = [
        for (final art in [
          'lebensenergie',
          'ausdauer',
          'astralenergie',
          'karma',
        ])
          lage(art),
      ];
      expect(orte.map((o) => o.dy).toSet(), hasLength(1));
      expect(tester.takeException(), isNull);
    });

    for (final breite in [744.0, 1024.0, 1440.0]) {
      testWidgets(
        'weit bei $breite dp ohne Überlauf, auch mit Textskalierung 2',
        (tester) async {
          await zeige(
            tester,
            held: vierRessourcen(),
            breite: breite,
            skalierung: 2,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

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
      'Schnellaktionen, Ressourcen und Eigenschaften stehen vor dem Abenteuer',
      (tester) async {
        await zeige(tester, held: mitAbenteuern([_nebel]));
        final aktionen = tester.getTopLeft(find.text('Probe suchen')).dy;
        final ressourcen = tester.getTopLeft(find.text('Ressourcen')).dy;
        final eigenschaften = tester.getTopLeft(find.text('Eigenschaften')).dy;
        final kampf = tester.getTopLeft(find.text('Kampf')).dy;
        final abenteuer = tester
            .getTopLeft(find.text('Die Spuren im Nebel'))
            .dy;
        expect(aktionen, lessThan(ressourcen));
        expect(ressourcen, lessThan(eigenschaften));
        // Einspaltig rückt der Kampf vor das Abenteuer.
        expect(eigenschaften, lessThan(kampf));
        expect(kampf, lessThan(abenteuer));
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
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('karto-kachel-abenteuer')),
          matching: find.text('Gareth'),
        ),
        findsOneWidget,
      );
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
      expect(notiz.datum.anzeigeText, '12. Phex 1043 BF');
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
      expect(notiz.datum.hasContent, isFalse);
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
            datum: HeroAdventureDateValue(
              day: '3',
              month: 'rahja',
              year: '1040',
            ),
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

  group('Häufige Proben', () {
    testWidgets('stehen nach den Ressourcen und vor dem Abenteuer', (
      tester,
    ) async {
      await zeige(tester, held: mitAbenteuern([_nebel]));
      final ressourcen = tester.getTopLeft(find.text('Ressourcen')).dy;
      final proben = tester.getTopLeft(find.text('Häufige Proben')).dy;
      final abenteuer = tester.getTopLeft(find.text('Die Spuren im Nebel')).dy;
      expect(ressourcen, lessThan(proben));
      expect(proben, lessThan(abenteuer));
      expect(find.text('Häufige Proben praiodan'), findsOneWidget);
    });

    testWidgets('„Proben wählen“ öffnet die Probensuche', (tester) async {
      final bestand = TestBestand();
      await zeige(tester, held: weltlich(), bestand: bestand);
      await tester.tap(
        find.byKey(const ValueKey('karto-spiel-proben-waehlen')),
      );
      await tester.pumpAndSettle();
      expect(bestand.aufrufe, contains('probeSuchen:praiodan'));
    });
  });

  group('Vor- und Nachteile', () {
    testWidgets('stehen einspaltig nach Kampf und Abenteuer', (tester) async {
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
      final eigenschaften = tester.getTopLeft(find.text('Eigenschaften')).dy;
      final kampf = tester.getTopLeft(find.text('Kampf')).dy;
      final merkmale = tester.getTopLeft(titel).dy;
      expect(eigenschaften, lessThan(kampf));
      expect(kampf, lessThan(merkmale));
    });

    testWidgets('sind eingeklappt und klappen per Tipp auf und zu', (
      tester,
    ) async {
      final einstellungen = _Einstellungen();
      addTearDown(einstellungen.close);
      final container = await zeige(
        tester,
        held: weltlich().copyWith(
          vorteileText: 'Flink',
          nachteileText: 'Goldgier 6',
        ),
        einstellungen: einstellungen,
      );
      final umschalter = find.byKey(
        const ValueKey('karto-spiel-merkmale-umschalten'),
      );
      expect(find.text('Alle zeigen (2)'), findsOneWidget);
      expect(find.textContaining('Vorteile  Flink'), findsOneWidget);

      await tester.ensureVisible(umschalter);
      await tester.tap(umschalter);
      await tester.pumpAndSettle();
      expect(find.text('Einklappen'), findsOneWidget);
      expect(find.text('Vorteile'), findsOneWidget);
      expect(find.text('Flink'), findsOneWidget);
      expect(container.read(merkmaleAufgeklapptProvider), isTrue);
      expect(einstellungen.load().merkmaleAufgeklappt, isTrue);

      await tester.ensureVisible(umschalter);
      await tester.tap(umschalter);
      await tester.pumpAndSettle();
      expect(find.text('Alle zeigen (2)'), findsOneWidget);
      expect(einstellungen.load().merkmaleAufgeklappt, isFalse);
    });

    testWidgets('öffnen aufgeklappt, wenn das Gerät es so gespeichert hat', (
      tester,
    ) async {
      final einstellungen = _Einstellungen(
        const AppSettings(merkmaleAufgeklappt: true),
      );
      addTearDown(einstellungen.close);
      await zeige(
        tester,
        held: weltlich().copyWith(vorteileText: 'Flink'),
        einstellungen: einstellungen,
      );
      expect(find.text('Einklappen'), findsOneWidget);
    });

    testWidgets('das Umschalten schreibt nie den Helden', (tester) async {
      final einstellungen = _Einstellungen();
      addTearDown(einstellungen.close);
      final held = weltlich().copyWith(vorteileText: 'Flink');
      final repo = FakeRepository(heroes: [held]);
      await zeige(
        tester,
        held: held,
        repository: repo,
        einstellungen: einstellungen,
      );
      final umschalter = find.byKey(
        const ValueKey('karto-spiel-merkmale-umschalten'),
      );
      await tester.ensureVisible(umschalter);
      await tester.tap(umschalter);
      await tester.pumpAndSettle();
      expect(einstellungen.load().merkmaleAufgeklappt, isTrue);
      // `saveHero` ersetzt den Eintrag durch eine neue Instanz.
      expect(identical(await repo.loadHeroById(held.id), held), isTrue);
      expect(await repo.loadHeroState(held.id), isNull);
    });

    group('weite Stufe (SPIEL-07)', () {
      Finder k(String schluessel) => find.byKey(ValueKey<String>(schluessel));

      HeroSheet breit(SpielkachelBreite? breite) => weltlich().copyWith(
        vorteileText: 'Flink, Zäher Hund',
        nachteileText: 'Goldgier 6',
        spielansicht: breite == null
            ? null
            : HeroSpielansicht(
                kacheln: [HeroSpielkachel(id: 'merkmale', breite: breite)],
              ),
      );

      testWidgets('aufgeklappt stehen die Arten nebeneinander', (tester) async {
        final einstellungen = _Einstellungen(
          const AppSettings(merkmaleAufgeklappt: true),
        );
        addTearDown(einstellungen.close);
        await zeige(
          tester,
          held: breit(SpielkachelBreite.mittel),
          breite: 1280,
          einstellungen: einstellungen,
        );
        expect(k('karto-merkmale-spalten'), findsOneWidget);
        final vorteile = tester.getTopLeft(find.text('Vorteile'));
        final nachteile = tester.getTopLeft(find.text('Nachteile'));
        expect(nachteile.dy, vorteile.dy);
        expect(nachteile.dx, greaterThan(vorteile.dx));
      });

      testWidgets('die Standardbreite bleibt unverändert untereinander', (
        tester,
      ) async {
        final einstellungen = _Einstellungen(
          const AppSettings(merkmaleAufgeklappt: true),
        );
        addTearDown(einstellungen.close);
        await zeige(
          tester,
          held: breit(null),
          breite: 1280,
          einstellungen: einstellungen,
        );
        expect(k('karto-merkmale-spalten'), findsNothing);
        expect(
          tester.getTopLeft(find.text('Nachteile')).dy,
          greaterThan(tester.getTopLeft(find.text('Vorteile')).dy),
        );
      });

      testWidgets('der Vergrößern-Dialog zeigt die Spalten', (tester) async {
        final einstellungen = _Einstellungen(
          const AppSettings(merkmaleAufgeklappt: true),
        );
        addTearDown(einstellungen.close);
        await zeige(
          tester,
          held: breit(null),
          breite: 1280,
          einstellungen: einstellungen,
        );
        await tester.tap(k('karto-kachel-merkmale-vergroessern'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: k('karto-kachel-merkmale-popup'),
            matching: k('karto-merkmale-spalten'),
          ),
          findsOneWidget,
        );
      });

      for (final breite in [744.0, 1024.0, 1440.0, 1920.0]) {
        for (final skalierung in [1.0, 2.0]) {
          testWidgets('mittel bei $breite dp, Schrift $skalierung, ohne '
              'Überlauf, auch im Anordnen', (tester) async {
            final einstellungen = _Einstellungen(
              const AppSettings(merkmaleAufgeklappt: true),
            );
            addTearDown(einstellungen.close);
            await zeige(
              tester,
              held: breit(SpielkachelBreite.mittel),
              breite: breite,
              skalierung: skalierung,
              einstellungen: einstellungen,
            );
            expect(tester.takeException(), isNull);
            await tester.tap(k('karto-spiel-anordnen'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          });
        }
      }
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
      await tester.ensureVisible(
        find.byKey(const ValueKey('karto-spiel-merkmale')),
      );
      await tester.tap(find.byKey(const ValueKey('karto-spiel-merkmale')));
      await tester.pumpAndSettle();
      expect(geprueft, 1);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('Bearbeiten öffnet das Merkmalsblatt', (tester) async {
      await zeige(tester, held: weltlich(), breite: 1024);
      await tester.ensureVisible(
        find.byKey(const ValueKey('karto-spiel-merkmale')),
      );
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

/// Einstellungsspeicher im Speicher, mit Änderungsstrom.
class _Einstellungen implements HiveSettingsRepository {
  _Einstellungen([AppSettings einstellungen = const AppSettings()])
    : _einstellungen = einstellungen;

  final StreamController<AppSettings> _strom =
      StreamController<AppSettings>.broadcast();
  AppSettings _einstellungen;

  @override
  Future<void> close() => _strom.close();

  @override
  AppSettings load() => _einstellungen;

  @override
  Future<void> save(AppSettings settings) async {
    _einstellungen = settings;
    _strom.add(settings);
  }

  @override
  Stream<AppSettings> watch() => _strom.stream;

  @override
  Future<void> attachUser(String uid, {Object? remote, Object? cipher}) async {}

  @override
  Future<void> detachUser() async {}

  @override
  bool get isAttached => false;

  @override
  String? get attachedUid => null;
}

/// Zählt, wie oft der Bogen gespeichert wird.
class _ZaehlendesRepository extends FakeRepository {
  _ZaehlendesRepository({super.heroes});

  int speicherungen = 0;

  @override
  Future<void> saveHero(HeroSheet hero) {
    speicherungen++;
    return super.saveHero(hero);
  }
}
