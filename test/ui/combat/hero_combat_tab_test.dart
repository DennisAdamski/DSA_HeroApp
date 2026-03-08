import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

void main() {
  HeroSheet buildHero({
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
        TalentDef(
          id: 'tal_dolch',
          name: 'Dolche',
          group: 'Kampftalent',
          type: 'Nahkampf',
          weaponCategory: 'Dolch',
          steigerung: 'C',
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
        WeaponDef(
          id: 'wpn_dolch',
          name: 'Dolch',
          type: 'Nahkampf',
          combatSkill: 'Dolche',
          tp: '1W6',
          possibleManeuvers: <String>['Finte'],
        ),
        WeaponDef(
          id: 'wpn_kurzbogen',
          name: 'Kurzbogen',
          type: 'Fernkampf',
          combatSkill: 'Boegen',
          tp: '1W6+4',
          fkMod: 1,
          reloadTime: 3,
          rangedDistanceBands: <RangedDistanceBand>[
            RangedDistanceBand(label: 'Nah', tpMod: 2),
            RangedDistanceBand(label: 'Mittel', tpMod: 0),
            RangedDistanceBand(label: 'Weit', tpMod: -1),
            RangedDistanceBand(label: 'Sehr weit', tpMod: -2),
            RangedDistanceBand(label: 'Extrem', tpMod: -4),
          ],
          rangedProjectiles: <RangedProjectile>[
            RangedProjectile(
              name: 'Jagdspitze',
              count: 8,
              tpMod: 1,
              iniMod: -1,
              fkMod: 2,
              description: 'Breite Spitze fuer Wild.',
            ),
          ],
        ),
      ],
    );
  }

  Future<WorkspaceTabEditActions> openCombatTab(
    WidgetTester tester,
    FakeRepository repo, {
    bool showInlineCombatTalentsActions = true,
  }) async {
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
              showInlineCombatTalentsActions: showInlineCombatTalentsActions,
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

  Future<void> openWeaponDialogByText(
    WidgetTester tester, {
    required String text,
  }) async {
    final target = find.text(text).first;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('combat-weapon-form-save')),
      findsOneWidget,
    );
  }

  Future<void> openAddWeaponDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey<String>('combat-weapon-add')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('combat-weapon-form-save')),
      findsOneWidget,
    );
  }

  Future<void> saveWeaponDialog(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey<String>('combat-weapon-form-save')),
    );
    await tester.pumpAndSettle();
  }

  Future<void> cancelWeaponDialog(WidgetTester tester) async {
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
  }

  Future<void> setSwitchByKey(
    WidgetTester tester, {
    required String keyName,
    required bool value,
  }) async {
    final tile = find.byKey(ValueKey<String>(keyName));
    expect(tile, findsOneWidget);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    final tileWidget = tester.widget<SwitchListTile>(tile);
    if (tileWidget.value == value) {
      return;
    }
    await tester.tap(tile, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Future<void> fillWeaponDialog(
    WidgetTester tester, {
    String? name,
    String? talent,
    String? weaponType,
    String? dk,
    String? breakFactor,
    String? kkBase,
    String? kkThreshold,
    String? iniMod,
    String? wmAt,
    String? wmPa,
    String? tpDiceCount,
    String? tpFlat,
    bool? oneHanded,
    bool? artifact,
    String? artifactDescription,
  }) async {
    if (name != null) {
      await tester.enterText(
        find.byKey(const ValueKey<String>('combat-weapon-form-name')),
        name,
      );
      await tester.pumpAndSettle();
    }
    if (weaponType != null) {
      await selectDropdownByKey(
        tester,
        keyName: 'combat-weapon-form-weapon-type',
        valueText: weaponType,
      );
    }
    if (talent != null) {
      await selectDropdownByKey(
        tester,
        keyName: 'combat-weapon-form-talent',
        valueText: talent,
      );
    }
    if (dk != null) {
      await tester.enterText(
        find.byKey(const ValueKey<String>('combat-weapon-form-dk')),
        dk,
      );
      await tester.pumpAndSettle();
    }
    final fieldValues = <String, String>{
      'combat-weapon-form-bf': breakFactor ?? '',
      'combat-weapon-form-kk-base': kkBase ?? '',
      'combat-weapon-form-kk-threshold': kkThreshold ?? '',
      'combat-weapon-form-ini-mod': iniMod ?? '',
      'combat-weapon-form-wm-at': wmAt ?? '',
      'combat-weapon-form-wm-pa': wmPa ?? '',
      'combat-weapon-form-dice-count': tpDiceCount ?? '',
      'combat-weapon-form-tp-flat': tpFlat ?? '',
    };
    for (final entry in fieldValues.entries) {
      if (entry.value.isEmpty) {
        continue;
      }
      await tester.enterText(
        find.byKey(ValueKey<String>(entry.key)),
        entry.value,
      );
      await tester.pumpAndSettle();
    }
    if (oneHanded != null) {
      await setSwitchByKey(
        tester,
        keyName: 'combat-weapon-form-one-handed',
        value: oneHanded,
      );
    }
    if (artifact != null) {
      await setSwitchByKey(
        tester,
        keyName: 'combat-weapon-form-artifact',
        value: artifact,
      );
    }
    if (artifactDescription != null) {
      final field = find.byKey(
        const ValueKey<String>('combat-weapon-form-artifact-description'),
      );
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, artifactDescription);
      await tester.pumpAndSettle();
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
      if (tile.evaluate().isEmpty) {
        return;
      }
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
    expect(find.widgetWithText(Tab, 'Kampf'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Sonderfertigkeiten'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Manoever'), findsOneWidget);
  });

  testWidgets('legacy Axxeleratus state still shows melee hint in combat tab', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          combatConfig: const CombatConfig(
            specialRules: CombatSpecialRules(axxeleratusActive: true),
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
    await tester.tap(find.widgetWithText(Tab, 'Kampf'));
    await tester.pumpAndSettle();
    final axxHintFinder = find.text(
      'Abwehr des beschleunigten Nahkampfangriffs: Automatische Finte +2',
    );
    for (var i = 0; i < 6 && axxHintFinder.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();

    expect(axxHintFinder, findsOneWidget);
  });

  testWidgets(
    'combat techniques table shows specialization column and edit mode control',
    (tester) async {
      final repo = FakeRepository(
        heroes: [
          buildHero(
            talents: const <String, HeroTalentEntry>{
              'tal_nah': HeroTalentEntry(),
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

      final actions = await openCombatTab(tester, repo);

      expect(find.text('Spezialisierung'), findsAtLeastNWidgets(1));
      expect(
        find.byKey(const ValueKey<String>('combat-spec-add-tal_nah')),
        findsNothing,
      );

      await actions.startEdit();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('combat-spec-add-tal_nah')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'combat techniques in workspace mode expose catalog management in edit mode',
    (tester) async {
      final repo = FakeRepository(
        heroes: [
          buildHero(
            talents: const <String, HeroTalentEntry>{
              'tal_nah': HeroTalentEntry(),
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

      final actions = await openCombatTab(
        tester,
        repo,
        showInlineCombatTalentsActions: false,
      );

      expect(
        find.byKey(const ValueKey<String>('combat-talents-start-edit')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('combat-talents-catalog-open')),
        findsNothing,
      );

      await actions.startEdit();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('combat-talents-start-edit')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('combat-talents-catalog-open')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('combat-talents-catalog-open')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kampftalent-Katalog'), findsOneWidget);
      expect(find.text('Schwerter'), findsAtLeastNWidgets(1));
      expect(find.text('Boegen'), findsAtLeastNWidgets(1));
    },
  );

  testWidgets('combat techniques save multiple specializations in edit mode', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{
            'tal_nah': HeroTalentEntry(),
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

    final actions = await openCombatTab(tester, repo);
    await actions.startEdit();
    await tester.pumpAndSettle();

    final specButton = find.byKey(
      const ValueKey<String>('combat-spec-add-tal_nah'),
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

  testWidgets('weapon table shows reduced columns', (tester) async {
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

    expect(find.text('Artefakt'), findsOneWidget);
    expect(find.text('Artefaktbeschreibung'), findsOneWidget);
    expect(find.text('INI'), findsAtLeastNWidgets(1));
    expect(find.text('KK-Basis'), findsNothing);
    expect(find.text('WM AT'), findsNothing);
    expect(find.text('Spezialisierung'), findsNothing);
  });

  testWidgets('clicking weapon name opens editable weapon dialog', (
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
                distanceClass: 'N',
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
    await openWeaponDialogByText(tester, text: 'Kurzschwert');

    expect(find.text('Stammdaten'), findsOneWidget);
    expect(find.text('Waffenwerte'), findsOneWidget);
    expect(find.text('Errechnete Werte'), findsOneWidget);
    expect(find.text('Waffenmodifikatoren'), findsOneWidget);
    expect(find.text('TP-Modifikatoren'), findsOneWidget);
    expect(find.text('INI-Modifikatoren'), findsOneWidget);
  });

  testWidgets('weapon dialog saves hidden weapon fields in read mode', (
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
    await openWeaponDialogByText(tester, text: '-');
    await fillWeaponDialog(
      tester,
      talent: 'Schwerter',
      weaponType: 'Kurzschwert',
      dk: 'N',
      kkBase: '12',
      kkThreshold: '2',
      iniMod: '3',
      wmAt: '2',
      wmPa: '1',
      tpDiceCount: '2',
      tpFlat: '4',
    );
    await saveWeaponDialog(tester);

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    final weapon = hero.combatConfig.weaponSlots.first;
    expect(weapon.weaponType, 'Kurzschwert');
    expect(weapon.distanceClass, 'N');
    expect(weapon.kkBase, 12);
    expect(weapon.kkThreshold, 2);
    expect(weapon.iniMod, 3);
    expect(weapon.wmAt, 2);
    expect(weapon.wmPa, 1);
    expect(weapon.tpDiceCount, 2);
    expect(weapon.tpFlat, 4);
  });

  testWidgets('weapon dialog shows read-only formula fields', (tester) async {
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
    await openWeaponDialogByText(tester, text: '-');

    expect(
      find.byKey(const ValueKey<String>('combat-weapon-form-preview-tpkk')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('combat-weapon-form-preview-ge-base')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('combat-weapon-form-preview-ge-threshold'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('combat-weapon-form-preview-ini-ge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('combat-weapon-form-preview-be-mod')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('combat-weapon-form-preview-ebe')),
      findsOneWidget,
    );

    final editableHeight = tester
        .getSize(find.byKey(const ValueKey<String>('combat-weapon-form-bf')))
        .height;
    final readOnlyHeight = tester
        .getSize(
          find.ancestor(
            of: find.byKey(
              const ValueKey<String>('combat-weapon-form-preview-tpkk'),
            ),
            matching: find.byType(InputDecorator),
          ),
        )
        .height;
    expect(readOnlyHeight, closeTo(editableHeight, 1));
  });

  testWidgets('weapon type filters talent selection without auto-selecting', (
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
    await openWeaponDialogByText(tester, text: '-');
    await fillWeaponDialog(tester, weaponType: 'Dolch');

    await tester.tap(
      find.byKey(const ValueKey<String>('combat-weapon-form-talent')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dolche').last, findsOneWidget);
    expect(find.text('Schwerter'), findsNothing);
    await tester.tap(find.text('-').last);
    await tester.pumpAndSettle();

    await cancelWeaponDialog(tester);

    await openWeaponDialogByText(tester, text: '-');
    await fillWeaponDialog(tester, name: 'Testdolch', weaponType: 'Dolch');

    await saveWeaponDialog(tester);

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.combatConfig.weaponSlots.first.talentId, isEmpty);
  });

  testWidgets('add weapon dialog cancels without creating new slot', (
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
    await openAddWeaponDialog(tester);
    await cancelWeaponDialog(tester);

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.combatConfig.weaponSlots.length, 1);
    expect(hero.combatConfig.weaponSlots.first.name, isEmpty);
  });

  testWidgets('catalog flow opens editor with prefilled values', (
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
    await tester.tap(
      find.byKey(const ValueKey<String>('combat-weapon-from-catalog')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();

    await saveWeaponDialog(tester);

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    final weapon = hero.combatConfig.weaponSlots[1];
    expect(weapon.name, 'Bidenhaender');
    expect(weapon.weaponType, 'Bidenhaender');
    expect(weapon.tpDiceCount, 2);
    expect(weapon.tpFlat, 2);
  });

  testWidgets('weapon table keeps talent and BF inline editable', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          combatConfig: const CombatConfig(
            weapons: <MainWeaponSlot>[MainWeaponSlot(name: 'Kurzschwert')],
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
      keyName: 'combat-weapon-cell-talent-0',
      valueText: 'Schwerter',
    );
    await commitTextFieldByKey(
      tester,
      keyName: 'combat-weapon-cell-bf-0',
      value: '5',
    );

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    final weapon = hero.combatConfig.weaponSlots.first;
    expect(weapon.talentId, 'tal_nah');
    expect(weapon.breakFactor, 5);
  });

  testWidgets('artifact fields are shown in table and persisted', (
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
    await openWeaponDialogByText(tester, text: '-');
    await fillWeaponDialog(
      tester,
      talent: 'Schwerter',
      weaponType: 'Kurzschwert',
      artifact: true,
      artifactDescription: 'Gebundener Dschinn',
    );
    await saveWeaponDialog(tester);

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    final weapon = hero.combatConfig.weaponSlots.first;
    expect(weapon.isArtifact, isTrue);
    expect(weapon.artifactDescription, 'Gebundener Dschinn');
    expect(
      find.byKey(
        const ValueKey<String>('combat-weapon-cell-artifact-description-0'),
      ),
      findsOneWidget,
    );
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

    await tester.tap(find.widgetWithText(Tab, 'Kampf'));
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

  testWidgets('shows only combat talent groups that have active talents', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{
            'tal_fern': HeroTalentEntry(talentValue: 5),
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

    expect(find.widgetWithText(ExpansionTile, 'Fernkampf'), findsOneWidget);
    expect(find.widgetWithText(ExpansionTile, 'Nahkampf'), findsNothing);
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

    await openWeaponsTab(tester);
    await openWeaponDialogByText(tester, text: '-');
    await fillWeaponDialog(
      tester,
      talent: 'Schwerter',
      weaponType: 'Kurzschwert',
      wmAt: '2',
      wmPa: '1',
      tpFlat: '2',
    );
    await saveWeaponDialog(tester);

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
    await openWeaponDialogByText(tester, text: '-');
    await fillWeaponDialog(
      tester,
      talent: 'Schwerter',
      weaponType: 'Kurzschwert',
      tpFlat: '3',
    );
    await saveWeaponDialog(tester);

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
    await openAddWeaponDialog(tester);
    await fillWeaponDialog(
      tester,
      talent: 'Schwerter',
      weaponType: 'Kurzschwert',
    );
    await saveWeaponDialog(tester);

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

    await tester.tap(find.widgetWithText(Tab, 'Kampf'));
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

    await tester.tap(find.widgetWithText(Tab, 'Kampf'));
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
    await openWeaponDialogByText(tester, text: '-');
    await fillWeaponDialog(
      tester,
      talent: 'Schwerter',
      weaponType: 'Kurzschwert',
    );
    await saveWeaponDialog(tester);

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
    await tester.tap(find.widgetWithText(Tab, 'Kampf'));
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
    await tester.tap(find.widgetWithText(Tab, 'Kampf'));
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
      await tester.tap(find.widgetWithText(Tab, 'Kampf'));
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

  testWidgets('active weapon overview PA includes initiative parade bonus', (
    tester,
  ) async {
    final configuredHero = buildHero(
      combatConfig: const CombatConfig(
        weapons: <MainWeaponSlot>[
          MainWeaponSlot(
            name: 'Kurzschwert',
            talentId: 'tal_nah',
            weaponType: 'Kurzschwert',
            iniMod: 21,
          ),
        ],
        selectedWeaponIndex: 0,
      ),
      talents: const <String, HeroTalentEntry>{
        'tal_nah': HeroTalentEntry(paValue: 4),
      },
    );
    final repo = FakeRepository(
      heroes: [configuredHero],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );

    final expectedPreview = computeCombatPreviewStats(
      configuredHero,
      const HeroState(
        currentLep: 10,
        currentAsp: 0,
        currentKap: 0,
        currentAu: 10,
      ),
      catalogTalents: buildCatalog().talents,
    );

    await openCombatTab(tester, repo);
    await tester.tap(find.widgetWithText(Tab, 'Kampf'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(Chip, 'PA: ${expectedPreview.paMitIniParadeMod}'),
      findsOneWidget,
    );
    expect(find.text('Ini Parade Mod'), findsNothing);
  });

  testWidgets(
    'active weapon info panel shows initiative chips and roll input',
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
      await tester.tap(find.widgetWithText(Tab, 'Kampf'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('combat-active-weapon-info-helden-ini'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('combat-active-weapon-info-helden-waffen-ini'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('combat-active-weapon-info-ini')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('combat-active-weapon-info-ini-roll'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('temporary ini roll input clamps without persisting to hero', (
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
    await tester.tap(find.widgetWithText(Tab, 'Kampf'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('combat-active-weapon-info-ini-roll')),
      '13',
    );
    await tester.pumpAndSettle();

    final rollController = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('combat-active-weapon-info-ini-roll')),
    );
    expect(rollController.controller?.text, '12');

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.combatConfig.manualMods.iniWurf, 0);
  });

  testWidgets('aufmerksamkeit disables initiative roll input in UI', (
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
    await tester.tap(find.widgetWithText(Tab, 'Kampf'));
    await tester.pumpAndSettle();

    final rollField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('combat-active-weapon-info-ini-roll')),
    );
    expect(rollField.readOnly, isTrue);
    expect(find.textContaining('Aufmerksamkeit aktiv'), findsOneWidget);
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
    await tester.tap(find.widgetWithText(Tab, 'Kampf'));
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

  testWidgets(
    'ranged info panel shows FK, distance, projectile data and updates ammo count',
    (tester) async {
      final repo = FakeRepository(
        heroes: [
          buildHero(
            combatConfig: const CombatConfig(
              weapons: <MainWeaponSlot>[
                MainWeaponSlot(
                  name: 'Kurzbogen',
                  talentId: 'tal_fern',
                  combatType: WeaponCombatType.ranged,
                  weaponType: 'Kurzbogen',
                  tpFlat: 4,
                  wmFk: 1,
                  rangedProfile: RangedWeaponProfile(
                    reloadTime: 3,
                    distanceBands: <RangedDistanceBand>[
                      RangedDistanceBand(label: 'Nah', tpMod: 2),
                      RangedDistanceBand(label: 'Mittel', tpMod: 0),
                      RangedDistanceBand(label: 'Weit', tpMod: -1),
                      RangedDistanceBand(label: 'Sehr weit', tpMod: -2),
                      RangedDistanceBand(label: 'Extrem', tpMod: -4),
                    ],
                    projectiles: <RangedProjectile>[
                      RangedProjectile(
                        name: 'Jagdspitze',
                        count: 8,
                        tpMod: 1,
                        iniMod: -1,
                        fkMod: 2,
                        description: 'Breite Spitze fuer Wild.',
                      ),
                    ],
                    selectedDistanceIndex: 1,
                    selectedProjectileIndex: 0,
                  ),
                ),
              ],
              selectedWeaponIndex: 0,
            ),
            talents: const <String, HeroTalentEntry>{
              'tal_fern': HeroTalentEntry(talentValue: 8, atValue: 8),
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
      await tester.tap(find.widgetWithText(Tab, 'Kampf'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('combat-active-weapon-info-fk')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('combat-active-weapon-info-reload-time'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('combat-active-weapon-projectile-select'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('combat-active-weapon-distance-select'),
        ),
        findsOneWidget,
      );
      expect(find.text('Breite Spitze fuer Wild.'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'combat-active-weapon-projectile-count-decrement',
          ),
        ),
      );
      await tester.pumpAndSettle();

      var heroes = await repo.listHeroes();
      var hero = heroes.firstWhere((entry) => entry.id == 'demo');
      expect(
        hero
            .combatConfig
            .selectedWeapon
            .rangedProfile
            .selectedProjectileOrNull
            ?.count,
        7,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'combat-active-weapon-projectile-count-increment',
          ),
        ),
      );
      await tester.pumpAndSettle();

      heroes = await repo.listHeroes();
      hero = heroes.firstWhere((entry) => entry.id == 'demo');
      expect(
        hero
            .combatConfig
            .selectedWeapon
            .rangedProfile
            .selectedProjectileOrNull
            ?.count,
        8,
      );
    },
  );

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
    await tester.tap(find.widgetWithText(Tab, 'Kampf'));
    await tester.pumpAndSettle();
    final offhandMode = find.byKey(
      const ValueKey<String>('combat-offhand-mode'),
    );
    for (var i = 0; i < 6 && offhandMode.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    expect(offhandMode, findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(offhandMode);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schild').last);
    await tester.pumpAndSettle();
    final offhandAtMod = find.byKey(
      const ValueKey<String>('combat-offhand-at-mod'),
    );
    for (var i = 0; i < 3 && offhandAtMod.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -180));
      await tester.pumpAndSettle();
    }
    expect(offhandAtMod, findsOneWidget);
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
      find.descendant(of: table, matching: find.text('Artefakt')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: table, matching: find.text('Artefaktbeschreibung')),
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
        .descendant(of: table, matching: find.text('INI'))
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

  testWidgets('weapon overview exposes INI fields in read mode', (
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

    expect(
      find.byKey(const ValueKey<String>('combat-weapon-cell-ini-0')),
      findsOneWidget,
    );
    expect(find.text('INI'), findsAtLeastNWidgets(1));
    expect(find.text('Artefaktbeschreibung'), findsOneWidget);
  });

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

    expect(find.text('Bidenhaender'), findsAtLeastNWidgets(1));
    expect(find.text('Kurzschwert'), findsNothing);
  });

  testWidgets('armor pieces can be added, edited and removed in read mode', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          combatConfig: const CombatConfig(
            armor: ArmorConfig(globalArmorTrainingLevel: 1),
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

    await tester.tap(find.widgetWithText(Tab, 'Kampf'));
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

    expect(find.text('Kettenhemd'), findsOneWidget);
    expect(find.text('RS 3'), findsOneWidget);
    expect(find.text('BE 4'), findsOneWidget);
    expect(find.text('RG I Ja'), findsOneWidget);

    await openArmorEditor(tester, index: 0);
    await fillArmorDialog(
      tester,
      name: 'Kettenhemd',
      rs: '5',
      be: '6',
      isActive: true,
      rg1Active: true,
    );
    expect(find.text('RS 5'), findsOneWidget);
    expect(find.text('BE 6'), findsOneWidget);
    expect(find.text('RG I Ja'), findsOneWidget);

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

  testWidgets('armor dialog shows RG I toggle only when training is I', (
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
    await tester.tap(find.widgetWithText(Tab, 'Kampf'));
    await tester.pumpAndSettle();

    await openArmorEditor(tester);
    expect(
      find.byKey(const ValueKey<String>('combat-armor-form-rg1')),
      findsNothing,
    );
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    await actions.startEdit();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Sonderfertigkeiten'));
    await tester.pumpAndSettle();
    await selectDropdownByKey(
      tester,
      keyName: 'combat-armor-global-training-level',
      valueText: 'I',
    );

    await tester.tap(find.widgetWithText(Tab, 'Kampf'));
    await tester.pumpAndSettle();
    await openArmorEditor(tester);
    expect(
      find.byKey(const ValueKey<String>('combat-armor-form-rg1')),
      findsOneWidget,
    );
  });
}
