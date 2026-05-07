import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

HeroSheet _buildHero({
  List<HeroInventoryEntry> inventoryEntries = const <HeroInventoryEntry>[],
  String dukaten = '',
  CombatConfig combatConfig = const CombatConfig(),
}) {
  return HeroSheet(
    id: 'hero-1',
    name: 'Thalion',
    level: 1,
    dukaten: dukaten,
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
    combatConfig: combatConfig,
  );
}

Future<void> _openTab(
  WidgetTester tester,
  FakeRepository repo, {
  Size size = const Size(1200, 800),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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

Finder _dukatenField() {
  return find.descendant(
    of: find.byKey(const ValueKey<String>('inventory-dukaten-field')),
    matching: find.byType(TextField),
  );
}

class _InventoryWorkspaceHarness extends StatefulWidget {
  const _InventoryWorkspaceHarness({required this.heroId});

  final String heroId;

  @override
  State<_InventoryWorkspaceHarness> createState() =>
      _InventoryWorkspaceHarnessState();
}

class _InventoryWorkspaceHarnessState
    extends State<_InventoryWorkspaceHarness> {
  WorkspaceTabEditActions? _actions;

  void _registerActions(WorkspaceTabEditActions actions) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() => _actions = actions);
    });
  }

  @override
  Widget build(BuildContext context) {
    final headerActions =
        _actions?.headerActions ?? const <WorkspaceHeaderAction>[];

    return Scaffold(
      appBar: AppBar(
        actions: [
          for (final action in headerActions)
            if (action.showWhenIdle) Builder(builder: action.builder),
        ],
      ),
      body: HeroInventoryTab(
        heroId: widget.heroId,
        onDirtyChanged: (_) {},
        onEditingChanged: (_) {},
        onRegisterDiscard: (_) {},
        onRegisterEditActions: _registerActions,
      ),
    );
  }
}

