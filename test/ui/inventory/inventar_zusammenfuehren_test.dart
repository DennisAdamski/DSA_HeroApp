import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory_tab.dart';

import '../../test_support/bogen_test_repository.dart';

// Stapel zusammenführen im Inventareditor (ARCH-03): Der Knopf erscheint nur
// mit passendem Stapel, die Auswahl nennt Menge und Ort.

HeroInventoryEntry _pfeile(String id, int menge, String ort) {
  return HeroInventoryEntry(
    gegenstand: 'Pfeil',
    anzahl: '$menge',
    menge: menge,
    itemType: InventoryItemType.verbrauchsgegenstand,
    woGetragen: ort,
    instanzId: id,
  );
}

final _held = HeroSheet(
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
  inventoryEntries: [
    _pfeile('r', 8, 'Rucksack'),
    _pfeile('k', 12, 'Köcher'),
    const HeroInventoryEntry(gegenstand: 'Seil', instanzId: 's'),
  ],
);

void main() {
  late BogenTestRepository repo;

  Future<void> zeige(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = BogenTestRepository(heroes: [_held]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [heroRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: HeroInventoryTab(
              heroId: 'hero-1',
              onDirtyChanged: (_) {},
              onEditingChanged: (_) {},
              onRegisterDiscard: (_) {},
              onRegisterEditActions: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> oeffne(WidgetTester tester, int zeile) async {
    await tester.tap(find.byKey(ValueKey<String>('inventory-row-open-$zeile')));
    await tester.pumpAndSettle();
  }

  final knopf = find.byKey(const ValueKey<String>('inventory-editor-merge'));

  testWidgets('der Rucksack geht in den Köcher', (tester) async {
    await zeige(tester);
    await oeffne(tester, 0);

    await tester.ensureVisible(knopf);
    await tester.tap(knopf);
    await tester.pumpAndSettle();
    expect(find.text('Pfeil — 12 Stück · Köcher'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('inventory-zielstapel-0')),
    );
    await tester.pumpAndSettle();

    final gespeichert = await repo.gespeichert('hero-1');
    final pfeile = gespeichert.inventoryEntries.where(
      (e) => e.gegenstand == 'Pfeil',
    );
    expect(pfeile.single.instanzId, 'k');
    expect(pfeile.single.menge, 20);
  });

  testWidgets('ohne passenden Stapel gibt es keinen Knopf', (tester) async {
    await zeige(tester);
    await oeffne(tester, 2);

    expect(knopf, findsNothing);
  });
}
