import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spielansicht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_base_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_verwaltungs_ziel.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import '../../test_support/fake_repository.dart';
import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

// Zauberkachel der Spielansicht: optional (standardmäßig ausgeblendet), zeigt
// gelernte Zauber mit ZfW*, Kurzangaben und Probe, schreibt nichts am Helden.

SpellDef _zauber(
  String id,
  String name, {
  String traits = '',
  String kosten = '',
}) => SpellDef(
  id: id,
  name: name,
  tradition: 'Gildenmagie',
  steigerung: 'D',
  attributes: const <String>['KL', 'IN', 'FF'],
  traits: traits,
  castingTime: '2 Aktionen',
  aspCost: kosten,
  range: '8 Schritt',
  duration: 'sofort',
  targetObject: 'Einzelobjekt',
);

final _katalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: const [],
  weapons: const [],
  spells: <SpellDef>[
    _zauber(
      'spell_ignifaxius',
      'Ignifaxius Flammenstrahl',
      traits: 'Elementar (Feuer), Schaden',
      kosten: '4 AsP',
    ),
    _zauber('spell_armatrutz', 'Armatrutz', traits: 'Metamagie'),
    _zauber('spell_balsam', 'Balsam Salabunde', traits: 'Heilung, Metamagie'),
  ],
);

HeroSheet _magier({HeroSpielansicht? ansicht}) =>
    testHero('liora', 'Liora').copyWith(
      resourceActivationConfig: const HeroResourceActivationConfig(
        magicEnabledOverride: true,
      ),
      representationen: const <String>['Mag'],
      merkmalskenntnisse: const <String>['Heilung'],
      spells: const <String, HeroSpellEntry>{
        'spell_ignifaxius': HeroSpellEntry(spellValue: 12, modifier: 2),
        'spell_armatrutz': HeroSpellEntry(spellValue: 7),
        'spell_balsam': HeroSpellEntry(spellValue: 9),
      },
      spielansicht: ansicht,
    );

/// Zauberkachel ausdrücklich auf der Seite, wie nach dem Hinzufügen.
const _sichtbar = HeroSpielansicht(
  kacheln: <HeroSpielkachel>[HeroSpielkachel(id: 'zauber')],
);

