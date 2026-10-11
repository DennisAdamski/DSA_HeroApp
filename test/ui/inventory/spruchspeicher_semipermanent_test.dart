import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/planung_bearbeiten_guard.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

import '../../test_support/bogen_test_repository.dart';

// Semipermanenten Spruchspeicher auslösen: Das Intervall läuft gegen das
// aventurische Datum der Kampagne des Helden. Die App zeigt den Stand nur an
// und sperrt nie; ohne Datum gibt es den Knopf „Matrizen regeneriert“.

AventurianDate _d(String tag, String monat) =>
    AventurianDate(day: tag, month: monat, year: '1027');

HeroInventoryEntry _robe({
  int proIntervall = 1,
  List<AventurianDate> anwendungen = const <AventurianDate>[],
  bool defekt = false,
}) => HeroInventoryEntry(
  gegenstand: 'Robe',
  isMagisch: true,
  instanzId: 'i-1',
  artefaktDaten: ArtefaktDaten(
    art: ArtefaktArt.spruchspeicherSemipermanent,
    intervall: ArtefaktIntervall.woche,
    anwendungenProIntervall: proIntervall,
    anwendungen: anwendungen,
    defekt: defekt,
    zauber: const <ArtefaktZauber>[
      ArtefaktZauber(name: 'Aureolus', repraesentation: 'Mag', zfpStern: 7),
    ],
  ),
);

HeroSheet _held(HeroInventoryEntry eintrag, {String? heute}) => HeroSheet(
  id: 'hero-1',
  name: 'Hofillusionistin',
  level: 1,
  attributes: const Attributes(
    mu: 12,
    kl: 11,
    inn: 10,
    ch: 10,
    ff: 11,
    ge: 12,
    ko: 11,
    kk: 12,
  ),
  inventoryEntries: [eintrag],
  adventures: [
    if (heute != null)
      HeroAdventureEntry(
        id: 'a',
        currentAventurianDate: HeroAdventureDateValue(
          day: heute,
          month: 'praios',
          year: '1027',
        ),
      ),
  ],
);

