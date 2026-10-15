import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/vitalwirkung.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/vitalwirkung_anwenden_dialog.dart';

const _trank = HeroInventoryEntry(
  gegenstand: 'Heiltrank',
  itemType: InventoryItemType.verbrauchsgegenstand,
  instanzId: 'trank-1',
  menge: 2,
  anzahl: '2',
  vitalwirkung: Vitalwirkung(lep: 8, wunden: 1),
);

const _held = HeroSheet(
  id: 'demo',
  name: 'Rondra',
  level: 1,
  attributes: Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  ),
  inventoryEntries: [_trank],
);

const _leererKatalog = RulesCatalog(
  version: 'test_catalog',
  source: 'test',
  talents: <TalentDef>[],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
);

final _zustand = const HeroState(
  currentLep: 10,
  currentAsp: 0,
  currentKap: 0,
  currentAu: 20,
).copyWith(wpiZustand: const WundZustand(wundenProZone: {WundZone.brust: 2}));

Finder _key(String schluessel) => find.byKey(ValueKey<String>(schluessel));

void main() {
  late int fertig;

  Future<FakeRepository> zeigePanel(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    fertig = 0;
    final repo = FakeRepository(heroes: [_held], states: {'demo': _zustand});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => _leererKatalog),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VitalwirkungPanel(
                heroId: 'demo',
                eintrag: _trank,
                onFertig: () => fertig++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('füllt die Vorgabe vor, bucht Wirkung und zieht ein Stück ab', (
    tester,
  ) async {
    final repo = await zeigePanel(tester);

    expect(
      tester.widget<TextField>(_key('vitalwirkung-lep')).controller!.text,
      '8',
    );
    expect(tester.widget<Text>(_key('vitalwirkung-wunden-brust')).data, '1');
    expect(find.textContaining('LeP 10 → 18'), findsOneWidget);

    await tester.tap(_key('vitalwirkung-uebernehmen'));
    await tester.pumpAndSettle();

    final z = (await repo.loadHeroState('demo'))!;
    expect(z.currentLep, 18);
    expect(z.wpiZustand.wundenInZone(WundZone.brust), 1);
    expect(z.buchungen, hasLength(1));
    final held = (await repo.loadHeroById('demo'))!;
    expect(held.inventoryEntries.single.menge, 1);
    expect(fertig, 1);
  });

  testWidgets('Werte und Wunden lassen sich vor dem Anwenden ändern', (
    tester,
  ) async {
    final repo = await zeigePanel(tester);

    await tester.enterText(_key('vitalwirkung-lep'), '5');
    await tester.tap(_key('vitalwirkung-wunden-plus-brust'));
    await tester.tap(_key('vitalwirkung-verbrauchen'));
    await tester.pumpAndSettle();
    await tester.tap(_key('vitalwirkung-uebernehmen'));
    await tester.pumpAndSettle();

    final z = (await repo.loadHeroState('demo'))!;
    expect(z.currentLep, 15);
    expect(z.wpiZustand.wundenInZone(WundZone.brust), 0);
    // Abgewählt: der Bestand bleibt.
    final held = (await repo.loadHeroById('demo'))!;
    expect(held.inventoryEntries.single.menge, 2);
  });

  testWidgets('ohne jede Wirkung bleibt Anwenden gesperrt', (tester) async {
    await zeigePanel(tester);
    await tester.enterText(_key('vitalwirkung-lep'), '');
    await tester.tap(_key('vitalwirkung-wunden-minus-brust'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(_key('vitalwirkung-uebernehmen')).onPressed,
      isNull,
    );
  });
}
