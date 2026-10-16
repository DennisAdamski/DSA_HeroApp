import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/planung_bearbeiten_guard.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

import '../../test_support/bogen_test_repository.dart';

// Zaubertalisman (Auxiliator) einsetzen: Der Anwender spricht den Zauber
// selbst; der Talisman liefert zusätzliche ZfP* (höchstens der ZfW, bei
// fremder Repräsentation die Hälfte, nur bei einem Spruch, der auch ohne ihn
// gelungen wäre). Gebucht werden Zauberkosten plus 1W3 AsP samt Protokoll.

HeroInventoryEntry _ring({
  MatrixStabilitaet stabilitaet = MatrixStabilitaet.stabil,
  bool defekt = false,
  int zfpStern = 8,
}) => HeroInventoryEntry(
  gegenstand: 'Mondsilberring',
  isMagisch: true,
  instanzId: 'i-1',
  artefaktDaten: ArtefaktDaten(
    art: ArtefaktArt.zaubertalisman,
    stabilitaet: stabilitaet,
    defekt: defekt,
    zauber: <ArtefaktZauber>[
      ArtefaktZauber(
        spellId: 'spell_ignifaxius',
        name: 'Ignifaxius',
        repraesentation: 'Mag',
        zfw: 14,
        zfpStern: zfpStern,
        kostenAsp: 9,
      ),
    ],
  ),
);

HeroSheet _held(HeroInventoryEntry eintrag, {int? zfw}) => HeroSheet(
  id: 'hero-1',
  name: 'Thalion',
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
  spells: {
    if (zfw != null)
      'spell_ignifaxius': HeroSpellEntry(
        spellValue: zfw,
        learnedRepresentation: 'Mag',
      ),
  },
  inventoryEntries: [eintrag],
);

