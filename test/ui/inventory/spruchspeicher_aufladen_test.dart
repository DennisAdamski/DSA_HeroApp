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

// Aufladbaren Spruchspeicher wieder aufladen: erst der Wurf auf die
// Haltematrix, dann „Übernehmen“. Wege der Alchimie 2012: nur die 20 schadet,
// jede bisherige Aufladung senkt die Schwelle um 1; Stäbe, Ringe,
// Dschinnenlampen 2011: 19–20.

HeroInventoryEntry _stirnreif({
  MatrixRegelfassung fassung = MatrixRegelfassung.alchimie2012,
  int aufladungen = 0,
  int? gesamt,
}) => HeroInventoryEntry(
  gegenstand: 'Stirnreif',
  isMagisch: true,
  instanzId: 'i-1',
  artefaktDaten: ArtefaktDaten(
    art: ArtefaktArt.spruchspeicherAufladbar,
    regelfassung: fassung,
    aufladungen: aufladungen,
    gesamtAspErschaffung: gesamt,
    ladungen: const <ArtefaktLadung>[
      ArtefaktLadung(
        id: 'a',
        verbraucht: true,
        zauber: <ArtefaktZauber>[
          ArtefaktZauber(
            spellId: 'spell_psy',
            name: 'Psychostabilis',
            kostenAsp: 9,
          ),
        ],
      ),
      ArtefaktLadung(
        id: 'b',
        verbraucht: true,
        zauber: <ArtefaktZauber>[
          ArtefaktZauber(
            spellId: 'spell_psy',
            name: 'Psychostabilis',
            kostenAsp: 9,
          ),
        ],
      ),
    ],
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

void main() {
  late BogenTestRepository repo;

  Future<void> zeige(WidgetTester tester, HeroInventoryEntry eintrag) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = BogenTestRepository(
      heroes: [_held(eintrag)],
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
    final knopf = find.byKey(
      const ValueKey<String>('inventory-editor-aufladen'),
    );
    await tester.ensureVisible(knopf);
    await tester.tap(knopf);
    await tester.pumpAndSettle();
  }

  Finder schluessel(String name) => find.byKey(ValueKey<String>(name));

  Future<void> tippeWurf(WidgetTester tester, String w20) async {
    await tester.ensureVisible(schluessel('spruchspeicher-aufladen-von-hand'));
    await tester.tap(schluessel('spruchspeicher-aufladen-von-hand'));
    await tester.pumpAndSettle();
    await tester.enterText(schluessel('spruchspeicher-aufladen-w20'), w20);
    await tester.pumpAndSettle();
  }

  Future<void> pruefe(WidgetTester tester) async {
    await tester.tap(schluessel('spruchspeicher-aufladen-wuerfeln'));
    await tester.pumpAndSettle();
  }

  Future<void> uebernehme(WidgetTester tester) async {
    await tester.tap(schluessel('spruchspeicher-aufladen-uebernehmen'));
    await tester.pumpAndSettle();
  }

  testWidgets('der Dialog nennt die Schwelle nach Fassung und Aufladungen', (
    tester,
  ) async {
    await zeige(tester, _stirnreif(aufladungen: 2));

    expect(
      find.textContaining('beschädigt ab W20 18 (Wege der Alchimie 2012, 2 '),
      findsOneWidget,
    );
  });

  testWidgets('Fassung 2011: Schwelle 19, auch nach mehreren Aufladungen', (
    tester,
  ) async {
    await zeige(
      tester,
      _stirnreif(fassung: MatrixRegelfassung.staebeRinge2011, aufladungen: 3),
    );

    expect(find.textContaining('beschädigt ab W20 19 ('), findsOneWidget);
  });

  testWidgets('unversehrt: Übernehmen lädt neu, zählt hoch und protokolliert', (
    tester,
  ) async {
    await zeige(tester, _stirnreif());
    await tippeWurf(tester, '19');

    await pruefe(tester);

    expect(
      find.textContaining('W20 19: Die Haltematrix ist unversehrt'),
      findsOneWidget,
    );
    expect(repo.bogenSpeicherungen, 0, reason: 'erst Übernehmen schreibt');

    await uebernehme(tester);

    expect(find.text('Der Spruchspeicher ist neu geladen.'), findsOneWidget);
    final daten = (await repo.gespeichert('hero-1'))
        .inventoryEntries
        .single
        .artefaktDaten!;
    expect(daten.ladungen.map((l) => l.verbraucht), [false, false]);
    expect(daten.aufladungen, 1);
    expect(daten.defekt, isFalse);
    expect(repo.bogenSpeicherungen, 1);
    final eintrag = (await repo.loadHeroState('hero-1'))!.diceLog.single;
    expect(eintrag.title, 'Aufladen: Stirnreif');
    expect(eintrag.subtitle, contains('W20 19 (Schaden ab 20)'));
  });

  testWidgets('die 20 beschädigt: Übernehmen vermerkt den Defekt, lädt nicht', (
    tester,
  ) async {
    await zeige(tester, _stirnreif());
    await tippeWurf(tester, '20');

    await pruefe(tester);
    expect(find.textContaining('irreparabel beschädigt'), findsWidgets);
    await uebernehme(tester);

    expect(
      find.text('Der Gegenstand ist als irreparabel beschädigt vermerkt.'),
      findsOneWidget,
    );
    final daten = (await repo.gespeichert('hero-1'))
        .inventoryEntries
        .single
        .artefaktDaten!;
    expect(daten.defekt, isTrue);
    expect(daten.ladungen.every((l) => l.verbraucht), isTrue);
    expect(daten.aufladungen, 0);
  });

  testWidgets('eine Aufladung früher schadet schon die 19 (Fassung 2012)', (
    tester,
  ) async {
    await zeige(tester, _stirnreif(aufladungen: 1));
    await tippeWurf(tester, '19');

    await pruefe(tester);
    await uebernehme(tester);

    final daten = (await repo.gespeichert('hero-1'))
        .inventoryEntries
        .single
        .artefaktDaten!;
    expect(daten.defekt, isTrue);
  });

  testWidgets('ein Wurf außerhalb 1–20 wird abgewiesen', (tester) async {
    await zeige(tester, _stirnreif());
    await tippeWurf(tester, '21');

    await pruefe(tester);

    expect(schluessel('spruchspeicher-aufladen-fehler'), findsOneWidget);
    expect(schluessel('spruchspeicher-aufladen-uebernehmen'), findsNothing);
    expect(repo.bogenSpeicherungen, 0);
  });

  testWidgets('ändern sich die Sprüche, ist das Ergebnis neu zu prüfen', (
    tester,
  ) async {
    await zeige(tester, _stirnreif(gesamt: 10));
    await tippeWurf(tester, '5');
    await pruefe(tester);

    expect(schluessel('spruchspeicher-aufladen-uebernehmen'), findsOneWidget);
    // Beide Ladungen kosten zusammen 18 AsP und überschreiten die 10 AsP.
    expect(find.textContaining('überschreiten die Gesamt-AsP'), findsOneWidget);

    await tester.ensureVisible(
      schluessel('spruchspeicher-aufladen-ladung-1-entfernen'),
    );
    await tester.tap(schluessel('spruchspeicher-aufladen-ladung-1-entfernen'));
    await tester.pumpAndSettle();

    expect(
      schluessel('spruchspeicher-aufladen-wuerfeln'),
      findsOneWidget,
      reason: 'ein geänderter Entwurf verlangt einen neuen Wurf',
    );
    // Eine Ladung kostet 9 AsP und passt in die 10 AsP; dafür fehlt jetzt ein
    // Spruch des Thesiskerns.
    expect(find.textContaining('überschreiten die Gesamt-AsP'), findsNothing);
    expect(
      find.textContaining('nicht alle zum selben Thesiskern'),
      findsOneWidget,
    );
  });

  testWidgets('mit nur einer Ladung lädt der Speicher mit einer neu', (
    tester,
  ) async {
    await zeige(tester, _stirnreif());
    await tester.ensureVisible(
      schluessel('spruchspeicher-aufladen-ladung-1-entfernen'),
    );
    await tester.tap(schluessel('spruchspeicher-aufladen-ladung-1-entfernen'));
    await tester.pumpAndSettle();
    await tippeWurf(tester, '3');
    await pruefe(tester);

    await uebernehme(tester);

    final daten = (await repo.gespeichert('hero-1'))
        .inventoryEntries
        .single
        .artefaktDaten!;
    expect(daten.ladungen.map((l) => l.id), ['a']);
    expect(daten.ladungen.single.verbraucht, isFalse);
  });
}
