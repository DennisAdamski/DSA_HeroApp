import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

import 'support/frame_timing_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  HeroSheet buildHero() {
    return const HeroSheet(
      id: 'demo',
      name: 'Rondra',
      level: 1,
      attributes: Attributes(
        mu: 14,
        kl: 12,
        inn: 13,
        ch: 11,
        ff: 10,
        ge: 12,
        ko: 14,
        kk: 13,
      ),
      combatConfig: CombatConfig(),
    );
  }

  RulesCatalog buildCatalog() {
    return const RulesCatalog(
      version: 'test_catalog',
      source: 'test',
      talents: <TalentDef>[
        TalentDef(
          id: 'tal_a',
          name: 'Athletik',
          group: 'Koerper',
          steigerung: 'C',
          attributes: <String>['Mut', 'Gewandtheit', 'Koerperkraft'],
        ),
        TalentDef(
          id: 'tal_nah',
          name: 'Schwerter',
          group: 'Kampftalent',
          type: 'Nahkampf',
          weaponCategory: 'Schwert',
          steigerung: 'D',
          attributes: <String>['Mut', 'Gewandtheit', 'Koerperkraft'],
        ),
      ],
      spells: <SpellDef>[],
      weapons: <WeaponDef>[],
    );
  }

  Future<WorkspaceTabEditActions> openTalentsTab(
    WidgetTester tester,
    FakeRepository repo,
  ) async {
    WorkspaceTabEditActions? actions;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => buildCatalog()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HeroTalentsTab(
              heroId: 'demo',
              onDirtyChanged: (_) {},
              onEditingChanged: (_) {},
              onRegisterDiscard: (_) {},
              onRegisterEditActions: (registered) {
                actions = registered;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(actions, isNotNull);
    return actions!;
  }

  Future<WorkspaceTabEditActions> openCombatTab(
    WidgetTester tester,
    FakeRepository repo,
  ) async {
    WorkspaceTabEditActions? actions;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => buildCatalog()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HeroCombatTalentsTab(
              heroId: 'demo',
              onDirtyChanged: (_) {},
              onEditingChanged: (_) {},
              onRegisterDiscard: (_) {},
              onRegisterEditActions: (registered) {
                actions = registered;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(actions, isNotNull);
    return actions!;
  }

  Future<WorkspaceTabEditActions> openOverviewTab(
    WidgetTester tester,
    FakeRepository repo,
  ) async {
    WorkspaceTabEditActions? actions;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [heroRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: HeroOverviewTab(
              heroId: 'demo',
              onDirtyChanged: (_) {},
              onEditingChanged: (_) {},
              onRegisterDiscard: (_) {},
              onRegisterEditActions: (registered) {
                actions = registered;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(actions, isNotNull);
    return actions!;
  }

  void reportScenario({
    required String scenario,
    required FrameTimingHarness harness,
  }) {
    final p50BuildMicros = harness.percentileBuildMicros(50);
    final p95BuildMicros = harness.percentileBuildMicros(95);
    debugPrint(
      'PERF_METRIC $scenario sampleCount=${harness.sampleCount} '
      'p50_build_us=$p50BuildMicros p95_build_us=$p95BuildMicros',
    );
    final nextData = <String, Object>{
      ...?binding.reportData,
      '${scenario}_sampleCount': harness.sampleCount,
      '${scenario}_p50_build_us': p50BuildMicros,
      '${scenario}_p95_build_us': p95BuildMicros,
    };
    binding.reportData = nextData;
    expect(harness.sampleCount, greaterThan(0));
    expect(
      p95BuildMicros,
      lessThan(32000),
      reason:
          'Frame build p95 should stay clearly below visible stutter levels '
          '(target release budget remains 16ms).',
    );
  }

  testWidgets('captures frame timing for repeated talent row edits', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [buildHero()],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    final actions = await openTalentsTab(tester, repo);
    await actions.startEdit();
    await tester.pumpAndSettle();

    final harness = FrameTimingHarness();
    harness.reset();
    harness.start();

    for (var i = 0; i < 20; i++) {
      await tester.enterText(
        find.byKey(const ValueKey<String>('talents-field-tal_a-talentValue')),
        '${i % 10}',
      );
      await tester.pump();
    }

    await tester.pumpAndSettle();
    harness.stop();
    reportScenario(scenario: 'talents_edit', harness: harness);
  });

  testWidgets('captures frame timing for repeated combat row edits', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [buildHero()],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    final actions = await openCombatTab(tester, repo);
    await actions.startEdit();
    await tester.pumpAndSettle();

    final combatField = find.byKey(
      const ValueKey<String>('talents-field-tal_nah-talentValue'),
    );
    expect(combatField, findsAtLeastNWidgets(1));

    final harness = FrameTimingHarness();
    harness.reset();
    harness.start();

    for (var i = 0; i < 20; i++) {
      await tester.enterText(combatField.first, '${i % 10}');
      await tester.pump();
    }

    await tester.pumpAndSettle();
    harness.stop();
    reportScenario(scenario: 'combat_edit', harness: harness);
  });

  testWidgets('captures frame timing for repeated overview edits', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [buildHero()],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    final actions = await openOverviewTab(tester, repo);
    await actions.startEdit();
    await tester.pumpAndSettle();

    final harness = FrameTimingHarness();
    harness.reset();
    harness.start();

    for (var i = 0; i < 20; i++) {
      await tester.enterText(
        find.byKey(const ValueKey<String>('overview-field-ap_total')),
        '${1000 + i}',
      );
      await tester.pump();
    }

    await tester.pumpAndSettle();
    harness.stop();
    reportScenario(scenario: 'overview_edit', harness: harness);
  });

  testWidgets('captures frame timing for overview AP increment action', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [buildHero()],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    final actions = await openOverviewTab(tester, repo);
    await actions.startEdit();
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('overview-field-ap_total_add')),
      '10',
    );
    await tester.pumpAndSettle();

    final harness = FrameTimingHarness();
    harness.reset();
    harness.start();

    for (var i = 0; i < 5; i++) {
      await tester.tap(
        find.byKey(const ValueKey<String>('overview-action-ap_total_add')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey<String>('overview-field-ap_total_add')),
        '10',
      );
      await tester.pump();
    }

    await tester.pumpAndSettle();
    harness.stop();
    reportScenario(scenario: 'overview_ap_increment', harness: harness);
  });
}
