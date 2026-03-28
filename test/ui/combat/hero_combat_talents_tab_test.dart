import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

void main() {
  HeroSheet buildHero({
    Attributes attributes = const Attributes(
      mu: 14,
      kl: 12,
      inn: 13,
      ch: 11,
      ff: 10,
      ge: 12,
      ko: 14,
      kk: 13,
    ),
    Map<String, HeroTalentEntry> talents = const <String, HeroTalentEntry>{},
  }) {
    return HeroSheet(
      id: 'demo',
      name: 'Rondra',
      level: 1,
      attributes: attributes,
      talents: talents,
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
          weaponCategory: 'Dolch, Kurzschwert',
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
    // Beide Kampftalente im Helden aktiv.
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{
            'tal_nah': HeroTalentEntry(),
            'tal_fern': HeroTalentEntry(),
          },
        ),
      ],
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
    expect(find.text('Waffengattung'), findsAtLeastNWidgets(1));
    expect(find.text('Ersatzweise'), findsAtLeastNWidgets(1));
    expect(find.text('AT'), findsAtLeastNWidgets(1));
    expect(find.text('PA'), findsAtLeastNWidgets(1));
    expect(find.text('Eigenschaften'), findsNothing);
  });

  testWidgets(
    'gifted combat talents use reduced complexity and fixed max TaW rules',
    (tester) async {
      final repo = FakeRepository(
        heroes: [
          buildHero(
            attributes: const Attributes(
              mu: 14,
              kl: 12,
              inn: 18,
              ch: 11,
              ff: 10,
              ge: 12,
              ko: 14,
              kk: 13,
            ),
            talents: const <String, HeroTalentEntry>{
              'tal_nah': HeroTalentEntry(gifted: true),
              'tal_fern': HeroTalentEntry(gifted: true),
            },
          ),
        ],
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

      expect(find.text('C'), findsNWidgets(2));
      expect(find.text('18'), findsNothing);

      await tester.tap(find.text('Dolche'));
      await tester.pumpAndSettle();
      expect(find.text('18'), findsOneWidget);
      await tester.tap(find.text('Schließen'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Boegen'));
      await tester.pumpAndSettle();
      expect(find.text('18'), findsOneWidget);
      expect(find.text('23'), findsNothing);
      await tester.tap(find.text('Schließen'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('only shows combat talents present in hero.talents', (
    tester,
  ) async {
    // Nur Fernkampf ist im Helden aktiv, Nahkampf fehlt.
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{
            'tal_fern': HeroTalentEntry(),
          },
        ),
      ],
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

    expect(find.text('Fernkampf'), findsOneWidget);
    expect(find.text('Nahkampf'), findsNothing);
    expect(find.text('Dolche'), findsNothing);
    expect(find.text('Boegen'), findsOneWidget);
  });

  testWidgets('blocks save for invalid Nahkampf AT/PA distribution', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{
            'tal_nah': HeroTalentEntry(),
            'tal_fern': HeroTalentEntry(),
          },
        ),
      ],
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
      '11',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-field-tal_nah-atValue')),
      '9',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-field-tal_nah-paValue')),
      '1',
    );

    await actions.save();
    await tester.pumpAndSettle();

    expect(find.textContaining('AT + PA = TaW'), findsOneWidget);

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.talents['tal_nah']?.talentValue ?? 0, 0);
    expect(hero.talents['tal_nah']?.atValue ?? 0, 0);
    expect(hero.talents['tal_nah']?.paValue ?? 0, 0);
  });

  testWidgets('blocks save for invalid Fernkampf distribution', (tester) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{
            'tal_nah': HeroTalentEntry(),
            'tal_fern': HeroTalentEntry(),
          },
        ),
      ],
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
      find.byKey(const ValueKey<String>('talents-field-tal_fern-talentValue')),
      '7',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-field-tal_fern-atValue')),
      '6',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-field-tal_fern-paValue')),
      '1',
    );

    await actions.save();
    await tester.pumpAndSettle();

    expect(find.textContaining('AT = TaW und PA = 0'), findsOneWidget);

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.talents['tal_fern']?.talentValue ?? 0, 0);
    expect(hero.talents['tal_fern']?.atValue ?? 0, 0);
    expect(hero.talents['tal_fern']?.paValue ?? 0, 0);
  });

  testWidgets('global edit flow persists valid combat talent changes', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{
            'tal_nah': HeroTalentEntry(),
            'tal_fern': HeroTalentEntry(),
          },
        ),
      ],
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
    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-field-tal_nah-atValue')),
      '5',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-field-tal_nah-paValue')),
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-field-tal_fern-talentValue')),
      '7',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-field-tal_fern-atValue')),
      '7',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-field-tal_fern-paValue')),
      '0',
    );
    await actions.save();
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.talents['tal_nah']?.talentValue, 8);
    expect(hero.talents['tal_nah']?.atValue, 5);
    expect(hero.talents['tal_nah']?.paValue, 3);
    expect(hero.talents['tal_fern']?.talentValue, 7);
    expect(hero.talents['tal_fern']?.atValue, 7);
    expect(hero.talents['tal_fern']?.paValue, 0);
  });

  testWidgets('saves multiple combat specializations for a combat talent', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{
            'tal_nah': HeroTalentEntry(),
            'tal_fern': HeroTalentEntry(),
          },
        ),
      ],
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
      '6',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-field-tal_nah-atValue')),
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-field-tal_nah-paValue')),
      '3',
    );

    final specButton = find.byKey(
      const ValueKey<String>('talents-combat-spec-add-tal_nah'),
    );
    await tester.ensureVisible(specButton);
    await tester.tap(specButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dolch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kurzschwert'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();

    await actions.save();
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    final entry = hero.talents['tal_nah'];
    expect(entry, isNotNull);
    expect(entry!.combatSpecializations, contains('Dolch'));
    expect(entry.combatSpecializations, contains('Kurzschwert'));
    expect(entry.specializations, contains('Dolch'));
    expect(entry.specializations, contains('Kurzschwert'));
  });
}