void main() {
  Finder k(String schluessel) => find.byKey(ValueKey<String>(schluessel));

  Future<FakeRepository> zeige(
    WidgetTester tester, {
    required HeroSheet held,
    KartoBestandsAdapter? bestand,
    double breite = 1280,
    double skalierung = 1,
    RulesCatalog? katalog,
    ValueChanged<KartoVerwaltungsAbschnitt>? verwaltungOeffnen,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, 2600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeRepository(
      heroes: [held],
      states: <String, HeroState>{
        held.id: const HeroState.empty().copyWith(currentAsp: 18),
      },
    );
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repository),
        rulesCatalogProvider.overrideWith((ref) async => katalog ?? _katalog),
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
            body: KartoSpielansicht(
              heroId: held.id,
              bestand: bestand ?? TestBestand(),
              aktion: (auftrag) => auftrag(),
              vorHeldenbearbeitung: () async => true,
              onVerwaltungOeffnen: verwaltungOeffnen,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  group('optional hinzufügen', () {
    testWidgets('steht standardmäßig nicht auf der Seite', (tester) async {
      await zeige(tester, held: _magier());
      expect(k('karto-kachel-zauber'), findsNothing);
      expect(find.text('Ignifaxius Flammenstrahl'), findsNothing);
    });

    testWidgets('Anordnen bietet sie zum Einblenden an; Fertig speichert', (
      tester,
    ) async {
      final repo = await zeige(tester, held: _magier());
      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();
      expect(k('karto-kachel-zauber-einblenden'), findsOneWidget);

      await tester.tap(k('karto-kachel-zauber-einblenden'));
      await tester.pumpAndSettle();
      expect(k('karto-kachel-zauber-einblenden'), findsNothing);

      await tester.ensureVisible(k('karto-spiel-anordnen-fertig'));
      await tester.tap(k('karto-spiel-anordnen-fertig'));
      await tester.pumpAndSettle();

      expect(k('karto-kachel-zauber'), findsOneWidget);
      expect(find.text('Ignifaxius Flammenstrahl'), findsOneWidget);
      final eintrag = (await repo.loadHeroById('liora'))!.spielansicht!
          .kachel('zauber')!;
      expect(eintrag.ausgeblendet, isFalse);
      // Gelernte Zauber bleiben unangetastet.
      expect((await repo.loadHeroById('liora'))!.spells, hasLength(3));
    });

    testWidgets('Abbrechen lässt sie ausgeblendet', (tester) async {
      final repo = await zeige(tester, held: _magier());
      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();
      await tester.tap(k('karto-kachel-zauber-einblenden'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(k('karto-spiel-anordnen-abbrechen'));
      await tester.tap(k('karto-spiel-anordnen-abbrechen'));
      await tester.pumpAndSettle();
      expect(k('karto-kachel-zauber'), findsNothing);
      expect((await repo.loadHeroById('liora'))!.spielansicht, isNull);
    });

    testWidgets('ein Held ohne Magie und Zauber bekommt sie nicht angeboten', (
      tester,
    ) async {
      await zeige(tester, held: testHero('praiodan', 'Praiodan'));
      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();
      expect(k('karto-kachel-zauber-einblenden'), findsNothing);
    });
  });

  group('Inhalt', () {
    testWidgets('Kopf, AsP, ZfW*, Kurzangaben', (tester) async {
      await zeige(tester, held: _magier(ansicht: _sichtbar));
      expect(k('karto-kachel-zauber'), findsOneWidget);
      expect(find.text('Zauber'), findsWidgets);
      expect(
        find.descendant(
          of: k('karto-zauber-asp'),
          matching: find.textContaining('AsP 18 / '),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Gildenmagier'), findsOneWidget);
      expect(find.textContaining('Heilung'), findsWidgets);
      // ZfW* = 12 + 2.
      expect(
        (k('karto-zauber-spell_ignifaxius-zfw').evaluate().single.widget
                as Text)
            .data,
        '14',
      );
      expect(find.text('4 AsP'), findsOneWidget);
      expect(find.text('2 Aktionen'), findsWidgets);
    });

    testWidgets('Tipp klappt die Details auf und wieder zu', (tester) async {
      await zeige(tester, held: _magier(ansicht: _sichtbar));
      expect(k('karto-zauber-spell_armatrutz-details'), findsNothing);
      await tester.tap(k('karto-zauber-spell_armatrutz-oeffnen'));
      await tester.pumpAndSettle();
      expect(k('karto-zauber-spell_armatrutz-details'), findsOneWidget);
      expect(find.textContaining('Einzelobjekt'), findsOneWidget);
      await tester.tap(k('karto-zauber-spell_armatrutz-oeffnen'));
      await tester.pumpAndSettle();
      expect(k('karto-zauber-spell_armatrutz-details'), findsNothing);
    });

    testWidgets('der Beschreibungsknopf öffnet die Zauberdetails', (
      tester,
    ) async {
      final bestand = TestBestand();
      await zeige(
        tester,
        held: _magier(ansicht: _sichtbar),
        bestand: bestand,
      );
      await tester.tap(k('karto-zauber-spell_balsam-beschreibung'));
      await tester.pumpAndSettle();
      expect(bestand.aufrufe, contains('zauberdetails:liora:spell_balsam'));
      // Der Knopf klappt die Kurzdetails nicht mit auf.
      expect(k('karto-zauber-spell_balsam-details'), findsNothing);
    });

    testWidgets('Sortierung nach ZfW* und Richtung umdrehen', (tester) async {
      await zeige(tester, held: _magier(ansicht: _sichtbar));
      double y(String id) => tester.getTopLeft(k('karto-zauber-$id')).dy;
      // Name aufsteigend: Armatrutz, Balsam, Ignifaxius.
      expect(y('spell_armatrutz'), lessThan(y('spell_balsam')));
      expect(y('spell_balsam'), lessThan(y('spell_ignifaxius')));

      // ZfW* zuerst mit dem höchsten Wert.
      await tester.tap(k('karto-zauber-sort-zfw'));
      await tester.pumpAndSettle();
      expect(y('spell_ignifaxius'), lessThan(y('spell_balsam')));
      expect(y('spell_balsam'), lessThan(y('spell_armatrutz')));

      await tester.tap(k('karto-zauber-sort-zfw'));
      await tester.pumpAndSettle();
      expect(y('spell_armatrutz'), lessThan(y('spell_balsam')));
    });

    testWidgets('Merkmalsfilter lässt nur passende Zauber stehen', (
      tester,
    ) async {
      await zeige(tester, held: _magier(ansicht: _sichtbar));
      await tester.tap(k('karto-zauber-merkmal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Heilung').last);
      await tester.pumpAndSettle();
      expect(k('karto-zauber-spell_balsam'), findsOneWidget);
      expect(k('karto-zauber-spell_armatrutz'), findsNothing);
      expect(k('karto-zauber-spell_ignifaxius'), findsNothing);

      await tester.tap(k('karto-zauber-merkmal'));
      await tester.pumpAndSettle();
      await tester.tap(k('karto-zauber-merkmal-alle'));
      await tester.pumpAndSettle();
      expect(k('karto-zauber-spell_armatrutz'), findsOneWidget);
    });

    testWidgets('ab sieben Zaubern gibt es die Suche', (tester) async {
      final viele = RulesCatalog(
        version: 'test',
        source: 'test',
        talents: const [],
        weapons: const [],
        spells: <SpellDef>[
          for (var i = 1; i <= 7; i++) _zauber('spell_$i', 'Zauber $i'),
        ],
      );
      final held = _magier(ansicht: _sichtbar).copyWith(
        spells: <String, HeroSpellEntry>{
          for (var i = 1; i <= 7; i++)
            'spell_$i': HeroSpellEntry(spellValue: i),
        },
      );
      await zeige(tester, held: held, katalog: viele);
      expect(k('karto-zauber-suche'), findsOneWidget);
      await tester.enterText(k('karto-zauber-suche'), 'zauber 3');
      await tester.pumpAndSettle();
      expect(k('karto-zauber-spell_3'), findsOneWidget);
      expect(k('karto-zauber-spell_4'), findsNothing);
      await tester.enterText(k('karto-zauber-suche'), 'nichts');
      await tester.pumpAndSettle();
      expect(k('karto-zauber-keine-treffer'), findsOneWidget);
    });

    testWidgets(
      'ohne aktivierte Zauber erklärt die Kachel, wo man sie einträgt',
      (tester) async {
        await zeige(
          tester,
          held: _magier(ansicht: _sichtbar)
              .copyWith(spells: const <String, HeroSpellEntry>{}),
        );
        expect(k('karto-zauber-leer'), findsOneWidget);
      },
    );

    for (final breite in <double>[390, 744, 1280]) {
      testWidgets('läuft bei $breite dp und doppelter Schrift ohne Überlauf', (
        tester,
      ) async {
        await zeige(
          tester,
          held: _magier(ansicht: _sichtbar),
          breite: breite,
          skalierung: 2,
        );
        await tester.ensureVisible(k('karto-zauber-spell_ignifaxius-oeffnen'));
        await tester.tap(k('karto-zauber-spell_ignifaxius-oeffnen'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Shortcut zur Magie-Seite', () {
    testWidgets('mit aktivierter Magie führt er in den Abschnitt Magie', (
      tester,
    ) async {
      KartoVerwaltungsAbschnitt? ziel;
      await zeige(
        tester,
        held: _magier(ansicht: _sichtbar),
        verwaltungOeffnen: (abschnitt) => ziel = abschnitt,
      );
      await tester.tap(k('karto-kachel-zauber-oeffnen'));
      expect(ziel, KartoVerwaltungsAbschnitt.magie);
    });

    testWidgets('bei verborgener Magie-Seite gibt es keinen Knopf', (
      tester,
    ) async {
      // Zauber mit ZfW, aber Magie ausdrücklich aus und kein Artefakt: der
      // Magie-Tab fehlt, der Knopf würde ins Leere führen.
      final held = _magier(ansicht: _sichtbar).copyWith(
        resourceActivationConfig: const HeroResourceActivationConfig(
          magicEnabledOverride: false,
        ),
      );
      await zeige(tester, held: held, verwaltungOeffnen: (_) {});
      expect(k('karto-kachel-zauber'), findsOneWidget);
      expect(k('karto-kachel-zauber-oeffnen'), findsNothing);
    });
  });

  group('Würfeln', () {
    testWidgets('ohne Gefechtsbrücke gibt es keinen Würfelknopf', (
      tester,
    ) async {
      await zeige(tester, held: _magier(ansicht: _sichtbar));
      expect(k('karto-zauber-spell_balsam-probe'), findsNothing);
    });

    testWidgets('die Probe trägt ZfW*, Eigenschaften und Verweis', (
      tester,
    ) async {
      final bestand = GefechtsTestBestand();
      await zeige(
        tester,
        held: _magier(ansicht: _sichtbar),
        bestand: bestand,
      );
      await tester.tap(k('karto-zauber-spell_ignifaxius-probe'));
      await tester.pumpAndSettle();

      expect(bestand.anfragen, hasLength(1));
      final probe = bestand.anfragen.single;
      expect(probe.type, ProbeType.spell);
      expect(probe.title, contains('Ignifaxius Flammenstrahl'));
      expect(probe.basePool, 14);
      expect(probe.targets.map((t) => t.label), <String>['KL', 'IN', 'FF']);
      expect(probe.verweis, isNotNull);
    });

    testWidgets('Würfeln schreibt den Helden nicht', (tester) async {
      final bestand = GefechtsTestBestand();
      final repo = await zeige(
        tester,
        held: _magier(ansicht: _sichtbar),
        bestand: bestand,
      );
      final vorher = await repo.loadHeroById('liora');
      await tester.tap(k('karto-zauber-spell_armatrutz-probe'));
      await tester.pumpAndSettle();
      expect(await repo.loadHeroById('liora'), vorher);
    });
  });
}
