import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/bought_stats.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

void main() {
  HeroSheet buildHero() {
    return HeroSheet(
      id: 'demo',
      name: 'Rondra',
      level: 1,
      attributes: const Attributes(
        mu: 14,
        kl: 12,
        inn: 13,
        ch: 11,
        ff: 10,
        ge: 12,
        ko: 14,
        kk: 13,
      ),
    );
  }

  testWidgets('attribute row opens shared probe dialog via dice icon', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: <HeroSheet>[buildHero()],
      states: <String, HeroState>{
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith(
            (ref) async => _buildRulesCatalog(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HeroOverviewTab(
              heroId: 'demo',
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

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('overview-roll-mu')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('overview-roll-mu')));
    await tester.pumpAndSettle();

    expect(find.text('Eigenschaftsprobe: Mut'), findsOneWidget);
  });

  testWidgets('bought stat dialog respects rule maximum for LeP', (
    tester,
  ) async {
    WorkspaceTabEditActions? editActions;
    final repo = FakeRepository(
      heroes: <HeroSheet>[
        buildHero().copyWith(
          apTotal: 9999,
          apAvailable: 9999,
          bought: const BoughtStats(lep: 7),
        ),
      ],
      states: <String, HeroState>{
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith(
            (ref) async => _buildRulesCatalog(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HeroOverviewTab(
              heroId: 'demo',
              onDirtyChanged: (_) {},
              onEditingChanged: (_) {},
              onRegisterDiscard: (_) {},
              onRegisterEditActions: (actions) {
                editActions = actions;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await editActions!.startEdit();
    await tester.pumpAndSettle();

    final raiseButton = find.byKey(
      const ValueKey<String>('overview-derived-raise-b_lep'),
    );
    await tester.scrollUntilVisible(
      raiseButton,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(raiseButton);
    await tester.pumpAndSettle();

    expect(find.text('LeP steigern'), findsOneWidget);
    expect(find.text('Aktueller Wert: 7 | Maximaler Wert: 7'), findsOneWidget);
    expect(find.text('Der Maximalwert ist bereits erreicht.'), findsOneWidget);
  });

  testWidgets('advantage chips can be selected from catalog and saved', (
    tester,
  ) async {
    WorkspaceTabEditActions? editActions;
    final repo = FakeRepository(
      heroes: <HeroSheet>[buildHero()],
      states: <String, HeroState>{
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith(
            (ref) async => _buildRulesCatalog(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HeroOverviewTab(
              heroId: 'demo',
              onDirtyChanged: (_) {},
              onEditingChanged: (_) {},
              onRegisterDiscard: (_) {},
              onRegisterEditActions: (actions) {
                editActions = actions;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await editActions!.startEdit();
    await tester.pumpAndSettle();

    final addAdvantageButton = find.byKey(
      const ValueKey<String>('overview-add-trait-vorteile'),
    );
    await tester.scrollUntilVisible(
      addAdvantageButton,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(addAdvantageButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Astralmacht');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Astralmacht'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '3');
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();

    await editActions!.save();
    await tester.pumpAndSettle();

    final saved = await repo.loadHeroById('demo');
    expect(saved!.vorteileText, 'Astralmacht 3');
    expect(saved.unknownModifierFragments, isEmpty);
  });
}

RulesCatalog _buildRulesCatalog() {
  return const RulesCatalog(
    version: 'test',
    source: 'test',
    talents: <TalentDef>[],
    spells: <SpellDef>[],
    weapons: <WeaponDef>[],
    advantages: <HeroTraitDef>[
      HeroTraitDef(
        id: 'adv_astralmacht',
        name: 'Astralmacht',
        traitType: 'advantage',
        costText: 'je 1 GP für 1 AsP',
        valueKind: 'points',
        minValue: 1,
        maxValue: 6,
        unit: 'AsP',
        selectionTemplate: 'Astralmacht {value}',
      ),
      HeroTraitDef(
        id: 'adv_flink',
        name: 'Flink',
        traitType: 'advantage',
        costText: '10 GP',
        valueKind: 'binary',
        selectionTemplate: 'Flink',
      ),
    ],
    disadvantages: <HeroTraitDef>[
      HeroTraitDef(
        id: 'dis_kurzatmig',
        name: 'Kurzatmig',
        traitType: 'disadvantage',
        costText: 'je -1 GP / 2 AuP',
        valueKind: 'points',
        minValue: 1,
        maxValue: 6,
        unit: 'AuP',
        selectionTemplate: 'Kurzatmig {value}',
      ),
    ],
  );
}
