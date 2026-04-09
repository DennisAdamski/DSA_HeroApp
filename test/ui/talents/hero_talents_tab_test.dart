import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_meta_talent.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
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
    List<HeroInventoryEntry> inventoryEntries = const <HeroInventoryEntry>[],
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
      inventoryEntries: inventoryEntries,
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
      sprachen: <SpracheDef>[
        SpracheDef(
          id: 'spr_zyklopaeisch',
          name: 'Zyklopäisch',
          familie: 'Tulamidya',
          steigerung: 'A',
          maxWert: 18,
        ),
      ],
      schriften: <SchriftDef>[
        SchriftDef(
          id: 'schrift_kusliker',
          name: 'Kusliker Zeichen',
          steigerung: 'B',
          maxWert: 18,
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

  Future<void> scrollMainListUpUntilVisible(
    WidgetTester tester,
    Finder target,
  ) async {
    final mainScrollable = find.byType(Scrollable).first;
    for (var attempt = 0; attempt < 12; attempt++) {
      if (target.evaluate().isNotEmpty) {
        return;
      }
      await tester.drag(mainScrollable, const Offset(0, 300));
      await tester.pumpAndSettle();
    }
    expect(target, findsOneWidget);
  }

  Future<void> openBeScreen(WidgetTester tester) async {
    final beButton = find.byKey(
      const ValueKey<String>('talents-be-screen-open'),
    );
    await scrollMainListUpUntilVisible(tester, beButton);
    await tester.ensureVisible(beButton);
    await tester.pumpAndSettle();
    await tester.tap(beButton);
    await tester.pumpAndSettle();
    expect(find.text('Talent-BE'), findsOneWidget);
  }

  Future<void> closeBeDialog(WidgetTester tester) async {
    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();
  }

  Future<void> createMetaTalent(
    WidgetTester tester, {
    required String name,
    required List<String> componentIds,
    required List<String> attributes,
    String be = '',
  }) async {
    final manageButton = find.byKey(
      const ValueKey<String>('meta-talents-manage-open'),
    );
    await scrollMainListUpUntilVisible(tester, manageButton);
    await tester.ensureVisible(manageButton);
    await tester.tap(manageButton);
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
      await tester.scrollUntilVisible(
        find.byKey(ValueKey<String>('meta-talent-component-$componentId')),
        200,
        scrollable: find.byType(Scrollable).last,
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
      expect(find.text('Ohne Gruppe', skipOffstage: false), findsOneWidget);
      expect(find.text('Kampftalent'), findsNothing);
      expect(find.text('Athletik'), findsOneWidget);
      expect(find.text('Boote Fahren'), findsNothing);
      expect(find.text('Schatzensuche', skipOffstage: false), findsOneWidget);
      expect(find.text('Schwerter'), findsNothing);
      expect(find.text('MU: 14 | GE: 12 | KK: 13'), findsOneWidget);

      final headers = <String>[
        'Name',
        'Eigenschaften',
        'Kompl.',
        'eBE',
        'TaW',
        'Mod',
        'TaW*',
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

  testWidgets('meta talent row opens detail dialog and probe dialog', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{
            'tal_a': HeroTalentEntry(talentValue: 6),
            'tal_b': HeroTalentEntry(talentValue: 8),
          },
          metaTalents: const <HeroMetaTalent>[
            HeroMetaTalent(
              id: 'meta_pflanzensuchen',
              name: 'Pflanzensuchen',
              componentTalentIds: <String>['tal_a', 'tal_b'],
              attributes: <String>['MU', 'IN', 'FF'],
              be: 'x2',
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

    await openTalentsTab(tester, repo, buildCatalog());

    final metaTalentRow = find.byKey(
      const ValueKey<String>('meta-talents-row-meta_pflanzensuchen'),
    );
    await tester.scrollUntilVisible(
      metaTalentRow,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(metaTalentRow);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: metaTalentRow, matching: find.text('Pflanzensuchen')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Heldenspezifisches Meta-Talent'), findsOneWidget);
    expect(find.text('Roh-TaW'), findsOneWidget);
    expect(find.text('Athletik'), findsWidgets);
    expect(find.text('Boote Fahren'), findsWidgets);

    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey<String>('meta-talents-roll-meta_pflanzensuchen'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Talentprobe: Pflanzensuchen'), findsOneWidget);
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

    final koerper = find.text('Koerperliche Talente');
    final gesellschaft = find.text('Gesellschaftliche Talente');
    await tester.scrollUntilVisible(
      find.text('Natur Talente'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final natur = find.text('Natur Talente');
    expect(koerper, findsOneWidget);
    expect(gesellschaft, findsOneWidget);
    expect(natur, findsOneWidget);
    expect(
      tester.getTopLeft(koerper).dy,
      lessThan(tester.getTopLeft(gesellschaft).dy),
    );
    expect(
      tester.getTopLeft(gesellschaft).dy,
      lessThan(tester.getTopLeft(natur).dy),
    );
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

  testWidgets('special ability add action stays available outside edit mode', (
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

    await openTalentsTab(tester, repo, buildCatalog());

    await tester.tap(find.text('Sonderfertigkeiten'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('talents-special-abilities-add')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sonderfertigkeit hinzufügen'), findsOneWidget);
  });

  testWidgets(
    'languages and scripts show described add buttons outside edit mode',
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

      await openTalentsTab(tester, repo, buildCatalog());

      await tester.tap(find.text('Sprachen & Schriften'));
      await tester.pumpAndSettle();

      expect(
        find.text('Lege bekannte Sprachen mit Lernwert und Muttersprache an.'),
        findsOneWidget,
      );
      expect(
        find.text('Erfasse gelernte Schriften inklusive aktuellem Wert.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Sprache'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Schrift'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Sprache'));
      await tester.pumpAndSettle();
      expect(find.text('Sprachen'), findsWidgets);
    },
  );

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
        find.byKey(
          const ValueKey<String>('talents-field-tal_a-modifier-total'),
        ),
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('talents-field-tal_a-modifier-total'),
        ),
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

  testWidgets('inventory talent modifiers are shown directly in the mod column', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{
            'tal_a': HeroTalentEntry(talentValue: 5),
          },
          inventoryEntries: const <HeroInventoryEntry>[
            HeroInventoryEntry(
              gegenstand: 'Kletterhandschuhe',
              itemType: InventoryItemType.ausruestung,
              istAusgeruestet: true,
              modifiers: <InventoryItemModifier>[
                InventoryItemModifier(
                  kind: InventoryModifierKind.talent,
                  targetId: 'tal_a',
                  wert: 2,
                  beschreibung: 'Kletterhandschuhe',
                ),
              ],
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

    await openTalentsTab(tester, repo, buildCatalog());

    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('talents-field-tal_a-modifier-total'),
        ),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('talents-field-tal_a-computed-taw'),
        ),
        matching: find.text('7'),
      ),
      findsOneWidget,
    );
  });

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
        find.byKey(
          const ValueKey<String>('talents-field-tal_a-modifier-total'),
        ),
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('talents-field-tal_a-modifier-total'),
        ),
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
    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Meta-Talente'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Meta-Talente'), findsOneWidget);
    expect(find.text('Pflanzensuchen'), findsOneWidget);

    final manageButton = find.byKey(
      const ValueKey<String>('meta-talents-manage-open'),
    );
    await scrollMainListUpUntilVisible(tester, manageButton);
    await tester.ensureVisible(manageButton);
    await tester.tap(manageButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schließen'));
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

      Future<String> visibleTextFor(Key key) async {
        final field = find.byKey(key);
        await tester.scrollUntilVisible(
          field,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        return textFor(key);
      }

      final actions = await openTalentsTab(tester, repo, buildCatalog());
      final computedTawField = find.byKey(
        const ValueKey<String>(
          'meta-talents-field-meta_pflanzensuchen-computed-taw',
        ),
      );
      await tester.scrollUntilVisible(
        computedTawField,
        300,
        scrollable: find.byType(Scrollable).first,
      );
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
        await visibleTextFor(
          const ValueKey<String>('meta-talents-field-meta_pflanzensuchen-ebe'),
        ),
        '-2',
      );
      expect(
        await visibleTextFor(
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
