import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory_tab.dart';

import '../../test_support/bogen_test_repository.dart';

// Verkaufen im Inventareditor (ARCH-03): Der Erlös ist mit dem vollen Wert
// vorbelegt, folgt der Anzahl und kommt auf den Geldstand.

const _held = HeroSheet(
  id: 'hero-1',
  name: 'Thalion',
  level: 1,
  attributes: Attributes(
    mu: 12,
    kl: 11,
    inn: 10,
    ch: 10,
    ff: 11,
    ge: 12,
    ko: 11,
    kk: 12,
  ),
  dukaten: '10',
  inventoryEntries: [
    HeroInventoryEntry(
      gegenstand: 'Fackel',
      anzahl: '5',
      menge: 5,
      wertSilber: 2,
      instanzId: 'f',
    ),
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

  Future<void> oeffneVerkauf(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey<String>('inventory-row-open-0')),
    );
    await tester.pumpAndSettle();
    final knopf = find.byKey(const ValueKey<String>('inventory-editor-sell'));
    await tester.ensureVisible(knopf);
    await tester.tap(knopf);
    await tester.pumpAndSettle();
  }

  String erloes(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const ValueKey<String>('verkaufen-erloes')))
      .controller!
      .text;

  testWidgets('drei Fackeln zum vollen Wert', (tester) async {
    await zeige(tester);
    await oeffneVerkauf(tester);
    expect(erloes(tester), '1');

    await tester.tap(find.byKey(const ValueKey<String>('verkaufen-minus')));
    await tester.tap(find.byKey(const ValueKey<String>('verkaufen-minus')));
    await tester.pump();
    expect(erloes(tester), '0,6');
    await tester.tap(find.byKey(const ValueKey<String>('verkaufen-ok')));
    await tester.pumpAndSettle();

    final gespeichert = await repo.gespeichert('hero-1');
    expect(gespeichert.dukaten, '10,6');
    expect(gespeichert.inventoryEntries.single.menge, 2);
  });

  testWidgets('ein eingetippter Erlös gilt', (tester) async {
    await zeige(tester);
    await oeffneVerkauf(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('verkaufen-erloes')),
      '2 D',
    );
    await tester.tap(find.byKey(const ValueKey<String>('verkaufen-minus')));
    await tester.pump();
    expect(erloes(tester), '2 D');
    await tester.tap(find.byKey(const ValueKey<String>('verkaufen-ok')));
    await tester.pumpAndSettle();

    final gespeichert = await repo.gespeichert('hero-1');
    expect(gespeichert.dukaten, '12');
    expect(gespeichert.inventoryEntries.single.menge, 1);
  });
}
