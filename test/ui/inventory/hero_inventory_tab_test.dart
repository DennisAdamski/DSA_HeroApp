import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

HeroSheet _buildHero({
  List<HeroInventoryEntry> inventoryEntries = const [],
}) {
  return HeroSheet(
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
    inventoryEntries: inventoryEntries,
  );
}

Future<WorkspaceTabEditActions> _openTab(
  WidgetTester tester,
  FakeRepository repo,
) async {
  WorkspaceTabEditActions? actions;
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
            onRegisterEditActions: (a) => actions = a,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(actions, isNotNull);
  return actions!;
}

void main() {
  group('HeroInventoryTab – Filter-Chips', () {
    testWidgets('zeigt alle Filter-Chips an', (tester) async {
      final repo = FakeRepository(heroes: [_buildHero()]);
      await _openTab(tester, repo);

      expect(find.text('Alle'), findsOneWidget);
      expect(find.text('Ausrüstung'), findsOneWidget);
      expect(find.text('Verbrauchsgegenstände'), findsOneWidget);
      expect(find.text('Wertvolles'), findsOneWidget);
      expect(find.text('Sonstiges'), findsOneWidget);
      expect(find.text('Waffen (auto)'), findsOneWidget);
      expect(find.text('Geschosse (auto)'), findsOneWidget);
    });

    testWidgets('filtert Eintraege nach Typ', (tester) async {
      final repo = FakeRepository(
        heroes: [
          _buildHero(
            inventoryEntries: [
              const HeroInventoryEntry(
                gegenstand: 'Trank',
                itemType: InventoryItemType.verbrauchsgegenstand,
              ),
              const HeroInventoryEntry(
                gegenstand: 'Ring',
                itemType: InventoryItemType.wertvolles,
              ),
            ],
          ),
        ],
      );
      await _openTab(tester, repo);

      // Beide Eintraege sichtbar im Filter 'Alle'
      expect(find.text('Trank'), findsOneWidget);
      expect(find.text('Ring'), findsOneWidget);

      // Auf 'Wertvolles' filtern (FilterChip gezielt ansprechen)
      await tester.tap(find.widgetWithText(FilterChip, 'Wertvolles'));
      await tester.pumpAndSettle();

      expect(find.text('Ring'), findsOneWidget);
      expect(find.text('Trank'), findsNothing);
    });
  });

  group('HeroInventoryTab – Verlinkter Eintrag (kein Delete-Button)', () {
    testWidgets(
      'verlinkter Eintrag hat keinen Loeschen-Button im Edit-Modus',
      (tester) async {
        final repo = FakeRepository(
          heroes: [
            _buildHero(
              inventoryEntries: [
                const HeroInventoryEntry(
                  gegenstand: 'Langschwert',
                  source: InventoryItemSource.waffe,
                  sourceRef: 'w:Langschwert',
                  istAusgeruestet: true,
                ),
              ],
            ),
          ],
        );
        final actions = await _openTab(tester, repo);
        await actions.startEdit();
        await tester.pumpAndSettle();

        expect(find.text('Langschwert'), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsNothing);
      },
    );
  });

  group('HeroInventoryTab – Manueller Eintrag (Delete-Button vorhanden)', () {
    testWidgets(
      'manueller Eintrag hat Loeschen-Button im Edit-Modus',
      (tester) async {
        final repo = FakeRepository(
          heroes: [
            _buildHero(
              inventoryEntries: [
                const HeroInventoryEntry(
                  gegenstand: 'Rucksack',
                  source: InventoryItemSource.manuell,
                ),
              ],
            ),
          ],
        );
        final actions = await _openTab(tester, repo);
        await actions.startEdit();
        await tester.pumpAndSettle();

        expect(find.text('Rucksack'), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      },
    );

    testWidgets(
      'verlinkter und manueller Eintrag: nur manueller hat Delete-Button',
      (tester) async {
        final repo = FakeRepository(
          heroes: [
            _buildHero(
              inventoryEntries: [
                const HeroInventoryEntry(
                  gegenstand: 'Langschwert',
                  source: InventoryItemSource.waffe,
                  sourceRef: 'w:Langschwert',
                ),
                const HeroInventoryEntry(
                  gegenstand: 'Rucksack',
                  source: InventoryItemSource.manuell,
                ),
              ],
            ),
          ],
        );
        final actions = await _openTab(tester, repo);
        await actions.startEdit();
        await tester.pumpAndSettle();

        // Genau ein Delete-Button (nur fuer Rucksack)
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);

        // Delete-Button ist im Rucksack-Card
        final rucksackCard = find.ancestor(
          of: find.text('Rucksack'),
          matching: find.byType(Card),
        );
        expect(
          find.descendant(
            of: rucksackCard,
            matching: find.byIcon(Icons.delete_outline),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('HeroInventoryTab – Eintrag hinzufuegen und loeschen', () {
    testWidgets('Gegenstand hinzufuegen-Button erzeugt neuen Eintrag',
        (tester) async {
      final repo = FakeRepository(heroes: [_buildHero()]);
      final actions = await _openTab(tester, repo);
      await actions.startEdit();
      await tester.pumpAndSettle();

      expect(find.text('Keine Einträge in dieser Kategorie.'), findsOneWidget);

      await tester.tap(find.text('Gegenstand hinzufügen'));
      await tester.pumpAndSettle();

      // Kein Leer-Text mehr; der neue Eintrag erscheint
      expect(find.text('Keine Einträge in dieser Kategorie.'), findsNothing);
    });

    testWidgets('manuellen Eintrag loeschen entfernt ihn aus der Liste',
        (tester) async {
      final repo = FakeRepository(
        heroes: [
          _buildHero(
            inventoryEntries: [
              const HeroInventoryEntry(
                gegenstand: 'Seil',
                source: InventoryItemSource.manuell,
              ),
            ],
          ),
        ],
      );
      final actions = await _openTab(tester, repo);
      await actions.startEdit();
      await tester.pumpAndSettle();

      expect(find.text('Seil'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Seil'), findsNothing);
      expect(find.text('Keine Einträge in dieser Kategorie.'), findsOneWidget);
    });
  });
}
