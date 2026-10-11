import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/planung_bearbeiten_guard.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

import '../../test_support/bogen_test_repository.dart';

// Ladungsbasierten Spruchspeicher auslösen: eine Ladung wird am Bogen
// verbraucht (ein Dokument), der Träger zahlt keine AsP, würfelt nichts und
// muss nicht zauberkundig sein; das Protokoll folgt als eigene Buchung.

ArtefaktLadung _ladung(String id, {bool verbraucht = false}) => ArtefaktLadung(
  id: id,
  verbraucht: verbraucht,
  zauber: const <ArtefaktZauber>[
    ArtefaktZauber(
      name: 'Psychostabilis',
      repraesentation: 'Mag',
      zfw: 12,
      zfpStern: 7,
      kostenAsp: 9,
    ),
    ArtefaktZauber(name: 'Illusion auflösen', kostenAsp: 6),
  ],
);

HeroInventoryEntry _stirnreif({
  ArtefaktArt art = ArtefaktArt.spruchspeicherAufladbar,
  List<ArtefaktLadung>? ladungen,
  bool defekt = false,
}) => HeroInventoryEntry(
  gegenstand: 'Stirnreif',
  isMagisch: true,
  instanzId: 'i-1',
  artefaktDaten: ArtefaktDaten(
    art: art,
    defekt: defekt,
    ladungen: ladungen ?? [_ladung('a'), _ladung('b'), _ladung('c')],
  ),
);

HeroSheet _held(HeroInventoryEntry eintrag) => HeroSheet(
  id: 'hero-1',
  name: 'Händler',
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
);

// Ein Träger ohne Astralenergie: der Spruchspeicher braucht keine.
HeroState _zustand() =>
    HeroState(currentLep: 30, currentAsp: 0, currentKap: 0, currentAu: 30);