void main() {
  late BogenTestRepository repo;

  Future<void> zeige(
    WidgetTester tester,
    HeroInventoryEntry eintrag, {
    int asp = 30,
    int? zfw,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 2600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = BogenTestRepository(
      heroes: [_held(eintrag, zfw: zfw)],
      states: {
        'hero-1': HeroState(
          currentLep: 30,
          currentAsp: asp,
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

  Future<void> eintragen(WidgetTester tester, String name, String text) async {
    await tester.enterText(schluessel('auxiliator-$name'), text);
    await tester.pumpAndSettle();
  }

  Future<void> vonHand(
    WidgetTester tester, {
    required String w3,
    required String w20,
    String? zusatz,
    String? hemmung,
  }) async {
    await tester.tap(schluessel('auxiliator-von-hand'));
    await tester.pumpAndSettle();
    await tester.enterText(schluessel('auxiliator-w3'), w3);
    await tester.enterText(schluessel('auxiliator-w20'), w20);
    if (zusatz != null) {
      await tester.enterText(schluessel('auxiliator-w20-zusatz'), zusatz);
    }
    if (hemmung != null) {
      await tester.enterText(schluessel('auxiliator-w6-hemmung'), hemmung);
    }
  }

  Future<void> einsetzen(WidgetTester tester) async {
    await tester.tap(schluessel('auxiliator-bestaetigen'));
    await tester.pumpAndSettle();
  }

  testWidgets('der Editor bietet „Auxiliator einsetzen“ statt „Auslösen“', (
    tester,
  ) async {
    await zeige(tester, _ring());

    expect(
      find.descendant(
        of: schluessel('inventory-editor-ausloesen'),
        matching: find.text('Auxiliator einsetzen'),
      ),
      findsOneWidget,
    );
    expect(
      schluessel('inventory-editor-artefakt-talisman-hinweis'),
      findsOneWidget,
    );
    expect(schluessel('inventory-editor-artefakt-stabilitaet'), findsOneWidget);
  });

  testWidgets('der Dialog erklärt den Weg und rechnet den Bonus', (
    tester,
  ) async {
    await zeige(tester, _ring(), zfw: 12);
    await oeffneDialog(tester);

    await eintragen(tester, 'zfp', '6');
    await eintragen(tester, 'rep', 'Mag');

    expect(find.textContaining('spricht den Zauber selbst'), findsOneWidget);
    expect(find.text('Bonus: 8 ZfP* · Gesamt: 14 ZfP*'), findsOneWidget);
    // Der ZfW aus dem Bogen ist als Vorgabe sichtbar.
    final feld = tester.widget<TextField>(schluessel('auxiliator-zfw'));
    expect(feld.decoration!.hintText, '12');
  });

  testWidgets('der ZfW des Anwenders deckelt den Bonus', (tester) async {
    await zeige(tester, _ring(), zfw: 5);
    await oeffneDialog(tester);

    await eintragen(tester, 'zfp', '6');
    await eintragen(tester, 'rep', 'Mag');

    expect(find.text('Bonus: 5 ZfP* · Gesamt: 11 ZfP*'), findsOneWidget);
    expect(find.text('Begrenzt durch den ZfW des Anwenders.'), findsOneWidget);
  });

  testWidgets('fremde Repräsentation halbiert den Bonus', (tester) async {
    await zeige(tester, _ring(), zfw: 12);
    await oeffneDialog(tester);

    await eintragen(tester, 'zfp', '6');
    await eintragen(tester, 'rep', 'Dru');

    expect(find.text('Bonus: 4 ZfP* · Gesamt: 10 ZfP*'), findsOneWidget);
    expect(find.text('Fremde Repräsentation: nur die Hälfte.'), findsOneWidget);
  });

  testWidgets('ein überschriebener Bonus gilt', (tester) async {
    await zeige(tester, _ring(), zfw: 12);
    await oeffneDialog(tester);

    await eintragen(tester, 'zfp', '6');
    await eintragen(tester, 'rep', 'Mag');
    await eintragen(tester, 'bonus-feld', '3');

    expect(find.text('Bonus: 3 ZfP* · Gesamt: 9 ZfP*'), findsOneWidget);
  });

  testWidgets('bucht Zauberkosten plus 1W3, Protokoll und Gesamt-ZfP*', (
    tester,
  ) async {
    await zeige(tester, _ring(), zfw: 12);
    await oeffneDialog(tester);
    await eintragen(tester, 'zfp', '6');
    await eintragen(tester, 'rep', 'Mag');
    await eintragen(tester, 'ziel', 'Ork');
    await vonHand(tester, w3: '2', w20: '5');

    await einsetzen(tester);

    expect(schluessel('auxiliator-fehler'), findsNothing);
    expect(find.text('ZfP* 6 + 8 = 14'), findsOneWidget);
    expect(find.text('11 AsP abgezogen.'), findsOneWidget);
    expect(find.text('Die Matrix hält ohne Zwischenfall.'), findsOneWidget);
    final zustand = (await repo.loadHeroState('hero-1'))!;
    expect(zustand.currentAsp, 19);
    final eintrag = zustand.diceLog.single;
    expect(eintrag.title, 'Auxiliator: Mondsilberring');
    expect(eintrag.subtitle, contains('ZfP* 6 + 8 = 14'));
    expect(eintrag.subtitle, contains('Ziel: Ork'));
    expect(repo.bogenSpeicherungen, 0, reason: 'der Bogen bleibt unberührt');
  });

  testWidgets('ein misslungener Spruch: kein Bonus, +2 auf den Ausfallwurf', (
    tester,
  ) async {
    await zeige(tester, _ring(), zfw: 12);
    await oeffneDialog(tester);
    await eintragen(tester, 'zfp', '0');
    await eintragen(tester, 'rep', 'Mag');
    await tester.tap(schluessel('auxiliator-gelungen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bonus: 0 ZfP*'), findsOneWidget);
    expect(find.textContaining('Ausfallwurf +2'), findsOneWidget);
    // stabil 2012: 17–19 gehemmt, 20 beschädigt; 18 + 2 = 20.
    await vonHand(tester, w3: '1', w20: '18');

    await einsetzen(tester);

    expect(find.text('Spruch misslungen, kein Bonus.'), findsOneWidget);
    expect(find.text('Die Matrix ist irreparabel beschädigt.'), findsOneWidget);
    expect(repo.bogenSpeicherungen, 0, reason: 'noch nichts am Bogen');
    await tester.tap(schluessel('auxiliator-defekt'));
    await tester.pumpAndSettle();
    final held = await repo.gespeichert('hero-1');
    expect(held.inventoryEntries.single.artefaktDaten!.defekt, isTrue);
    expect(find.textContaining('als beschädigt vermerkt'), findsOneWidget);
  });

  testWidgets('eine Hemmung nennt die Spielrunden', (tester) async {
    await zeige(tester, _ring(), zfw: 12);
    await oeffneDialog(tester);
    await eintragen(tester, 'zfp', '6');
    await eintragen(tester, 'rep', 'Mag');
    await vonHand(tester, w3: '1', w20: '17', hemmung: '4');

    await einsetzen(tester);

    expect(find.textContaining('für 4 Spielrunden gehemmt'), findsOneWidget);
    expect(schluessel('auxiliator-defekt'), findsNothing);
  });

  testWidgets('die Zauberkosten lassen sich anpassen', (tester) async {
    await zeige(tester, _ring(), zfw: 12);
    await oeffneDialog(tester);
    await eintragen(tester, 'zfp', '6');
    await eintragen(tester, 'rep', 'Mag');
    await eintragen(tester, 'kosten', '4');
    await vonHand(tester, w3: '3', w20: '2');

    await einsetzen(tester);

    expect(find.text('7 AsP abgezogen.'), findsOneWidget);
    expect((await repo.loadHeroState('hero-1'))!.currentAsp, 23);
  });

  testWidgets('zu wenig AsP: Fehler im Dialog, nichts gebucht', (tester) async {
    await zeige(tester, _ring(), asp: 5, zfw: 12);
    await oeffneDialog(tester);
    await eintragen(tester, 'zfp', '6');
    await eintragen(tester, 'rep', 'Mag');
    await vonHand(tester, w3: '2', w20: '5');

    await einsetzen(tester);

    expect(find.textContaining('Zu wenig AsP'), findsOneWidget);
    expect((await repo.loadHeroState('hero-1'))!.currentAsp, 5);
  });

  testWidgets('ohne ZfP* der Probe gibt es eine Fehlermeldung', (tester) async {
    await zeige(tester, _ring(), zfw: 12);
    await oeffneDialog(tester);
    await vonHand(tester, w3: '2', w20: '5');

    await einsetzen(tester);

    expect(find.textContaining('ZfP* der Probe'), findsWidgets);
    expect(schluessel('auxiliator-fehler'), findsOneWidget);
    expect((await repo.loadHeroState('hero-1'))!.currentAsp, 30);
  });

  testWidgets('Würfe außerhalb des Bereichs werden abgewiesen', (tester) async {
    await zeige(tester, _ring(), zfw: 12);
    await oeffneDialog(tester);
    await eintragen(tester, 'zfp', '6');
    await eintragen(tester, 'rep', 'Mag');
    await vonHand(tester, w3: '4', w20: '5');

    await einsetzen(tester);

    expect(find.textContaining('W3 liegt außerhalb'), findsOneWidget);
    expect((await repo.loadHeroState('hero-1'))!.currentAsp, 30);
  });

  testWidgets('ein beschädigter Talisman bietet keine Aktion an', (
    tester,
  ) async {
    await zeige(tester, _ring(defekt: true));

    expect(schluessel('inventory-editor-ausloesen'), findsNothing);
  });
}
