import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

void main() {
  HeroSheet buildHero({
    List<String> hiddenTalentIds = const <String>[],
    CombatConfig combatConfig = const CombatConfig(),
    Map<String, HeroTalentEntry> talents = const <String, HeroTalentEntry>{},
  }) {
    return HeroSheet(
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
      talents: talents,
      combatConfig: combatConfig,
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
          name: 'Schwerter',
          group: 'Kampftalent',
          type: 'Nahkampf',
          weaponCategory: 'Schwert',
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

  Future<void> openWeaponsTab(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(Tab, 'Waffen'));
    await tester.pumpAndSettle();
  }

  Future<void> selectDropdownByKey(
    WidgetTester tester, {
    required String keyName,
    required String valueText,
  }) async {
    final dropdown = find.byKey(ValueKey<String>(keyName));
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(valueText).last);
    await tester.pumpAndSettle();
  }

  Future<void> commitTextFieldByKey(
    WidgetTester tester, {
    required String keyName,
    required String value,
  }) async {
    final field = find.byKey(ValueKey<String>(keyName));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> fillWeaponRow(
    WidgetTester tester, {
    required int rowIndex,
    required String weaponType,
    String talent = 'Schwerter',
    String? dk,
    String? atMod,
    String? paMod,
    String? tpValue,
    String? breakFactor,
  }) async {
    await selectDropdownByKey(
      tester,
      keyName: 'combat-weapon-cell-talent-$rowIndex',
      valueText: talent,
    );
    await selectDropdownByKey(
      tester,
      keyName: 'combat-weapon-cell-weapon-type-$rowIndex',
      valueText: weaponType,
    );
    if (dk != null) {
      await commitTextFieldByKey(
        tester,
        keyName: 'combat-weapon-cell-dk-$rowIndex',
        value: dk,
      );
    }
    if (atMod != null) {
      await commitTextFieldByKey(
        tester,
        keyName: 'combat-weapon-cell-wm-at-$rowIndex',
        value: atMod,
      );
    }
    if (paMod != null) {
      await commitTextFieldByKey(
        tester,
        keyName: 'combat-weapon-cell-wm-pa-$rowIndex',
        value: paMod,
      );
    }
    if (tpValue != null) {
      await commitTextFieldByKey(
        tester,
        keyName: 'combat-weapon-cell-tp-value-$rowIndex',
        value: tpValue,
      );
    }
    if (breakFactor != null) {
      await commitTextFieldByKey(
        tester,
        keyName: 'combat-weapon-cell-bf-$rowIndex',
        value: breakFactor,
      );
    }
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

    await tester.tap(
      find.byKey(const ValueKey<String>('combat-armor-form-save')),
    );
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
    expect(find.widgetWithText(Tab, 'Waffen'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Nahkampf'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Sonderfertigkeiten'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Manoever'), findsOneWidget);
  });

  testWidgets(
    'special rules tab renames Linkhand and removes Axxeleratus toggle',
    (tester) async {
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
      await tester.tap(find.widgetWithText(Tab, 'Sonderfertigkeiten'));
      await tester.pumpAndSettle();

      expect(find.text('Linkhand'), findsOneWidget);
      expect(find.text('Linkhand aktiv'), findsNothing);
      expect(find.text('Axxeleratus aktiv'), findsNothing);

      final linkhandTopLeft = tester.getTopLeft(find.text('Linkhand'));
      final schildkampfTopLeft = tester.getTopLeft(find.text('Schildkampf I'));
      expect(linkhandTopLeft.dy, lessThan(schildkampfTopLeft.dy));
    },
  );

  testWidgets(
    'combat techniques table shows specialization column and edit mode control',
    (tester) async {
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

      expect(find.text('Spezialisierung'), findsAtLeastNWidgets(1));
      expect(
        find.byKey(const ValueKey<String>('talents-combat-spec-tal_nah')),
        findsNothing,
      );

      await actions.startEdit();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('talents-combat-spec-tal_nah')),
        findsOneWidget,
      );
    },
  );

  testWidgets('combat techniques save multiple specializations in edit mode', (
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

    final specButton = find.byKey(
      const ValueKey<String>('talents-combat-spec-tal_nah'),
    );
    await tester.ensureVisible(specButton);
    await tester.tap(specButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Schwert'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uebernehmen'));
    await tester.pumpAndSettle();

    await actions.save();
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    final entry = hero.talents['tal_nah'];
    expect(entry, isNotNull);
    expect(entry!.combatSpecializations, const <String>['Schwert']);
    expect(entry.specializations, 'Schwert');
  });

  testWidgets('weapon table specialization uses strict normalized matching', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{
            'tal_nah': HeroTalentEntry(
              combatSpecializations: <String>['Schwert'],
              specializations: 'Schwert',
            ),
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

    await openCombatTab(tester, repo);
    await openWeaponsTab(tester);

    await fillWeaponRow(tester, rowIndex: 0, weaponType: 'Kurzschwert');
    expect(find.text('Nein'), findsWidgets);

    await fillWeaponRow(tester, rowIndex: 0, weaponType: 'Schwert');
    expect(find.text('Ja'), findsWidgets);
  });

  testWidgets('keeps weapon management only in Waffen subtab', (tester) async {
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

    await tester.tap(find.widgetWithText(Tab, 'Nahkampf'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('combat-weapon-add')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('combat-weapons-overview-table')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('combat-weapon-remove-0')),
      findsNothing,
    );

    await tester.tap(find.widgetWithText(Tab, 'Waffen'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('combat-weapon-add')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('combat-weapons-overview-table')),
      findsOneWidget,
    );
  });

  testWidgets(
    'hides fully hidden combat technique groups outside visibility mode',
    (tester) async {
      final repo = FakeRepository(
        heroes: [
          buildHero(hiddenTalentIds: const <String>['tal_nah']),
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

      await openCombatTab(tester, repo);

      expect(find.widgetWithText(ExpansionTile, 'Fernkampf'), findsOneWidget);
      expect(find.widgetWithText(ExpansionTile, 'Nahkampf'), findsNothing);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('combat-talents-visibility-mode-toggle'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ExpansionTile, 'Nahkampf'), findsOneWidget);
    },
  );

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

    await openWeaponsTab(tester);
    await fillWeaponRow(
      tester,
      rowIndex: 0,
      weaponType: 'Kurzschwert',
      atMod: '2',
      paMod: '1',
      tpValue: '2',
    );

    await tester.tap(find.widgetWithText(Tab, 'Sonderfertigkeiten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kampfreflexe'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Aufmerksamkeit'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Aufmerksamkeit'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Manoever'));
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
    expect(hero.combatConfig.specialRules.aufmerksamkeit, isTrue);
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

    await openWeaponsTab(tester);
    await fillWeaponRow(
      tester,
      rowIndex: 0,
      weaponType: 'Kurzschwert',
      tpValue: '3',
    );

    await tester.tap(find.widgetWithText(Tab, 'Sonderfertigkeiten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kampfreflexe'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Aufmerksamkeit'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Aufmerksamkeit'));
    await tester.pumpAndSettle();

    await actions.cancel();
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.combatConfig.mainWeapon.name, isEmpty);
    expect(hero.combatConfig.mainWeapon.weaponType, isEmpty);
    expect(hero.combatConfig.specialRules.kampfreflexe, isFalse);
    expect(hero.combatConfig.specialRules.aufmerksamkeit, isFalse);
  });

  testWidgets('supports multiple weapon slots in read mode with auto-save', (
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

    await openCombatTab(tester, repo);

    await openWeaponsTab(tester);
    await tester.tap(find.byKey(const ValueKey<String>('combat-weapon-add')));
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.combatConfig.weaponSlots.length, 2);
    expect(hero.combatConfig.weaponSlots[1].tpDiceCount, 1);
  });

  testWidgets('removing selected weapon sets active selection to none', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          combatConfig: const CombatConfig(
            weapons: <MainWeaponSlot>[
              MainWeaponSlot(
                name: 'Kurzschwert',
                talentId: 'tal_nah',
                weaponType: 'Kurzschwert',
              ),
              MainWeaponSlot(
                name: 'Bidenhaender',
                talentId: 'tal_nah',
                weaponType: 'Bidenhaender',
              ),
            ],
            selectedWeaponIndex: 1,
          ),
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

    await openCombatTab(tester, repo);
    await openWeaponsTab(tester);
    final removeButton = find.byKey(
      const ValueKey<String>('combat-weapon-remove-1'),
    );
    await tester.ensureVisible(removeButton);
    await tester.pumpAndSettle();
    await tester.tap(removeButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.combatConfig.weaponSlots.length, 1);
    expect(hero.combatConfig.selectedWeaponIndex, -1);
  });

  testWidgets('shows maneuver support status per active weapon', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          combatConfig: const CombatConfig(
            weapons: <MainWeaponSlot>[
              MainWeaponSlot(
                name: 'Kurzschwert',
                talentId: 'tal_nah',
                weaponType: 'Kurzschwert',
              ),
              MainWeaponSlot(
                name: 'Bidenhaender',
                talentId: 'tal_nah',
                weaponType: 'Bidenhaender',
              ),
            ],
            selectedWeaponIndex: 0,
          ),
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

    await openCombatTab(tester, repo);

    await tester.tap(find.widgetWithText(Tab, 'Nahkampf'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('combat-main-weapon-select-0-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kurzschwert').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Manoever'));
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

    await tester.tap(find.widgetWithText(Tab, 'Manoever'));
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

  testWidgets('weapon type sets default name for a new row in read mode', (
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

    await openCombatTab(tester, repo);
    await openWeaponsTab(tester);
    await fillWeaponRow(tester, rowIndex: 0, weaponType: 'Kurzschwert');

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.combatConfig.weaponSlots[0].name, 'Kurzschwert');
    expect(hero.combatConfig.weaponSlots[0].tpDiceCount, 1);
  });

  testWidgets('active weapon selection persists in read mode', (tester) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          combatConfig: const CombatConfig(
            weapons: <MainWeaponSlot>[
              MainWeaponSlot(
                name: 'Kurzschwert',
                talentId: 'tal_nah',
                weaponType: 'Kurzschwert',
              ),
              MainWeaponSlot(
                name: 'Bidenhaender',
                talentId: 'tal_nah',
                weaponType: 'Bidenhaender',
              ),
            ],
            selectedWeaponIndex: 0,
          ),
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

    await openCombatTab(tester, repo);
    await tester.tap(find.widgetWithText(Tab, 'Nahkampf'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('combat-main-weapon-select-0-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bidenhaender').last);
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.combatConfig.selectedWeaponIndex, 1);
    expect(hero.combatConfig.mainWeapon.name, 'Bidenhaender');
  });

  testWidgets('active weapon can be set to none and back', (tester) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          combatConfig: const CombatConfig(
            weapons: <MainWeaponSlot>[
              MainWeaponSlot(
                name: 'Kurzschwert',
                talentId: 'tal_nah',
                weaponType: 'Kurzschwert',
              ),
              MainWeaponSlot(
                name: 'Bidenhaender',
                talentId: 'tal_nah',
                weaponType: 'Bidenhaender',
              ),
            ],
            selectedWeaponIndex: 1,
          ),
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

    await openCombatTab(tester, repo);
    await tester.tap(find.widgetWithText(Tab, 'Nahkampf'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('combat-main-weapon-select-1-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keine Waffe').last);
    await tester.pumpAndSettle();

    var heroes = await repo.listHeroes();
    var hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.combatConfig.selectedWeaponIndex, -1);

    await tester.tap(
      find.byKey(const ValueKey<String>('combat-main-weapon-select-none-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kurzschwert').last);
    await tester.pumpAndSettle();

    heroes = await repo.listHeroes();
    hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.combatConfig.selectedWeaponIndex, 0);
    expect(hero.combatConfig.mainWeapon.name, 'Kurzschwert');
  });

  testWidgets(
    'melee info panel shows active weapon stats and supported active maneuvers',
    (tester) async {
      final repo = FakeRepository(
        heroes: [
          buildHero(
            combatConfig: const CombatConfig(
              weapons: <MainWeaponSlot>[
                MainWeaponSlot(
                  name: 'Kurzschwert',
                  talentId: 'tal_nah',
                  weaponType: 'Kurzschwert',
                ),
                MainWeaponSlot(
                  name: 'Bidenhaender',
                  talentId: 'tal_nah',
                  weaponType: 'Bidenhaender',
                  wmAt: 3,
                  wmPa: 2,
                  iniMod: 4,
                  tpFlat: 5,
                ),
              ],
              selectedWeaponIndex: 0,
              specialRules: CombatSpecialRules(
                activeManeuvers: <String>['Finte', 'Wuchtschlag'],
              ),
            ),
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

      await openCombatTab(tester, repo);
      await tester.tap(find.widgetWithText(Tab, 'Nahkampf'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('combat-active-weapon-info-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('combat-active-weapon-info-at')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('combat-active-weapon-info-pa')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('combat-active-weapon-info-tp')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('combat-active-weapon-info-ini')),
        findsOneWidget,
      );

      final atBefore =
          (tester
                      .widget<Chip>(
                        find.byKey(
                          const ValueKey<String>(
                            'combat-active-weapon-info-at',
                          ),
                        ),
                      )
                      .label
                  as Text)
              .data;
      final paBefore =
          (tester
                      .widget<Chip>(
                        find.byKey(
                          const ValueKey<String>(
                            'combat-active-weapon-info-pa',
                          ),
                        ),
                      )
                      .label
                  as Text)
              .data;
      final tpBefore =
          (tester
                      .widget<Chip>(
                        find.byKey(
                          const ValueKey<String>(
                            'combat-active-weapon-info-tp',
                          ),
                        ),
                      )
                      .label
                  as Text)
              .data;
      final iniBefore =
          (tester
                      .widget<Chip>(
                        find.byKey(
                          const ValueKey<String>(
                            'combat-active-weapon-info-ini',
                          ),
                        ),
                      )
                      .label
                  as Text)
              .data;

      final maneuversFinder = find.byKey(
        const ValueKey<String>('combat-active-weapon-info-maneuvers'),
      );
      expect(
        find.descendant(of: maneuversFinder, matching: find.text('Finte')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: maneuversFinder,
          matching: find.text('Wuchtschlag'),
        ),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('combat-main-weapon-select-0-2')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bidenhaender').last);
      await tester.pumpAndSettle();

      final atAfter =
          (tester
                      .widget<Chip>(
                        find.byKey(
                          const ValueKey<String>(
                            'combat-active-weapon-info-at',
                          ),
                        ),
                      )
                      .label
                  as Text)
              .data;
      final paAfter =
          (tester
                      .widget<Chip>(
                        find.byKey(
                          const ValueKey<String>(
                            'combat-active-weapon-info-pa',
                          ),
                        ),
                      )
                      .label
                  as Text)
              .data;
      final tpAfter =
          (tester
                      .widget<Chip>(
                        find.byKey(
                          const ValueKey<String>(
                            'combat-active-weapon-info-tp',
                          ),
                        ),
                      )
                      .label
                  as Text)
              .data;
      final iniAfter =
          (tester
                      .widget<Chip>(
                        find.byKey(
                          const ValueKey<String>(
                            'combat-active-weapon-info-ini',
                          ),
                        ),
                      )
                      .label
                  as Text)
              .data;

      expect(iniBefore, contains('Kampf INI:'));
      expect(atAfter, isNot(equals(atBefore)));
      expect(paAfter, isNot(equals(paBefore)));
      expect(tpAfter, isNot(equals(tpBefore)));
      expect(iniAfter, isNot(equals(iniBefore)));
      expect(iniAfter, contains('Kampf INI:'));

      expect(
        find.descendant(of: maneuversFinder, matching: find.text('Finte')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: maneuversFinder,
          matching: find.text('Wuchtschlag'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('active weapon INI shows helden/kampf split and roll behavior', (
    tester,
  ) async {
    Future<({String? heldenIni, String? heldenWaffenIni, String? kampfIni})>
    pumpAndReadIni({
      required bool klingentaenzer,
      required bool aufmerksamkeit,
    }) async {
      final repo = FakeRepository(
        heroes: [
          buildHero(
            combatConfig: CombatConfig(
              weapons: const <MainWeaponSlot>[
                MainWeaponSlot(
                  name: 'Kurzschwert',
                  talentId: 'tal_nah',
                  weaponType: 'Kurzschwert',
                ),
              ],
              selectedWeaponIndex: 0,
              specialRules: CombatSpecialRules(
                klingentaenzer: klingentaenzer,
                aufmerksamkeit: aufmerksamkeit,
              ),
            ),
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
                onRegisterEditActions: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Nahkampf'));
      await tester.pumpAndSettle();
      final heldenIni =
          (tester
                      .widget<Chip>(
                        find.byKey(
                          const ValueKey<String>(
                            'combat-active-weapon-info-helden-ini',
                          ),
                        ),
                      )
                      .label
                  as Text)
              .data;
      final kampfIni =
          (tester
                      .widget<Chip>(
                        find.byKey(
                          const ValueKey<String>(
                            'combat-active-weapon-info-ini',
                          ),
                        ),
                      )
                      .label
                  as Text)
              .data;
      final heldenWaffenIni =
          (tester
                      .widget<Chip>(
                        find.byKey(
                          const ValueKey<String>(
                            'combat-active-weapon-info-helden-waffen-ini',
                          ),
                        ),
                      )
                      .label
                  as Text)
              .data;
      return (
        heldenIni: heldenIni,
        heldenWaffenIni: heldenWaffenIni,
        kampfIni: kampfIni,
      );
    }

    final noSf = await pumpAndReadIni(
      klingentaenzer: false,
      aufmerksamkeit: false,
    );
    expect(noSf.heldenIni, contains('Helden INI:'));
    expect(noSf.heldenWaffenIni, contains('Helden+Waffen INI:'));
    expect(noSf.heldenIni, contains(' + 0 = '));
    expect(noSf.kampfIni, contains('Kampf INI:'));

    final klingentaenzerOnly = await pumpAndReadIni(
      klingentaenzer: true,
      aufmerksamkeit: false,
    );
    expect(klingentaenzerOnly.heldenIni, contains(' + 0 = '));
    expect(klingentaenzerOnly.heldenWaffenIni, contains('Helden+Waffen INI:'));
    expect(klingentaenzerOnly.kampfIni, contains('Kampf INI:'));

    final aufmerksamkeitOnly = await pumpAndReadIni(
      klingentaenzer: false,
      aufmerksamkeit: true,
    );
    expect(aufmerksamkeitOnly.heldenIni, contains(' + 1W6 = '));
    expect(aufmerksamkeitOnly.heldenWaffenIni, contains('Helden+Waffen INI:'));

    final both = await pumpAndReadIni(
      klingentaenzer: true,
      aufmerksamkeit: true,
    );
    expect(both.heldenIni, contains(' + 2W6 = '));
    expect(both.heldenWaffenIni, contains('Helden+Waffen INI:'));
    expect(both.kampfIni, contains('Kampf INI:'));
  });

  testWidgets(
    'temporary ini roll input clamps and updates ini parade mod without persistence',
    (tester) async {
      final repo = FakeRepository(
        heroes: [
          buildHero(
            combatConfig: const CombatConfig(
              weapons: <MainWeaponSlot>[
                MainWeaponSlot(
                  name: 'Kurzschwert',
                  talentId: 'tal_nah',
                  weaponType: 'Kurzschwert',
                ),
              ],
              selectedWeaponIndex: 0,
              specialRules: CombatSpecialRules(klingentaenzer: true),
            ),
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

      await openCombatTab(tester, repo);
      await tester.tap(find.widgetWithText(Tab, 'Nahkampf'));
      await tester.pumpAndSettle();

      final iniBefore =
          (tester
                      .widget<Chip>(
                        find.byKey(
                          const ValueKey<String>(
                            'combat-active-weapon-info-ini',
                          ),
                        ),
                      )
                      .label
                  as Text)
              .data;

      await tester.enterText(
        find.byKey(
          const ValueKey<String>('combat-active-weapon-info-ini-roll'),
        ),
        '13',
      );
      await tester.pumpAndSettle();

      final rollController = tester.widget<TextField>(
        find.byKey(
          const ValueKey<String>('combat-active-weapon-info-ini-roll'),
        ),
      );
      expect(rollController.controller?.text, '12');
      final iniAfter =
          (tester
                      .widget<Chip>(
                        find.byKey(
                          const ValueKey<String>(
                            'combat-active-weapon-info-ini',
                          ),
                        ),
                      )
                      .label
                  as Text)
              .data;
      expect(iniAfter, isNot(equals(iniBefore)));

      final heroes = await repo.listHeroes();
      final hero = heroes.firstWhere((entry) => entry.id == 'demo');
      expect(hero.combatConfig.manualMods.iniWurf, 0);
    },
  );

  testWidgets('aufmerksamkeit disables ini roll input and uses max roll', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          combatConfig: const CombatConfig(
            weapons: <MainWeaponSlot>[
              MainWeaponSlot(
                name: 'Kurzschwert',
                talentId: 'tal_nah',
                weaponType: 'Kurzschwert',
              ),
            ],
            selectedWeaponIndex: 0,
            specialRules: CombatSpecialRules(
              aufmerksamkeit: true,
              klingentaenzer: true,
            ),
          ),
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

    await openCombatTab(tester, repo);
    await tester.tap(find.widgetWithText(Tab, 'Nahkampf'));
    await tester.pumpAndSettle();

    final rollField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('combat-active-weapon-info-ini-roll')),
    );
    expect(rollField.readOnly, isTrue);
    expect(rollField.controller?.text, '12');
    expect(
      find.textContaining('Aufmerksamkeit aktiv: automatisch 12'),
      findsOneWidget,
    );
  });

  testWidgets('melee info panel shows empty state when no weapon is selected', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          combatConfig: const CombatConfig(
            weapons: <MainWeaponSlot>[
              MainWeaponSlot(
                name: 'Kurzschwert',
                talentId: 'tal_nah',
                weaponType: 'Kurzschwert',
              ),
              MainWeaponSlot(
                name: 'Bidenhaender',
                talentId: 'tal_nah',
                weaponType: 'Bidenhaender',
              ),
            ],
            selectedWeaponIndex: -1,
          ),
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

    await openCombatTab(tester, repo);
    await tester.tap(find.widgetWithText(Tab, 'Nahkampf'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('combat-active-weapon-info-card')),
      findsOneWidget,
    );
    expect(find.text('Keine aktive Waffe ausgewaehlt.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('combat-active-weapon-info-at')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('combat-active-weapon-info-maneuvers')),
      findsNothing,
    );
  });

  testWidgets('offhand values persist in read mode', (tester) async {
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
    await tester.tap(find.widgetWithText(Tab, 'Nahkampf'));
    await tester.pumpAndSettle();
    final offhandMode = find.byKey(
      const ValueKey<String>('combat-offhand-mode'),
    );
    await tester.ensureVisible(offhandMode);
    await tester.pumpAndSettle();
    await tester.tap(offhandMode);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schild').last);
    await tester.pumpAndSettle();
    final offhandAtMod = find.byKey(
      const ValueKey<String>('combat-offhand-at-mod'),
    );
    await tester.ensureVisible(offhandAtMod);
    await tester.pumpAndSettle();
    await tester.enterText(offhandAtMod, '2');
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.combatConfig.offhand.mode, OffhandMode.shield);
    expect(hero.combatConfig.offhand.atMod, 2);
  });

  testWidgets('weapon overview table lists active weapon first', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          combatConfig: const CombatConfig(
            weapons: <MainWeaponSlot>[
              MainWeaponSlot(
                name: 'Kurzschwert',
                talentId: 'tal_nah',
                weaponType: 'Kurzschwert',
                tpFlat: 2,
              ),
              MainWeaponSlot(
                name: 'Bidenhaender',
                talentId: 'tal_nah',
                weaponType: 'Bidenhaender',
                tpFlat: 3,
              ),
            ],
            selectedWeaponIndex: 1,
          ),
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

    await openCombatTab(tester, repo);
    await tester.tap(find.widgetWithText(Tab, 'Waffen'));
    await tester.pumpAndSettle();

    final table = find.byKey(
      const ValueKey<String>('combat-weapons-overview-table'),
    );
    for (var i = 0; i < 8 && table.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    expect(table, findsOneWidget);
    expect(
      find.descendant(of: table, matching: find.text('Waffentalent')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: table, matching: find.text('TP Kalk')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: table, matching: find.textContaining('1W6')),
      findsWidgets,
    );
    final dkHeader = find
        .descendant(of: table, matching: find.text('DK'))
        .first;
    final atHeader = find
        .descendant(of: table, matching: find.text('AT'))
        .first;
    final paHeader = find
        .descendant(of: table, matching: find.text('PA'))
        .first;
    final tpHeader = find
        .descendant(of: table, matching: find.text('TP'))
        .first;
    final iniHeader = find
        .descendant(of: table, matching: find.text('Helden+Waffen INI'))
        .first;
    final bfHeader = find
        .descendant(of: table, matching: find.text('BF'))
        .first;
    expect(
      tester.getTopLeft(atHeader).dx,
      greaterThan(tester.getTopLeft(dkHeader).dx),
    );
    expect(
      tester.getTopLeft(paHeader).dx,
      greaterThan(tester.getTopLeft(atHeader).dx),
    );
    expect(
      tester.getTopLeft(tpHeader).dx,
      greaterThan(tester.getTopLeft(paHeader).dx),
    );
    expect(
      tester.getTopLeft(iniHeader).dx,
      greaterThan(tester.getTopLeft(tpHeader).dx),
    );
    expect(
      tester.getTopLeft(bfHeader).dx,
      greaterThan(tester.getTopLeft(iniHeader).dx),
    );

    final bidenFinder = find
        .descendant(of: table, matching: find.text('Bidenhaender'))
        .first;
    final kurzFinder = find
        .descendant(of: table, matching: find.text('Kurzschwert'))
        .first;
    expect(
      tester.getTopLeft(bidenFinder).dy,
      lessThan(tester.getTopLeft(kurzFinder).dy),
    );
  });

  testWidgets(
    'weapon overview INI column reacts to INI Mod and INI/GE composition',
    (tester) async {
      final repo = FakeRepository(
        heroes: [
          buildHero(
            combatConfig: const CombatConfig(
              weapons: <MainWeaponSlot>[
                MainWeaponSlot(
                  name: 'Kurzschwert',
                  talentId: 'tal_nah',
                  weaponType: 'Kurzschwert',
                  kkBase: 10,
                  kkThreshold: 3,
                  iniMod: 0,
                ),
              ],
              selectedWeaponIndex: 0,
            ),
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

      await openCombatTab(tester, repo);
      await openWeaponsTab(tester);

      final iniBefore =
          (tester
                      .widget<Text>(
                        find.byKey(
                          const ValueKey<String>('combat-weapon-cell-ini-0'),
                        ),
                      )
                      .data ??
                  '')
              .trim();
      final iniGeText =
          (tester
                      .widget<Text>(
                        find.byKey(
                          const ValueKey<String>('combat-weapon-cell-ini-ge-0'),
                        ),
                      )
                      .data ??
                  '')
              .trim();
      expect(iniGeText, isNotEmpty);

      await commitTextFieldByKey(
        tester,
        keyName: 'combat-weapon-cell-ini-mod-0',
        value: '2',
      );

      final iniAfter =
          (tester
                      .widget<Text>(
                        find.byKey(
                          const ValueKey<String>('combat-weapon-cell-ini-0'),
                        ),
                      )
                      .data ??
                  '')
              .trim();

      expect(int.parse(iniAfter), int.parse(iniBefore) + 2);
    },
  );

  testWidgets('weapon table filters by DK in read mode', (tester) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          combatConfig: const CombatConfig(
            weapons: <MainWeaponSlot>[
              MainWeaponSlot(
                name: 'Kurzschwert',
                talentId: 'tal_nah',
                weaponType: 'Kurzschwert',
                distanceClass: 'N',
              ),
              MainWeaponSlot(
                name: 'Bidenhaender',
                talentId: 'tal_nah',
                weaponType: 'Bidenhaender',
                distanceClass: 'S',
              ),
            ],
            selectedWeaponIndex: 0,
          ),
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

    await openCombatTab(tester, repo);
    await openWeaponsTab(tester);
    await selectDropdownByKey(
      tester,
      keyName: 'combat-weapons-filter-dk',
      valueText: 'S',
    );

    expect(
      find.byKey(const ValueKey<String>('combat-weapon-cell-name-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('combat-weapon-cell-name-0')),
      findsNothing,
    );
  });

  testWidgets('armor pieces can be added, edited and removed in read mode', (
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

    await openCombatTab(tester, repo);

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
    expect(
      find.textContaining('RS 3 | BE 4 | Aktiv Ja | RG I Ja'),
      findsOneWidget,
    );

    await openArmorEditor(tester, index: 0);
    await fillArmorDialog(
      tester,
      name: 'Kettenhemd',
      rs: '5',
      be: '6',
      isActive: true,
      rg1Active: true,
    );
    expect(
      find.textContaining('RS 5 | BE 6 | Aktiv Ja | RG I Ja'),
      findsOneWidget,
    );

    final removeButton = find.byKey(
      const ValueKey<String>('combat-armor-remove-0'),
    );
    for (var i = 0; i < 6 && removeButton.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -260));
      await tester.pumpAndSettle();
    }
    expect(removeButton, findsOneWidget);
    await tester.ensureVisible(removeButton);
    await tester.pumpAndSettle();
    await tester.tap(removeButton);
    await tester.pumpAndSettle();
    expect(find.text('Keine Ruestungsstuecke erfasst.'), findsOneWidget);

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.combatConfig.armor.pieces, isEmpty);
  });
}