void main() {
  late BogenTestRepository repo;

  Future<void> zeige(WidgetTester tester, HeroInventoryEntry eintrag) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = BogenTestRepository(
      heroes: [_held(eintrag)],
      states: {'hero-1': _zustand()},
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

  Future<void> oeffneDialog(WidgetTester tester) async {
    final knopf = find.byKey(
      const ValueKey<String>('inventory-editor-ausloesen'),
    );
    await tester.ensureVisible(knopf);
    await tester.tap(knopf);
    await tester.pumpAndSettle();
  }

  Future<void> bestaetige(WidgetTester tester) async {
    await tester.tap(
      find.byKey(
        const ValueKey<String>('spruchspeicher-ausloesen-bestaetigen'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder schluessel(String name) => find.byKey(ValueKey<String>(name));

  testWidgets('der Dialog zeigt Ladungen und gespeicherte Wirkung', (
    tester,
  ) async {
    await zeige(tester, _stirnreif());

    await oeffneDialog(tester);

    expect(find.text('3 von 3 Ladungen frei'), findsOneWidget);
    expect(schluessel('spruchspeicher-ausloesen-ladung-0'), findsOneWidget);
    expect(schluessel('spruchspeicher-ausloesen-ladung-2'), findsOneWidget);
    expect(find.text('Psychostabilis'), findsWidgets);
    expect(
      find.textContaining('Repräsentation Mag · ZfW 12 · ZfP* 7'),
      findsWidgets,
    );
    expect(find.textContaining('keine AsP-Kosten'), findsOneWidget);
    expect(
      find.textContaining('Zauberprobe'),
      findsNothing,
      reason: 'keine Probe, keine Wirkdialog-Sprache',
    );
  });

  testWidgets('verbraucht die gewählte Ladung am Bogen, nichts sonst', (
    tester,
  ) async {
    await zeige(tester, _stirnreif());
    await oeffneDialog(tester);
    await tester.tap(schluessel('spruchspeicher-ausloesen-ladung-1'));
    await tester.pumpAndSettle();
    await tester.enterText(
      schluessel('spruchspeicher-ausloesen-ziel'),
      'Verhandlungspartner',
    );

    await bestaetige(tester);

    expect(find.text('Ladung ausgelöst.'), findsOneWidget);
    expect(find.text('2 von 3 Ladungen frei'), findsOneWidget);
    final held = await repo.gespeichert('hero-1');
    final daten = held.inventoryEntries.single.artefaktDaten!;
    expect(daten.ladungen.map((l) => l.verbraucht), [false, true, false]);
    expect(daten.defekt, isFalse);
    expect(repo.bogenSpeicherungen, 1, reason: 'genau ein Bogendokument');
    final zustand = (await repo.loadHeroState('hero-1'))!;
    expect(zustand.currentAsp, 0, reason: 'keine AsP gebucht');
    final eintrag = zustand.diceLog.single;
    expect(eintrag.title, 'Spruchspeicher: Stirnreif');
    expect(eintrag.subtitle, contains('Psychostabilis + Illusion auflösen'));
    expect(eintrag.subtitle, contains('Ziel: Verhandlungspartner'));
  });

  testWidgets('die letzte Ladung eines einmaligen Speichers löscht die Magie', (
    tester,
  ) async {
    await zeige(
      tester,
      _stirnreif(
        art: ArtefaktArt.spruchspeicherEinmalig,
        ladungen: [_ladung('a')],
      ),
    );
    await oeffneDialog(tester);

    await bestaetige(tester);

    expect(
      schluessel('spruchspeicher-ausloesen-erloschen'),
      findsOneWidget,
      reason: 'der Dialog nennt, dass die Magie erloschen ist',
    );
    final held = await repo.gespeichert('hero-1');
    expect(
      held.inventoryEntries.single.artefaktDaten!.ladungen.single.verbraucht,
      isTrue,
    );
    expect(
      held.inventoryEntries.single.isMagisch,
      isTrue,
      reason: 'der Eintrag bleibt, die App entfernt nichts',
    );
  });

  testWidgets(
    'ein leerer, aufladbarer Speicher bietet Aufladen statt Auslösen',
    (tester) async {
      await zeige(
        tester,
        _stirnreif(ladungen: [_ladung('a', verbraucht: true)]),
      );

      expect(schluessel('inventory-editor-ausloesen'), findsNothing);
      expect(schluessel('inventory-editor-aufladen'), findsOneWidget);
    },
  );

  testWidgets('ein erloschener einmaliger Speicher bietet nichts an', (
    tester,
  ) async {
    await zeige(
      tester,
      _stirnreif(
        art: ArtefaktArt.spruchspeicherEinmalig,
        ladungen: [_ladung('a', verbraucht: true)],
      ),
    );

    expect(schluessel('inventory-editor-ausloesen'), findsNothing);
    expect(schluessel('inventory-editor-aufladen'), findsNothing);
  });

  testWidgets('ein beschädigter Speicher bietet keine Aktion an', (
    tester,
  ) async {
    await zeige(tester, _stirnreif(defekt: true));

    expect(schluessel('inventory-editor-ausloesen'), findsNothing);
    expect(schluessel('inventory-editor-aufladen'), findsNothing);
  });

  testWidgets('wurde der Gegenstand inzwischen geändert, bleibt alles stehen', (
    tester,
  ) async {
    await zeige(tester, _stirnreif());
    await oeffneDialog(tester);
    repo.fremdeAenderung = (held) => held.copyWith(
      inventoryEntries: [
        held.inventoryEntries.single.copyWith(gegenstand: 'Umbenannt'),
      ],
    );

    await bestaetige(tester);

    expect(schluessel('spruchspeicher-ausloesen-fehler'), findsOneWidget);
    expect(find.textContaining('inzwischen geändert'), findsOneWidget);
    expect(repo.bogenSpeicherungen, 0);
    expect((await repo.loadHeroState('hero-1'))!.diceLog, isEmpty);
  });
}
