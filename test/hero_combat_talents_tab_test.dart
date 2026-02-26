import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

void main() {
  HeroSheet buildHero({List<String> hiddenTalentIds = const <String>[]}) {
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
      hiddenTalentIds: hiddenTalentIds,
    );
  }

  RulesCatalog buildCatalog() {
    return const RulesCatalog(
      version: 'test_catalog',
      source: 'test',
      talents: <TalentDef>[
        TalentDef(
          id: 'tal_nah',
          name: 'Dolche',
          group: 'Kampftalent',
          type: 'Nahkampf',
          weaponCategory: 'Dolch',
          steigerung: 'D',
          attributes: <String>['Mut', 'Gewandheit', 'Koerperkraft'],
        ),
        TalentDef(
          id: 'tal_fern',
          name: 'Boegen',
          group: 'Kampftalent',
          type: 'Fernkampf',
          weaponCategory: 'Bogen',
          steigerung: 'D',
          attributes: <String>['Intuition', 'Fingerfertigkeit', 'Koerperkraft'],
        ),
        TalentDef(
          id: 'tal_misc',
          name: 'Athletik',
          group: 'Koerper',
          steigerung: 'C',
          attributes: <String>['Mut', 'Gewandheit', 'Koerperkraft'],
        ),
      ],
      spells: <SpellDef>[],
      weapons: <WeaponDef>[],
    );
  }

  Future<WorkspaceTabEditActions> openCombatTab(
    WidgetTester tester,
    FakeRepository repo,
    RulesCatalog catalog,
  ) async {
    WorkspaceTabEditActions? actions;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => catalog),
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

  testWidgets('shows only combat talents grouped by type', (tester) async {
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

    await openCombatTab(tester, repo, buildCatalog());

    expect(find.text('Nahkampf'), findsOneWidget);
    expect(find.text('Fernkampf'), findsOneWidget);
    expect(find.text('Dolche'), findsOneWidget);
    expect(find.text('Boegen'), findsOneWidget);
    expect(find.text('Athletik'), findsNothing);
  });

  testWidgets('global edit flow persists combat talent changes', (tester) async {
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

    final actions = await openCombatTab(tester, repo, buildCatalog());
    await actions.startEdit();
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-field-tal_nah-talentValue')),
      '8',
    );
    final visibilityToggle = find.byKey(
      const ValueKey<String>('talents-visibility-tal_nah'),
    );
    await tester.ensureVisible(visibilityToggle);
    await tester.tap(visibilityToggle);
    await tester.pumpAndSettle();
    await actions.save();
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.talents['tal_nah']?.talentValue, 8);
    expect(hero.hiddenTalentIds, contains('tal_nah'));
    expect(find.text('Dolche'), findsNothing);
  });
}
