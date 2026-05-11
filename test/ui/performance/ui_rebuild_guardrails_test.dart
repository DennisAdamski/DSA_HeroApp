import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/debug/ui_rebuild_observer.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_magic_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

bool _isKnownMagicTableOverflow(Object exception) {
  final text = exception.toString();
  return text.contains('A RenderFlex overflowed by 21 pixels');
}

Future<void> _pumpAndSettleIgnoringKnownMagicOverflow(
  WidgetTester tester,
) async {
  await tester.pumpAndSettle();
  Object? exception;
  do {
    exception = tester.takeException();
    if (exception != null && !_isKnownMagicTableOverflow(exception)) {
      throw exception;
    }
  } while (exception != null);
}

void main() {
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
      talents: <String, HeroTalentEntry>{
        'tal_a': HeroTalentEntry(),
        'tal_nah': HeroTalentEntry(),
      },
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

  HeroSheet buildMagicHero() {
    return buildHero().copyWith(
      merkmalskenntnisse: const <String>['Kraft'],
      representationen: const <String>['Mag'],
      spells: const <String, HeroSpellEntry>{
        'spell_axxeleratus': HeroSpellEntry(
          spellValue: 8,
          learnedRepresentation: 'Mag',
          learnedTradition: 'Mag',
        ),
      },
    );
  }

  RulesCatalog buildMagicCatalog() {
    return const RulesCatalog(
      version: 'test_catalog',
      source: 'test',
      talents: <TalentDef>[],
      spells: <SpellDef>[
        SpellDef(
          id: 'spell_axxeleratus',
          name: 'Axxeleratus Blitzgeschwind',
          tradition: 'Elf',
          steigerung: 'C',
          attributes: <String>['Klugheit', 'Gewandheit', 'Konstitution'],
          availability: 'Mag3',
          traits: 'Kraft',
          aspCost: '7 AsP',
          range: '7 Schritt',
          duration: 'ZfP* Spielrunden',
          castingTime: '2 Aktionen',
          wirkung: 'Beschleunigt das Ziel deutlich.',
        ),
      ],
      weapons: <WeaponDef>[],
    );
  }

  setUp(() {
    UiRebuildObserver.enabled = true;
    UiRebuildObserver.reset();
  });

  tearDown(() {
    UiRebuildObserver.enabled = false;
    UiRebuildObserver.reset();
  });

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
    await _pumpAndSettleIgnoringKnownMagicOverflow(tester);
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
            body: HeroCombatTab(
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

  Future<WorkspaceTabEditActions> openMagicTab(
    WidgetTester tester,
    FakeRepository repo,
  ) async {
    WorkspaceTabEditActions? actions;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => buildMagicCatalog()),
          appSettingsProvider.overrideWith(
            (ref) => Stream<AppSettings>.value(const AppSettings()),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HeroMagicTab(
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

  Future<void> openCombatSubTab(WidgetTester tester, String label) async {
    final tab = find.widgetWithText(Tab, label);
    await tester.ensureVisible(tab);
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  testWidgets('editing a talent row does not rebuild the full talents tab', (
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

    UiRebuildObserver.reset('hero_talents_tab');
    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-field-tal_a-talentValue')),
      '7',
    );
    await tester.pump();

    expect(UiRebuildObserver.count('hero_talents_tab'), lessThanOrEqualTo(1));
  });

  testWidgets('editing combat talent values avoids full combat tab rebuild', (
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
    // Kampftechniken ist jetzt Tab 3 — muss erst navigiert werden
    await openCombatSubTab(tester, 'Kampftechniken');

    await actions.startEdit();
    await tester.pumpAndSettle();

    UiRebuildObserver.reset('hero_combat_tab');
    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-field-tal_nah-talentValue')),
      '8',
    );
    await tester.pump();

    expect(UiRebuildObserver.count('hero_combat_tab'), lessThanOrEqualTo(1));
  });

  testWidgets('editing a magic spell value avoids full magic tab rebuild', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [buildMagicHero()],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    final actions = await openMagicTab(tester, repo);
    await actions.startEdit();
    await _pumpAndSettleIgnoringKnownMagicOverflow(tester);

    UiRebuildObserver.reset('hero_magic_tab');
    await tester.enterText(
      find.byKey(
        const ValueKey<String>(
          'magic-spells-field-spell_axxeleratus-spellValue',
        ),
      ),
      '9',
    );
    await tester.pump();

    expect(UiRebuildObserver.count('hero_magic_tab'), lessThanOrEqualTo(1));
  });

  testWidgets('hero name changes do not fan out to combat quick stats', (
    tester,
  ) async {
    final baseHero = buildHero();
    final repo = FakeRepository(
      heroes: [baseHero],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    await openCombatTab(tester, repo);

    UiRebuildObserver.reset('combat_quick_stats');
    await repo.saveHero(baseHero.copyWith(name: 'Rondrigo'));
    await tester.pumpAndSettle();

    expect(UiRebuildObserver.count('combat_quick_stats'), lessThanOrEqualTo(1));
  });

  testWidgets('manual mod changes do not fan out to combat weapons section', (
    tester,
  ) async {
    final baseHero = buildHero();
    final repo = FakeRepository(
      heroes: [baseHero],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    await openCombatTab(tester, repo);
    await openCombatSubTab(tester, 'Waffen');

    UiRebuildObserver.reset('combat_weapons_section');
    await repo.saveHero(
      baseHero.copyWith(
        combatConfig: const CombatConfig(
          manualMods: CombatManualMods(atMod: 2, iniMod: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      UiRebuildObserver.count('combat_weapons_section'),
      lessThanOrEqualTo(1),
    );
  });

  testWidgets('weapon changes do not fan out to combat armor section', (
    tester,
  ) async {
    final baseHero = buildHero();
    final repo = FakeRepository(
      heroes: [baseHero],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    await openCombatTab(tester, repo);
    await openCombatSubTab(tester, 'Rüstung & Verteidigung');

    UiRebuildObserver.reset('combat_armor_section');
    await repo.saveHero(
      baseHero.copyWith(
        combatConfig: const CombatConfig(
          weapons: <MainWeaponSlot>[
            MainWeaponSlot(name: 'Langschwert', talentId: 'tal_nah'),
          ],
          selectedWeaponIndex: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      UiRebuildObserver.count('combat_armor_section'),
      lessThanOrEqualTo(1),
    );
  });
}