void main() {
  late BogenTestRepository repo;

  Future<void> zeige(
    WidgetTester tester,
    HeroInventoryEntry eintrag, {
    String? heute = '10',
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = BogenTestRepository(
      heroes: [_held(eintrag, heute: heute)],
      states: {
        'hero-1': HeroState(
          currentLep: 30,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 30,
        ),
      },
    );
    final aktionen = ValueNotifier<WorkspaceTabEditActions?>(null);
    addTearDown(aktionen.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [heroRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: PlanungsBearbeitungsBereich(
              heroId: 'hero-1',
              child: HeroInventoryTab(
                heroId: 'hero-1',
                onDirtyChanged: (_) {},
                onEditingChanged: (_) {},
                onRegisterDiscard: (_) {},
                onRegisterEditActions: (wert) => aktionen.value = wert,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('inventory-row-open-0')),
    );
    await tester.pumpAndSettle();
  }

  Finder schluessel(String name) => find.byKey(ValueKey<String>(name));

  Future<void> oeffneDialog(WidgetTester tester) async {
    final knopf = schluessel('inventory-editor-ausloesen');
    await tester.ensureVisible(knopf);
    await tester.tap(knopf);
    await tester.pumpAndSettle();
  }

  Future<void> bestaetige(WidgetTester tester) async {
    await tester.tap(schluessel('spruchspeicher-ausloesen-bestaetigen'));
    await tester.pumpAndSettle();
  }

  Future<List<AventurianDate>> gespeicherteAnwendungen() async =>
      (await repo.gespeichert('hero-1'))
          .inventoryEntries
          .single
          .artefaktDaten!
          .anwendungen;

  testWidgets('der Dialog zeigt Zauber und freie Anwendungen im Intervall', (
    tester,
  ) async {
    await zeige(
      tester,
      _robe(proIntervall: 3, anwendungen: [_d('8', 'praios')]),
    );

    await oeffneDialog(tester);

    expect(find.text('2 von 3 Anwendungen je Woche frei'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Aureolus'),
      ),
      findsOneWidget,
    );
    expect(schluessel('spruchspeicher-ausloesen-ladung-0'), findsNothing);
  });

  testWidgets('vermerkt die Anwendung mit dem Kampagnendatum, ein Dokument', (
    tester,
  ) async {
    await zeige(tester, _robe());
    await oeffneDialog(tester);
    await tester.enterText(
      schluessel('spruchspeicher-ausloesen-ziel'),
      'Publikum',
    );

    await bestaetige(tester);

    expect(find.text('Anwendung vermerkt.'), findsOneWidget);
    expect(
      find.textContaining('0 von 1 Anwendung je Woche frei'),
      findsWidgets,
    );
    expect(
      find.textContaining('frühestens wieder am 17. Praios 1027 BF'),
      findsWidgets,
    );
    expect(await gespeicherteAnwendungen(), [_d('10', 'praios')]);
    expect(repo.bogenSpeicherungen, 1);
    final eintrag = (await repo.loadHeroState('hero-1'))!.diceLog.single;
    expect(eintrag.title, 'Spruchspeicher: Robe');
    expect(eintrag.subtitle, contains('Aureolus'));
    expect(eintrag.subtitle, contains('Anwendung (0 von 1 Anwendung je Woche'));
    expect(eintrag.subtitle, contains('Ziel: Publikum'));
    expect((await repo.loadHeroState('hero-1'))!.currentAsp, 0);
  });

  testWidgets('ein erschöpftes Intervall warnt, sperrt aber nicht', (
    tester,
  ) async {
    await zeige(tester, _robe(anwendungen: [_d('8', 'praios')]));
    await oeffneDialog(tester);

    expect(
      find.textContaining('Alle 1 Anwendung je Woche sind verbraucht'),
      findsOneWidget,
    );
    expect(
      find.textContaining('frühestens wieder am 15. Praios'),
      findsWidgets,
    );
    await bestaetige(tester);

    expect(find.text('Anwendung vermerkt.'), findsOneWidget);
    expect(await gespeicherteAnwendungen(), [_d('10', 'praios')]);
  });

  testWidgets('nach genug Tagen verfällt die alte Anwendung', (tester) async {
    await zeige(tester, _robe(anwendungen: [_d('2', 'praios')]));
    await oeffneDialog(tester);

    expect(find.text('1 von 1 Anwendung je Woche frei'), findsOneWidget);
    await bestaetige(tester);

    expect(await gespeicherteAnwendungen(), [_d('10', 'praios')]);
  });

  testWidgets('ohne Kampagnendatum: Anwendung ohne Datum, Hinweis', (
    tester,
  ) async {
    await zeige(tester, _robe(), heute: null);
    await oeffneDialog(tester);

    await bestaetige(tester);

    expect(schluessel('spruchspeicher-ausloesen-ohne-datum'), findsOneWidget);
    final anwendungen = await gespeicherteAnwendungen();
    expect(anwendungen, hasLength(1));
    expect(anwendungen.single.hasContent, isFalse);
  });

  testWidgets('„Matrizen regeneriert“ leert die vermerkten Anwendungen', (
    tester,
  ) async {
    await zeige(
      tester,
      _robe(anwendungen: [const AventurianDate()]),
      heute: null,
    );
    await oeffneDialog(tester);
    expect(
      find.text(
        '0 von 1 Anwendung je Woche frei · Datum unbekannt, es verfällt nichts von selbst',
      ),
      findsOneWidget,
    );

    await tester.tap(schluessel('spruchspeicher-ausloesen-regeneriert'));
    await tester.pumpAndSettle();

    expect(find.text('1 von 1 Anwendung je Woche frei'), findsOneWidget);
    expect(schluessel('spruchspeicher-ausloesen-regeneriert'), findsNothing);
    expect(await gespeicherteAnwendungen(), isEmpty);
    // Danach lässt sich ohne Fehler auslösen: der Dialog kennt den neuen Stand.
    await bestaetige(tester);
    expect(schluessel('spruchspeicher-ausloesen-fehler'), findsNothing);
    expect(find.text('Anwendung vermerkt.'), findsOneWidget);
  });

  testWidgets('ein beschädigter Speicher bietet keine Auslösung an', (
    tester,
  ) async {
    await zeige(tester, _robe(defekt: true));

    expect(schluessel('inventory-editor-ausloesen'), findsNothing);
    expect(schluessel('inventory-editor-aufladen'), findsNothing);
  });

  testWidgets('wurde der Gegenstand inzwischen geändert, bleibt alles stehen', (
    tester,
  ) async {
    await zeige(tester, _robe());
    await oeffneDialog(tester);
    repo.fremdeAenderung = (held) => held.copyWith(
      inventoryEntries: [
        held.inventoryEntries.single.copyWith(gegenstand: 'Umbenannt'),
      ],
    );

    await bestaetige(tester);

    expect(find.textContaining('inzwischen geändert'), findsOneWidget);
    expect(repo.bogenSpeicherungen, 0);
  });
}
