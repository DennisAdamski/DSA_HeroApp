import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

void main() {
  HeroSheet buildHero() {
    return const HeroSheet(
      id: 'demo',
      name: 'Rondra',
      level: 7,
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
          id: 'tal_nah',
          name: 'Schwerter',
          group: 'Kampftalent',
          type: 'Nahkampf',
          weaponCategory: 'Schwert',
          steigerung: 'D',
          attributes: <String>['Mut', 'Gewandheit', 'Koerperkraft'],
        ),
      ],
      spells: <SpellDef>[],
      weapons: <WeaponDef>[
        WeaponDef(
          id: 'wpn_kurzschwert',
          name: 'Kurzschwert',
          type: 'Nahkampf',
          combatSkill: 'Schwerter',
          tp: '1W6+2',
          possibleManeuvers: <String>['Finte'],
        ),
        WeaponDef(
          id: 'wpn_bidenhaender',
          name: 'Bidenhaender',
          type: 'Nahkampf',
          combatSkill: 'Schwerter',
          tp: '2W6+2',
          possibleManeuvers: <String>['Wuchtschlag'],
        ),
      ],
    );
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

  Future<void> openWeaponEditor(WidgetTester tester, {bool add = false}) async {
    await tester.tap(
      find.byKey(
        ValueKey<String>(add ? 'combat-weapon-add' : 'combat-weapon-edit'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('combat-weapon-form-name')),
      findsOneWidget,
    );
  }

  Future<void> selectDialogDropdown(
    WidgetTester tester, {
    required String keyName,
    required String valueText,
  }) async {
    await tester.tap(find.byKey(ValueKey<String>(keyName)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(valueText).last);
    await tester.pumpAndSettle();
  }

  Future<void> fillWeaponDialog(
    WidgetTester tester, {
    required String name,
    required String weaponType,
    String talent = 'Schwerter',
    String kkBase = '12',
    String kkThreshold = '2',
    String iniMod = '0',
    String atMod = '0',
    String paMod = '0',
    String dice = '1',
    String tpValue = '2',
    String breakFactor = '0',
    bool oneHanded = true,
  }) async {
    await tester.enterText(
      find.byKey(const ValueKey<String>('combat-weapon-form-name')),
      name,
    );
    await selectDialogDropdown(
      tester,
      keyName: 'combat-weapon-form-talent',
      valueText: talent,
    );
    await selectDialogDropdown(
      tester,
      keyName: 'combat-weapon-form-weapon-type',
      valueText: weaponType,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('combat-weapon-form-kk-base')),
      kkBase,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('combat-weapon-form-kk-threshold')),
      kkThreshold,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('combat-weapon-form-ini-mod')),
      iniMod,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('combat-weapon-form-at-mod')),
      atMod,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('combat-weapon-form-pa-mod')),
      paMod,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('combat-weapon-form-dice')),
      dice,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('combat-weapon-form-tp-value')),
      tpValue,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('combat-weapon-form-bf')),
      breakFactor,
    );
    final switchFinder = find.byType(SwitchListTile);
    await tester.ensureVisible(switchFinder);
    final switchWidget = tester.widget<SwitchListTile>(switchFinder);
    if (switchWidget.value != oneHanded) {
      final switchControl = find.descendant(
        of: switchFinder,
        matching: find.byType(Switch),
      );
      await tester.tap(switchControl, warnIfMissed: false);
      await tester.pumpAndSettle();
    }
    await tester.tap(
      find.byKey(const ValueKey<String>('combat-weapon-form-save')),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openArmorEditor(WidgetTester tester, {int? index}) async {
    final key = index == null
        ? const ValueKey<String>('combat-armor-add')
        : ValueKey<String>('combat-armor-edit-$index');
    final target = find.byKey(key);
    for (var i = 0; i < 6 && target.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    expect(target, findsOneWidget);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    if (index == null) {
      await tester.tap(target);
    } else {
      await tester.tap(target);
    }
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('combat-armor-form-name')),
      findsOneWidget,
    );
  }

  Future<void> fillArmorDialog(
    WidgetTester tester, {
    required String name,
    required String rs,
    required String be,
    required bool isActive,
    required bool rg1Active,
  }) async {
    await tester.enterText(
      find.byKey(const ValueKey<String>('combat-armor-form-name')),
      name,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('combat-armor-form-rs')),
      rs,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('combat-armor-form-be')),
      be,
    );

    Future<void> setSwitch(String key, bool value) async {
      final tile = find.byKey(ValueKey<String>(key));
      final tileWidget = tester.widget<SwitchListTile>(tile);
      if (tileWidget.value == value) {
        return;
      }
      await tester.tap(tile, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    await setSwitch('combat-armor-form-active', isActive);
    await setSwitch('combat-armor-form-rg1', rg1Active);

    await tester.tap(find.byKey(const ValueKey<String>('combat-armor-form-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('shows combat submenu tabs', (tester) async {
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

    await openCombatTab(tester, repo);

    expect(find.widgetWithText(Tab, 'Kampftechniken'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Nahkampf'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'SF/Manoever'), findsOneWidget);
  });

  testWidgets('shared save persists changes from melee and sf subtabs', (
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

    await tester.tap(find.widgetWithText(Tab, 'Nahkampf'));
    await tester.pumpAndSettle();
    await openWeaponEditor(tester);
    await fillWeaponDialog(
      tester,
      name: 'Kurzschwert',
      weaponType: 'Kurzschwert',
      atMod: '2',
      paMod: '1',
      tpValue: '2',
    );

    await tester.tap(find.widgetWithText(Tab, 'SF/Manoever'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kampfreflexe'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Finte'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finte'));
    await tester.pumpAndSettle();

    await actions.save();
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.combatConfig.mainWeapon.name, 'Kurzschwert');
    expect(hero.combatConfig.mainWeapon.weaponType, 'Kurzschwert');
    expect(hero.combatConfig.mainWeapon.talentId, 'tal_nah');
    expect(hero.combatConfig.mainWeapon.wmAt, 2);
    expect(hero.combatConfig.specialRules.kampfreflexe, isTrue);
    expect(hero.combatConfig.specialRules.activeManeuvers, contains('Finte'));
  });

  testWidgets('cancel discards draft across combat subtabs', (tester) async {
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

    await tester.tap(find.widgetWithText(Tab, 'Nahkampf'));
    await tester.pumpAndSettle();
    await openWeaponEditor(tester);
    await fillWeaponDialog(
      tester,
      name: 'Testwaffe',
      weaponType: 'Kurzschwert',
      tpValue: '3',
    );

    await tester.tap(find.widgetWithText(Tab, 'SF/Manoever'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kampfreflexe'));
    await tester.pumpAndSettle();

    await actions.cancel();
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.combatConfig.mainWeapon.name, isEmpty);
    expect(hero.combatConfig.mainWeapon.weaponType, isEmpty);
    expect(hero.combatConfig.specialRules.kampfreflexe, isFalse);
  });

  testWidgets('supports multiple weapon slots with one-handed flag', (
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

    await tester.tap(find.widgetWithText(Tab, 'Nahkampf'));
    await tester.pumpAndSettle();

    await openWeaponEditor(tester, add: true);
    await fillWeaponDialog(
      tester,
      name: 'Bidenhaender',
      weaponType: 'Bidenhaender',
      atMod: '3',
      oneHanded: false,
    );

    await actions.save();
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.combatConfig.weaponSlots.length, 2);
    expect(hero.combatConfig.selectedWeaponIndex, 1);
    expect(hero.combatConfig.mainWeapon.name, 'Bidenhaender');
    expect(hero.combatConfig.mainWeapon.weaponType, 'Bidenhaender');
    expect(hero.combatConfig.mainWeapon.wmAt, 3);
    expect(hero.combatConfig.selectedWeapon.isOneHanded, isFalse);
  });

  testWidgets('shows maneuver support status per active weapon', (
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

    await tester.tap(find.widgetWithText(Tab, 'Nahkampf'));
    await tester.pumpAndSettle();

    await openWeaponEditor(tester);
    await fillWeaponDialog(
      tester,
      name: 'Kurzschwert',
      weaponType: 'Kurzschwert',
    );

    await openWeaponEditor(tester, add: true);
    await fillWeaponDialog(
      tester,
      name: 'Bidenhaender',
      weaponType: 'Bidenhaender',
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('combat-main-weapon-select-1-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kurzschwert').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'SF/Manoever'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Finte'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    final finteTile = find.ancestor(
      of: find.text('Finte'),
      matching: find.byType(SwitchListTile),
    );
    expect(
      find.descendant(
        of: finteTile,
        matching: find.text('Von aktiver Waffe unterstuetzt'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(Tab, 'Nahkampf'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('combat-main-weapon-select-0-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bidenhaender').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'SF/Manoever'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Finte'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: finteTile, matching: find.text('Nicht unterstuetzt')),
      findsOneWidget,
    );
  });

  testWidgets('armor pieces can be added, edited and removed with live preview', (
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

    await tester.tap(find.widgetWithText(Tab, 'Nahkampf'));
    await tester.pumpAndSettle();

    await openArmorEditor(tester);
    await fillArmorDialog(
      tester,
      name: 'Kettenhemd',
      rs: '3',
      be: '4',
      isActive: true,
      rg1Active: true,
    );

    expect(find.textContaining('Kettenhemd'), findsOneWidget);
    expect(find.textContaining('RS 3 | BE 4 | Aktiv Ja | RG I Ja'), findsOneWidget);

    await openArmorEditor(tester, index: 0);
    await fillArmorDialog(
      tester,
      name: 'Kettenhemd',
      rs: '5',
      be: '6',
      isActive: true,
      rg1Active: true,
    );
    expect(find.textContaining('RS 5 | BE 6 | Aktiv Ja | RG I Ja'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -280));
    await tester.pumpAndSettle();
    final removeButton = find.byKey(const ValueKey<String>('combat-armor-remove-0'));
    await tester.ensureVisible(removeButton);
    await tester.pumpAndSettle();
    await tester.tap(removeButton);
    await tester.pumpAndSettle();
    expect(find.text('Keine Ruestungsstuecke erfasst.'), findsOneWidget);
  });
}
