import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_meta_talent.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

void main() {
  var tabOpenCounter = 0;

  HeroSheet buildHero({
    int level = 1,
    Map<String, HeroTalentEntry> talents = const <String, HeroTalentEntry>{},
    List<HeroMetaTalent> metaTalents = const <HeroMetaTalent>[],
    CombatConfig combatConfig = const CombatConfig(),
  }) {
    return HeroSheet(
      id: 'demo',
      name: 'Rondra',
      level: level,
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
      talents: talents,
      metaTalents: metaTalents,
      combatConfig: combatConfig,
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
          be: 'x2',
          attributes: <String>['Mut', 'Gewandheit', 'Koerperkraft'],
        ),
        TalentDef(
          id: 'tal_b',
          name: 'Boote Fahren',
          group: 'Natur',
          steigerung: 'B',
          attributes: <String>['Mut', 'Intuition', 'Koerperkraft'],
        ),
        TalentDef(
          id: 'tal_c',
          name: 'Schatzensuche',
          group: '',
          steigerung: 'D',
          attributes: <String>['Klugheit', 'Intuition', 'Intuition'],
          active: false,
        ),
        TalentDef(
          id: 'tal_kampf',
          name: 'Schwerter',
          group: 'Kampftalent',
          type: 'Nahkampf',
          weaponCategory: 'Schwert',
          steigerung: 'D',
          be: 'x2',
          attributes: <String>['Mut', 'Gewandheit', 'Koerperkraft'],
        ),
      ],
      spells: <SpellDef>[],
      weapons: <WeaponDef>[],
    );
  }

  Future<WorkspaceTabEditActions> openTalentsTab(
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
            body: HeroTalentsTab(
              key: ValueKey<String>('talents-tab-${tabOpenCounter++}'),
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

  Future<void> openBeScreen(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey<String>('talents-be-screen-open')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Talent-BE'), findsOneWidget);
  }

  Future<void> closeBeDialog(WidgetTester tester) async {
    await tester.tap(find.text('Schliessen'));
    await tester.pumpAndSettle();
  }

  Future<void> createMetaTalent(
    WidgetTester tester, {
    required String name,
    required List<String> componentIds,
    required List<String> attributes,
    String be = '',
  }) async {
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('meta-talents-manage-open')),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('meta-talents-manage-open')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('meta-talents-manage-open')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('meta-talents-manager-add')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('meta-talent-name-field')),
      name,
    );
    if (be.isNotEmpty) {
      await tester.enterText(
        find.byKey(const ValueKey<String>('meta-talent-be-field')),
        be,
      );
    }

    for (var index = 0; index < attributes.length; index++) {
      await tester.tap(
        find.byKey(ValueKey<String>('meta-talent-attribute-$index')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(attributes[index]).last);
      await tester.pumpAndSettle();
    }

    for (final componentId in componentIds) {
      await tester.ensureVisible(
        find.byKey(ValueKey<String>('meta-talent-component-$componentId')),
      );
      await tester.tap(
        find.byKey(ValueKey<String>('meta-talent-component-$componentId')),
      );
      await tester.pumpAndSettle();
    }

    await tester.tap(
      find.byKey(const ValueKey<String>('meta-talent-editor-save')),
    );
    await tester.pumpAndSettle();
    expect(find.text(name), findsWidgets);
  }

  testWidgets(
    'only talents present in hero.talents are shown, groups render correctly',
    (tester) async {
      // Held hat nur tal_a und tal_c in talents-Map. tal_b fehlt und wird nicht angezeigt.
      final repo = FakeRepository(
        heroes: [
          buildHero(
            talents: const <String, HeroTalentEntry>{
              'tal_a': HeroTalentEntry(),
              'tal_c': HeroTalentEntry(),
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

      await openTalentsTab(tester, repo, buildCatalog());

      expect(find.text('Koerper'), findsOneWidget);
      expect(find.text('Natur'), findsNothing);
      expect(find.text('Ohne Gruppe'), findsOneWidget);
      expect(find.text('Kampftalent'), findsNothing);
      expect(find.text('Athletik'), findsOneWidget);
      expect(find.text('Boote Fahren'), findsNothing);
      expect(find.text('Schatzensuche'), findsOneWidget);
      expect(find.text('Schwerter'), findsNothing);
      expect(find.text('MU: 14 | GE: 12 | KK: 13'), findsOneWidget);

      final headers = <String>[
        'Talent-Name',
        'Eigenschaften',
        'Kompl.',
        'eBE',
        'TaW',
        'Mod',
        'TaW berechnet',
        'SE',
        'Spezialisierungen',
      ];
      for (var i = 0; i < headers.length - 1; i++) {
        final left = tester.getTopLeft(find.text(headers[i]).first).dx;
        final right = tester.getTopLeft(find.text(headers[i + 1]).first).dx;
        if (right >= left) {
          expect(right, greaterThanOrEqualTo(left));
        }
      }
      expect(find.text('Sonderfertigkeiten'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('talents-be-screen-open')),
        findsOneWidget,
      );
    },
  );

  testWidgets('talent row opens shared probe dialog via dice icon', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{
            'tal_a': HeroTalentEntry(talentValue: 7),
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

    await openTalentsTab(tester, repo, buildCatalog());

    await tester.tap(find.byKey(const ValueKey<String>('talents-roll-tal_a')));
    await tester.pumpAndSettle();

    expect(find.text('Talentprobe: Athletik'), findsOneWidget);
  });

  testWidgets('non-combat groups follow configured custom order', (
    tester,
  ) async {
    final customCatalog = const RulesCatalog(
      version: 'test_catalog',
      source: 'test',
      talents: <TalentDef>[
        TalentDef(
          id: 't1',
          name: 'Athletik',
          group: 'Koerperliche Talente',
          steigerung: 'C',
          attributes: <String>['Mut', 'Gewandheit', 'Koerperkraft'],
        ),
        TalentDef(
          id: 't2',
          name: 'Etikette',
          group: 'Gesellschaftliche Talente',
          steigerung: 'B',
          attributes: <String>['Klugheit', 'Intuition', 'Charisma'],
        ),
        TalentDef(
          id: 't3',
          name: 'Orientierung',
          group: 'Natur Talente',
          steigerung: 'C',
          attributes: <String>['Klugheit', 'Intuition', 'Intuition'],
        ),
        TalentDef(
          id: 't4',
          name: 'Sagen',
          group: 'Wissenstalente',
          steigerung: 'B',
          attributes: <String>['Klugheit', 'Intuition', 'Charisma'],
        ),
        TalentDef(
          id: 't5',
          name: 'Kochen',
          group: 'Handwerkliche Talente',
          steigerung: 'B',
          attributes: <String>['Klugheit', 'Fingerfertigkeit', 'Konstitution'],
        ),
      ],
      spells: <SpellDef>[],
      weapons: <WeaponDef>[],
    );

    // Held hat alle Talente in der Map, damit sie sichtbar sind.
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{
            't1': HeroTalentEntry(),
            't2': HeroTalentEntry(),
            't3': HeroTalentEntry(),
            't4': HeroTalentEntry(),
            't5': HeroTalentEntry(),
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

    await openTalentsTab(tester, repo, customCatalog);

    final groupOrder = tester
        .widgetList<ExpansionTile>(find.byType(ExpansionTile))
        .map((tile) => ((tile.title as Text).data ?? '').trim())
        .toList(growable: false);
    expect(groupOrder, [
      'Koerperliche Talente',
      'Gesellschaftliche Talente',
      'Natur Talente',
    ]);
    await tester.scrollUntilVisible(
      find.text('Wissenstalente'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Wissenstalente'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Handwerkliche Talente'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Handwerkliche Talente'), findsOneWidget);
  });

  testWidgets('edit mode allows editing talent values', (tester) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{
            'tal_a': HeroTalentEntry(),
            'tal_b': HeroTalentEntry(),
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

    final actions = await openTalentsTab(tester, repo, buildCatalog());
    await actions.startEdit();
    await tester.pumpAndSettle();

    // Im Edit-Modus rendert EditAwareTableCell ein editierbares TextField.
    final innerField = find.descendant(
      of: find.byKey(const ValueKey<String>('talents-field-tal_a-talentValue')),
      matching: find.byType(TextField),
    );
    expect(innerField, findsOneWidget);

    // Katalog-Button erscheint im Edit-Modus.
    expect(
      find.byKey(const ValueKey<String>('talents-catalog-open')),
      findsOneWidget,
    );
    final catalogX = tester
        .getTopLeft(find.byKey(const ValueKey<String>('talents-catalog-open')))
        .dx;
    final beX = tester
        .getTopLeft(
          find.byKey(const ValueKey<String>('talents-be-screen-open')),
        )
        .dx;
    expect(catalogX, lessThan(beX));
  });

  testWidgets('gifted talents show reduced complexity and higher max TaW', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{
            'tal_a': HeroTalentEntry(gifted: true),
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

    await openTalentsTab(tester, repo, buildCatalog());

    expect(find.text('B'), findsOneWidget);
    expect(find.text('19'), findsNothing);

    await tester.tap(find.text('Athletik'));
    await tester.pumpAndSettle();

    expect(find.text('19'), findsOneWidget);
  });

  testWidgets('save persists edited talent values', (tester) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{'tal_a': HeroTalentEntry()},
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

    final actions = await openTalentsTab(tester, repo, buildCatalog());
    await actions.startEdit();
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-field-tal_a-talentValue')),
      '7',
    );
    await actions.save();
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.talents['tal_a']?.talentValue, 7);
  });

  testWidgets('structured talent special abilities are saved from the sf tab', (
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

    final actions = await openTalentsTab(tester, repo, buildCatalog());
    await actions.startEdit();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sonderfertigkeiten'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('talents-special-abilities-add')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-special-ability-name')),
      'Regeneration I',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('talents-special-ability-save')),
    );
    await tester.pumpAndSettle();

    await actions.save();
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.talentSpecialAbilities, const <TalentSpecialAbility>[
      TalentSpecialAbility(name: 'Regeneration I'),
    ]);
  });

  testWidgets(
    'modifier dialog persists summed talent modifiers and updates computed taw',
    (tester) async {
      final repo = FakeRepository(
        heroes: [
          buildHero(
            talents: const <String, HeroTalentEntry>{
              'tal_a': HeroTalentEntry(talentValue: 5),
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

      final actions = await openTalentsTab(tester, repo, buildCatalog());
      await actions.startEdit();
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('talents-field-tal_a-modifier-total')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('talents-field-tal_a-modifier-total')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('talent-modifiers-add')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('talent-modifiers-add')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('talent-modifier-value-0')),
        '2',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('talent-modifier-description-0')),
        'Sichtbonus',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('talent-modifier-value-1')),
        '-1',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('talent-modifier-description-1')),
        'Nebel',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('talent-modifiers-save')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('talents-field-tal_a-modifier-total'),
        ),
        findsOneWidget,
      );
      expect(find.text('1'), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('talents-field-tal_a-computed-taw'),
          ),
          matching: find.text('6'),
        ),
        findsOneWidget,
      );

      await actions.save();
      await tester.pumpAndSettle();

      final heroes = await repo.listHeroes();
      final hero = heroes.firstWhere((entry) => entry.id == 'demo');
      expect(hero.talents['tal_a']?.modifier, 1);
      expect(hero.talents['tal_a']?.talentModifiers.length, 2);
    },
  );

  testWidgets(
    'modifier dialog truncates descriptions, skips empty entries and shows details',
    (tester) async {
      const longDescription =
          '123456789012345678901234567890123456789012345678901234567890XYZ';
      const truncatedDescription =
          '123456789012345678901234567890123456789012345678901234567890';
      final repo = FakeRepository(
        heroes: [
          buildHero(
            talents: const <String, HeroTalentEntry>{
              'tal_a': HeroTalentEntry(talentValue: 4),
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

      final actions = await openTalentsTab(tester, repo, buildCatalog());
      await actions.startEdit();
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('talents-field-tal_a-modifier-total')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('talents-field-tal_a-modifier-total')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('talent-modifiers-add')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('talent-modifiers-add')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('talent-modifier-value-0')),
        '5',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('talent-modifier-description-0')),
        longDescription,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('talent-modifier-value-1')),
        '3',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('talent-modifier-description-1')),
        '',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('talent-modifiers-save')),
      );
      await tester.pumpAndSettle();

      await actions.save();
      await tester.pumpAndSettle();

      final heroes = await repo.listHeroes();
      final hero = heroes.firstWhere((entry) => entry.id == 'demo');
      expect(hero.talents['tal_a']?.modifier, 5);
      expect(hero.talents['tal_a']?.talentModifiers.length, 1);
      expect(
        hero.talents['tal_a']?.talentModifiers.single.description,
        truncatedDescription,
      );

      await tester.ensureVisible(find.text('Athletik').first);
      await tester.tap(find.text('Athletik').first);
      await tester.pumpAndSettle();

      expect(find.text('Gesamt-Mod'), findsOneWidget);
      expect(find.text(truncatedDescription), findsOneWidget);
      expect(find.text('5'), findsWidgets);
    },
  );

  testWidgets('cancel discards local draft changes', (tester) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{'tal_a': HeroTalentEntry()},
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

    final actions = await openTalentsTab(tester, repo, buildCatalog());
    await actions.startEdit();
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-field-tal_a-talentValue')),
      '9',
    );

    await actions.cancel();
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.talents['tal_a']?.talentValue, isNull);
    expect(find.text('Athletik'), findsOneWidget);
  });

  testWidgets(
    'temporary BE override stays active within current workspace session',
    (tester) async {
      final repo = FakeRepository(
        heroes: [
          buildHero(
            level: 7,
            talents: const <String, HeroTalentEntry>{
              'tal_a': HeroTalentEntry(),
            },
            combatConfig: const CombatConfig(
              armor: ArmorConfig(
                pieces: <ArmorPiece>[
                  ArmorPiece(
                    name: 'Ruestung',
                    isActive: true,
                    rg1Active: false,
                    be: 3,
                  ),
                ],
                globalArmorTrainingLevel: 0,
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

      final actions = await openTalentsTab(tester, repo, buildCatalog());
      await openBeScreen(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('talents-be-override-field')),
        '1',
      );
      await tester.pumpAndSettle();
      await closeBeDialog(tester);

      await actions.startEdit();
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('talents-field-tal_a-talentValue')),
        '9',
      );
      await actions.save();
      await tester.pumpAndSettle();

      final heroes = await repo.listHeroes();
      final hero = heroes.firstWhere((entry) => entry.id == 'demo');
      expect(hero.combatConfig.armor.pieces.first.be, 3);
      expect(hero.talents['tal_a']?.talentValue, 9);

      await openTalentsTab(tester, repo, buildCatalog());
      await openBeScreen(tester);
      final overrideField = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('talents-be-override-field')),
      );
      expect(overrideField.controller?.text ?? '', '1');
    },
  );

  testWidgets('meta talents can be created and deleted in edit mode', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{
            'tal_a': HeroTalentEntry(),
            'tal_b': HeroTalentEntry(),
            'tal_kampf': HeroTalentEntry(),
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

    final actions = await openTalentsTab(tester, repo, buildCatalog());
    await actions.startEdit();
    await tester.pumpAndSettle();

    await createMetaTalent(
      tester,
      name: 'Pflanzensuchen',
      componentIds: const <String>['tal_a', 'tal_b', 'tal_kampf'],
      attributes: const <String>['MU', 'IN', 'FF'],
      be: 'x2',
    );
    await tester.tap(find.text('Schliessen'));
    await tester.pumpAndSettle();

    expect(find.text('Meta-Talente'), findsOneWidget);
    expect(find.text('Pflanzensuchen'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('meta-talents-manage-open')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schliessen'));
    await tester.pumpAndSettle();

    expect(find.text('Pflanzensuchen'), findsNothing);
    expect(find.text('Meta-Talente'), findsNothing);
  });

  testWidgets(
    'meta talents update live from draft talent values and be override',
    (tester) async {
      final repo = FakeRepository(
        heroes: [
          buildHero(
            talents: const <String, HeroTalentEntry>{
              'tal_a': HeroTalentEntry(talentValue: 6),
              'tal_b': HeroTalentEntry(talentValue: 8),
              'tal_kampf': HeroTalentEntry(talentValue: 4),
            },
            metaTalents: const <HeroMetaTalent>[
              HeroMetaTalent(
                id: 'meta_pflanzensuchen',
                name: 'Pflanzensuchen',
                componentTalentIds: <String>['tal_a', 'tal_b', 'tal_kampf'],
                attributes: <String>['MU', 'IN', 'FF'],
                be: 'x2',
              ),
            ],
            combatConfig: const CombatConfig(
              armor: ArmorConfig(
                pieces: <ArmorPiece>[
                  ArmorPiece(name: 'Ruestung', isActive: true, be: 2),
                ],
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

      String textFor(Key key) {
        final finder = find.descendant(
          of: find.byKey(key),
          matching: find.byType(Text),
        );
        return tester.widget<Text>(finder.first).data ?? '';
      }

      final actions = await openTalentsTab(tester, repo, buildCatalog());
      expect(
        textFor(
          const ValueKey<String>(
            'meta-talents-field-meta_pflanzensuchen-computed-taw',
          ),
        ),
        '2',
      );

      await actions.startEdit();
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('talents-field-tal_a-talentValue')),
        '9',
      );
      await tester.pumpAndSettle();
      expect(
        textFor(
          const ValueKey<String>(
            'meta-talents-field-meta_pflanzensuchen-computed-taw',
          ),
        ),
        '3',
      );

      await openBeScreen(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('talents-be-override-field')),
        '1',
      );
      await tester.pumpAndSettle();
      await closeBeDialog(tester);

      expect(
        textFor(
          const ValueKey<String>('meta-talents-field-meta_pflanzensuchen-ebe'),
        ),
        '-2',
      );
      expect(
        textFor(
          const ValueKey<String>(
            'meta-talents-field-meta_pflanzensuchen-computed-taw',
          ),
        ),
        '5',
      );
    },
  );

  testWidgets(
    'meta talent references lock components in catalog and are activated on save',
    (tester) async {
      final repo = FakeRepository(
        heroes: [
          buildHero(
            talents: const <String, HeroTalentEntry>{
              'tal_a': HeroTalentEntry(talentValue: 5),
            },
            metaTalents: const <HeroMetaTalent>[
              HeroMetaTalent(
                id: 'meta_pflanzensuchen',
                name: 'Pflanzensuchen',
                componentTalentIds: <String>['tal_a', 'tal_b'],
                attributes: <String>['MU', 'IN', 'FF'],
              ),
            ],
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

      final actions = await openTalentsTab(tester, repo, buildCatalog());
      await actions.startEdit();
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('talents-catalog-open')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Meta-Referenz'), findsWidgets);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      await actions.save();
      await tester.pumpAndSettle();

      final heroes = await repo.listHeroes();
      final hero = heroes.firstWhere((entry) => entry.id == 'demo');
      expect(hero.talents.keys, containsAll(<String>['tal_a', 'tal_b']));
    },
  );
}