Future<void> _openWorkspaceHarness(
  WidgetTester tester,
  FakeRepository repo, {
  Size size = const Size(740, 844),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [heroRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        home: _InventoryWorkspaceHarness(heroId: 'hero-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('HeroInventoryTab – Tabelle und Filter', () {
    testWidgets('zeigt die Filter-Chips und die Inventartabelle', (
      tester,
    ) async {
      final repo = FakeRepository(
        heroes: <HeroSheet>[
          _buildHero(
            inventoryEntries: const <HeroInventoryEntry>[
              HeroInventoryEntry(
                gegenstand: 'Rucksack',
                source: InventoryItemSource.manuell,
              ),
            ],
          ),
        ],
      );

      await _openTab(tester, repo);

      expect(find.text('Alle'), findsOneWidget);
      expect(find.text('Ausrüstung'), findsOneWidget);
      expect(find.text('Verbrauchsgegenstände'), findsOneWidget);
      expect(find.text('Wertvolles'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Sonstiges'), findsOneWidget);
      expect(find.text('Waffen (auto)'), findsOneWidget);
      expect(find.text('Geschosse (auto)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('inventory-table')),
        findsOneWidget,
      );
    });

    testWidgets('filtert Einträge nach Typ', (tester) async {
      final repo = FakeRepository(
        heroes: <HeroSheet>[
          _buildHero(
            inventoryEntries: const <HeroInventoryEntry>[
              HeroInventoryEntry(
                gegenstand: 'Trank',
                itemType: InventoryItemType.verbrauchsgegenstand,
              ),
              HeroInventoryEntry(
                gegenstand: 'Ring',
                itemType: InventoryItemType.wertvolles,
              ),
            ],
          ),
        ],
      );

      await _openTab(tester, repo);

      expect(find.text('Trank'), findsOneWidget);
      expect(find.text('Ring'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Wertvolles'));
      await tester.pumpAndSettle();

      expect(find.text('Ring'), findsOneWidget);
      expect(find.text('Trank'), findsNothing);
    });
  });

  group('HeroInventoryTab – Zeilenaktionen', () {
    testWidgets('verlinkter Eintrag hat keinen Delete-Button', (tester) async {
      final repo = FakeRepository(
        heroes: <HeroSheet>[
          _buildHero(
            inventoryEntries: const <HeroInventoryEntry>[
              HeroInventoryEntry(
                gegenstand: 'Langschwert',
                source: InventoryItemSource.waffe,
                sourceRef: 'w:Langschwert',
                istAusgeruestet: true,
              ),
            ],
          ),
        ],
      );

      await _openTab(tester, repo);

      expect(find.text('Langschwert'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('inventory-row-delete-0')),
        findsNothing,
      );
    });

    testWidgets('manueller Eintrag hat einen Delete-Button', (tester) async {
      final repo = FakeRepository(
        heroes: <HeroSheet>[
          _buildHero(
            inventoryEntries: const <HeroInventoryEntry>[
              HeroInventoryEntry(
                gegenstand: 'Rucksack',
                source: InventoryItemSource.manuell,
              ),
            ],
          ),
        ],
      );

      await _openTab(tester, repo);

      expect(find.text('Rucksack'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('inventory-row-delete-0')),
        findsOneWidget,
      );
    });

    testWidgets('manuellen Eintrag bearbeiten speichert sofort', (
      tester,
    ) async {
      final repo = FakeRepository(
        heroes: <HeroSheet>[
          _buildHero(
            inventoryEntries: const <HeroInventoryEntry>[
              HeroInventoryEntry(
                gegenstand: 'Seil',
                source: InventoryItemSource.manuell,
              ),
            ],
          ),
        ],
      );

      await _openTab(tester, repo);

      await tester.tap(
        find.byKey(const ValueKey<String>('inventory-row-open-0')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gegenstand bearbeiten'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey<String>('inventory-editor-name')),
        'Seil, 20 m',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('inventory-editor-save')),
      );
      await tester.pumpAndSettle();

      final heroes = await repo.listHeroes();
      final hero = heroes.single;
      expect(hero.inventoryEntries.single.gegenstand, 'Seil, 20 m');
    });

    testWidgets('verknüpfter Eintrag pflegt magisch und geweiht im Inventar', (
      tester,
    ) async {
      final repo = FakeRepository(
        heroes: <HeroSheet>[
          _buildHero(
            combatConfig: const CombatConfig(
              weapons: [MainWeaponSlot(name: 'Langschwert')],
            ),
            inventoryEntries: const <HeroInventoryEntry>[
              HeroInventoryEntry(
                gegenstand: 'Langschwert',
                itemType: InventoryItemType.ausruestung,
                source: InventoryItemSource.waffe,
                sourceRef: 'w:Langschwert',
                istAusgeruestet: true,
              ),
            ],
          ),
        ],
      );

      await _openTab(tester, repo);

      await tester.tap(
        find.byKey(const ValueKey<String>('inventory-row-open-0')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('inventory-editor-magisch')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('inventory-editor-magisch-description'),
        ),
        'Runenätzung',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('inventory-editor-geweiht')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('inventory-editor-geweiht-description'),
        ),
        'Rahjaweihe',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('inventory-editor-save')),
      );
      await tester.pumpAndSettle();

      final heroes = await repo.listHeroes();
      final hero = heroes.single;
      expect(hero.inventoryEntries.single.isMagisch, isTrue);
      expect(hero.inventoryEntries.single.magischDescription, 'Runenätzung');
      expect(hero.inventoryEntries.single.isGeweiht, isTrue);
      expect(hero.inventoryEntries.single.geweihtDescription, 'Rahjaweihe');
      expect(hero.combatConfig.weaponSlots.single.isArtifact, isTrue);
      expect(
        hero.combatConfig.weaponSlots.single.artifactDescription,
        'Runenätzung',
      );
      expect(hero.combatConfig.weaponSlots.single.isGeweiht, isTrue);
      expect(
        hero.combatConfig.weaponSlots.single.geweihtDescription,
        'Rahjaweihe',
      );
    });

    testWidgets('manuellen Eintrag löschen entfernt ihn nach Bestätigung', (
      tester,
    ) async {
      final repo = FakeRepository(
        heroes: <HeroSheet>[
          _buildHero(
            inventoryEntries: const <HeroInventoryEntry>[
              HeroInventoryEntry(
                gegenstand: 'Seil',
                source: InventoryItemSource.manuell,
              ),
            ],
          ),
        ],
      );

      await _openTab(tester, repo);

      final deleteButton = tester.widget<IconButton>(
        find.byKey(const ValueKey<String>('inventory-row-delete-0')),
      );
      deleteButton.onPressed!.call();
      await tester.pumpAndSettle();

      expect(find.text('Gegenstand löschen'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
      await tester.pumpAndSettle();

      final heroes = await repo.listHeroes();
      final hero = heroes.single;
      expect(hero.inventoryEntries, isEmpty);
      expect(find.text('Keine Einträge in dieser Kategorie.'), findsOneWidget);
    });
  });

  group('HeroInventoryTab – Direktes Speichern', () {
    testWidgets('Dukaten speichern bei Fokusverlust direkt', (tester) async {
      final repo = FakeRepository(
        heroes: <HeroSheet>[_buildHero(dukaten: '5')],
      );

      await _openTab(tester, repo);

      await tester.enterText(_dukatenField(), '12');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final heroes = await repo.listHeroes();
      final hero = heroes.single;
      expect(hero.dukaten, '12');
    });

    testWidgets('Dukaten lassen sich per Silbertaler-Schritt erhöhen', (
      tester,
    ) async {
      final repo = FakeRepository(
        heroes: <HeroSheet>[_buildHero(dukaten: '5')],
      );

      await _openTab(tester, repo);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('inventory-dukaten-increment-silber'),
        ),
      );
      await tester.pumpAndSettle();

      final heroes = await repo.listHeroes();
      final hero = heroes.single;
      expect(hero.dukaten, '5,1');
      expect(find.text('5 D / 1 S'), findsOneWidget);
    });

    testWidgets('Kreuzer-Schritte erhalten gemischte Münzwerte genau', (
      tester,
    ) async {
      final repo = FakeRepository(
        heroes: <HeroSheet>[_buildHero(dukaten: '1 D 2 S')],
      );

      await _openTab(tester, repo);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('inventory-dukaten-increment-kreuzer'),
        ),
      );
      await tester.pumpAndSettle();

      final heroes = await repo.listHeroes();
      final hero = heroes.single;
      expect(hero.dukaten, '1,201');
      expect(find.text('1 D / 2 S / 1 K'), findsOneWidget);
    });

    testWidgets('Dukaten-Schritte werden beim Senken bei null begrenzt', (
      tester,
    ) async {
      final repo = FakeRepository(
        heroes: <HeroSheet>[_buildHero(dukaten: '0')],
      );

      await _openTab(tester, repo);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('inventory-dukaten-decrement-dukaten'),
        ),
      );
      await tester.pumpAndSettle();

      final heroes = await repo.listHeroes();
      final hero = heroes.single;
      expect(hero.dukaten, '0');
    });

    testWidgets('Header-Aktion fügt Gegenstand direkt hinzu', (tester) async {
      final repo = FakeRepository(heroes: <HeroSheet>[_buildHero()]);

      await _openWorkspaceHarness(tester, repo);

      await tester.tap(
        find.byKey(const ValueKey<String>('inventory-header-add')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('inventory-editor-name')),
        'Proviant',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('inventory-editor-save')),
      );
      await tester.pumpAndSettle();

      final heroes = await repo.listHeroes();
      final hero = heroes.single;
      expect(hero.inventoryEntries, hasLength(1));
      expect(hero.inventoryEntries.single.gegenstand, 'Proviant');
    });
  });

  group('HeroInventoryTab – Breites Layout', () {
    testWidgets('breites Layout öffnet den Editor als Split-Panel', (
      tester,
    ) async {
      final repo = FakeRepository(
        heroes: <HeroSheet>[
          _buildHero(
            inventoryEntries: const <HeroInventoryEntry>[
              HeroInventoryEntry(
                gegenstand: 'Rucksack',
                source: InventoryItemSource.manuell,
              ),
            ],
          ),
        ],
      );

      await _openTab(tester, repo, size: const Size(1400, 900));

      expect(
        find.byKey(const ValueKey<String>('inventory-editor-panel')),
        findsNothing,
      );
      expect(
        find.text('Gegenstand auswählen oder oben rechts hinzufügen.'),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('inventory-row-open-0')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('inventory-editor-panel')),
        findsOneWidget,
      );
      expect(find.text('Gegenstand bearbeiten'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('inventory-editor-name')),
        findsOneWidget,
      );
    });
  });
}
