import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/alchimika_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_instance_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/elixier_einnehmen_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/inventory_item_editor.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/planung_bearbeiten_guard.dart';

import '../../test_support/real_catalog.dart';

const _attribute = Attributes(
  mu: 12,
  kl: 12,
  inn: 12,
  ch: 12,
  ff: 12,
  ge: 12,
  ko: 12,
  kk: 12,
);

const _zustand = HeroState(
  currentLep: 20,
  currentAsp: 0,
  currentKap: 0,
  currentAu: 20,
);

Finder _key(String schluessel) => find.byKey(ValueKey<String>(schluessel));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EchterKatalog echt;
  late HeroInventoryEntry elixier;

  setUpAll(() async {
    echt = await ladeEchtenRegelkatalog();
    final mittel = echt.catalog.alchimika.firstWhere(
      (m) => m.id == 'alch_mutelixier',
    );
    elixier = mitAlchimikum(
      const HeroInventoryEntry(
        instanzId: 'mut-1',
        menge: 2,
        anzahl: '2',
        gegenstand: 'Mutelixier',
      ),
      mittel,
      'E',
    );
  });

  HeroSheet held(HeroInventoryEntry eintrag) => HeroSheet(
    id: 'demo',
    name: 'Rondra',
    level: 1,
    attributes: _attribute,
    inventoryEntries: [eintrag],
  );

  Future<FakeRepository> zeige(
    WidgetTester tester,
    Widget Function(HeroInventoryEntry) baue,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRepository(
      heroes: [held(elixier)],
      states: {'demo': _zustand},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          ...echt.overrides,
        ],
        child: MaterialApp(home: Scaffold(body: baue(elixier))),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('zeigt die Katalogwirkung, legt sie an und zieht ein Stück ab', (
    tester,
  ) async {
    var fertig = 0;
    final repo = await zeige(
      tester,
      (eintrag) => ElixierPanel(
        heroId: 'demo',
        eintrag: eintrag,
        onFertig: () => fertig++,
      ),
    );

    expect(find.text('Mutelixier, Qualität E'), findsOneWidget);
    expect(_key('elixier-eigenschaft-MU'), findsOneWidget);
    expect(find.textContaining('MU +3 · 1 Tag'), findsOneWidget);

    await tester.tap(_key('elixier-einnehmen'));
    await tester.pumpAndSettle();

    final z = (await repo.loadHeroState('demo'))!;
    expect(z.activeSpellEffects.instanzen, hasLength(1));
    expect(effektiveTempAttributeMods(z).mu, 3);
    expect(z.diceLog, hasLength(1));
    final h = (await repo.loadHeroById('demo'))!;
    expect(h.inventoryEntries.single.menge, 1);
    expect(fertig, 1);
  });

  testWidgets('ohne Abbuchung bleibt der Bestand', (tester) async {
    final repo = await zeige(
      tester,
      (eintrag) =>
          ElixierPanel(heroId: 'demo', eintrag: eintrag, onFertig: () {}),
    );

    await tester.tap(_key('elixier-verbrauchen'));
    await tester.pumpAndSettle();
    await tester.tap(_key('elixier-einnehmen'));
    await tester.pumpAndSettle();

    final z = (await repo.loadHeroState('demo'))!;
    expect(z.activeSpellEffects.instanzen, hasLength(1));
    final h = (await repo.loadHeroById('demo'))!;
    expect(h.inventoryEntries.single.menge, 2);
  });

  testWidgets('ein Gegenstand ohne Katalogverweis hat keine Wirkung', (
    tester,
  ) async {
    await zeige(
      tester,
      (_) => ElixierPanel(
        heroId: 'demo',
        eintrag: const HeroInventoryEntry(gegenstand: 'Wasser'),
        onFertig: () {},
      ),
    );
    expect(_key('elixier-keine-wirkung'), findsOneWidget);
    expect(_key('elixier-einnehmen'), findsNothing);
  });

  testWidgets('der Inventareditor bietet bei einem Elixier „Anwenden“ an', (
    tester,
  ) async {
    await zeige(
      tester,
      (eintrag) => PlanungsBearbeitungsBereich(
        heroId: 'demo',
        child: InventoryItemEditor(
          entry: eintrag,
          onSaved: (_) async {},
          onCancelled: () {},
        ),
      ),
    );
    expect(_key('inventory-editor-anwenden'), findsOneWidget);
  });
}
