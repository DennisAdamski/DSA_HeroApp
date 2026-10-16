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

// Matrixgeber auslösen: Der Träger lässt die Zauber-AsP einfließen, es gibt
// keine Zauberprobe, der Stabilitätswurf kann die Matrix beschädigen, und
// das Inventar verbraucht nichts.

const _armschiene = HeroInventoryEntry(
  gegenstand: 'Armschiene',
  isMagisch: true,
  instanzId: 'i-1',
  artefaktDaten: ArtefaktDaten(
    zauber: <ArtefaktZauber>[
      ArtefaktZauber(
        name: 'Gardianum',
        repraesentation: 'Mag',
        zfw: 12,
        zfpStern: 7,
        kostenAsp: 9,
        reichweite: 'Selbst',
      ),
      ArtefaktZauber(name: 'Armatrutz', kostenAsp: 6),
    ],
  ),
);

HeroSheet _held([HeroInventoryEntry eintrag = _armschiene]) => HeroSheet(
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
  inventoryEntries: [eintrag],
);

HeroState _zustand(int asp) =>
    HeroState(currentLep: 30, currentAsp: asp, currentKap: 0, currentAu: 30);

void main() {
  late BogenTestRepository repo;

  Future<void> zeige(
    WidgetTester tester, {
    int asp = 20,
    HeroInventoryEntry eintrag = _armschiene,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = BogenTestRepository(
      heroes: [_held(eintrag)],
      states: {'hero-1': _zustand(asp)},
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

  Future<void> tippeWurf(WidgetTester tester, String w20, {String? w6}) async {
    await tester.tap(
      find.byKey(const ValueKey<String>('matrix-ausloesen-von-hand')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('matrix-ausloesen-w20')),
      w20,
    );
    if (w6 != null) {
      await tester.enterText(
        find.byKey(const ValueKey<String>('matrix-ausloesen-w6-hemmung')),
        w6,
      );
    }
  }

  Future<void> bestaetige(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey<String>('matrix-ausloesen-bestaetigen')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('der Dialog zeigt die gespeicherte Wirkung und die Kosten', (
    tester,
  ) async {
    await zeige(tester);

    await oeffneDialog(tester);

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Gardianum'),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Repräsentation Mag · ZfW 12 · ZfP* 7'),
      findsOneWidget,
    );
    expect(find.text('Kosten: 15 AsP'), findsOneWidget);
    expect(find.textContaining('Zauberprobe gibt es nicht'), findsOneWidget);
  });

  testWidgets('bucht die AsP, schreibt ins Protokoll und verbraucht nichts', (
    tester,
  ) async {
    await zeige(tester);
    await oeffneDialog(tester);
    await tippeWurf(tester, '5');

    await bestaetige(tester);

    expect(find.text('15 AsP abgezogen.'), findsOneWidget);
    expect(
      find.text('Die Auslösung gelingt ohne Zwischenfall.'),
      findsOneWidget,
    );
    final zustand = (await repo.loadHeroState('hero-1'))!;
    expect(zustand.currentAsp, 5);
    expect(zustand.diceLog.single.title, 'Matrixgeber: Armschiene');
    final held = await repo.gespeichert('hero-1');
    expect(held.inventoryEntries.single.menge, isNot(0));
    expect(held.inventoryEntries.single.artefaktDaten!.defekt, isFalse);
    expect(repo.bogenSpeicherungen, 0, reason: 'der Bogen bleibt unberührt');
  });

  testWidgets('eine Hemmung nennt die Spielrunden und ändert den Bogen nicht', (
    tester,
  ) async {
    await zeige(tester);
    await oeffneDialog(tester);
    await tippeWurf(tester, '17', w6: '4');

    await bestaetige(tester);

    expect(find.textContaining('für 4 Spielrunden gehemmt'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('matrix-ausloesen-defekt')),
      findsNothing,
    );
    expect(repo.bogenSpeicherungen, 0);
  });

  testWidgets(
    'irreparabel: erst die ausdrückliche Aktion vermerkt den Defekt',
    (tester) async {
      await zeige(tester);
      await oeffneDialog(tester);
      await tippeWurf(tester, '20');

      await bestaetige(tester);

      expect(
        find.text('Die Matrix ist irreparabel beschädigt.'),
        findsOneWidget,
      );
      expect(repo.bogenSpeicherungen, 0, reason: 'noch nichts am Bogen');
      await tester.tap(
        find.byKey(const ValueKey<String>('matrix-ausloesen-defekt')),
      );
      await tester.pumpAndSettle();

      final held = await repo.gespeichert('hero-1');
      expect(held.inventoryEntries.single.artefaktDaten!.defekt, isTrue);
      expect(find.textContaining('als beschädigt vermerkt'), findsOneWidget);
    },
  );

  testWidgets('zu wenig AsP: Fehler im Dialog, nichts gebucht', (tester) async {
    await zeige(tester, asp: 10);
    await oeffneDialog(tester);
    await tippeWurf(tester, '5');

    await bestaetige(tester);

    expect(
      find.byKey(const ValueKey<String>('matrix-ausloesen-fehler')),
      findsOneWidget,
    );
    expect(find.textContaining('Zu wenig AsP'), findsOneWidget);
    expect((await repo.loadHeroState('hero-1'))!.currentAsp, 10);
  });

  testWidgets('ein beschädigter Matrixgeber bietet keine Auslösung an', (
    tester,
  ) async {
    await zeige(
      tester,
      eintrag: _armschiene.copyWith(
        artefaktDaten: _armschiene.artefaktDaten!.copyWith(defekt: true),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('inventory-editor-ausloesen')),
      findsNothing,
    );
  });

  testWidgets('Eingaben außerhalb des Würfelbereichs werden abgewiesen', (
    tester,
  ) async {
    await zeige(tester);
    await oeffneDialog(tester);
    await tippeWurf(tester, '21');

    await bestaetige(tester);

    expect(find.textContaining('außerhalb des Bereichs'), findsOneWidget);
    expect((await repo.loadHeroState('hero-1'))!.currentAsp, 20);
  });
}
