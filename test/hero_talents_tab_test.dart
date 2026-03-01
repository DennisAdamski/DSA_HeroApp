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
import 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

void main() {
  var tabOpenCounter = 0;

  HeroSheet buildHero({
    int level = 1,
    List<String> hiddenTalentIds = const <String>[],
    Map<String, HeroTalentEntry> talents = const <String, HeroTalentEntry>{},
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

  testWidgets(
    'grouped table renders with requested column order and hidden talents are excluded in normal mode',
    (tester) async {
      final repo = FakeRepository(
        heroes: [
          buildHero(hiddenTalentIds: const <String>['tal_b']),
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
        'BE',
        'eBE',
        'TaW',
        'max TaW',
        'Mod',
        'TaW berechnet',
        'SE',
        'Spezialisierungen',
        'Sonderfertigkeiten',
      ];
      for (var i = 0; i < headers.length - 1; i++) {
        final left = tester.getTopLeft(find.text(headers[i]).first).dx;
        final right = tester.getTopLeft(find.text(headers[i + 1]).first).dx;
        expect(left, lessThan(right));
      }
    },
  );

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

  testWidgets('edit mode shows hidden talents and enables visibility toggles', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(hiddenTalentIds: const <String>['tal_b']),
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

    expect(find.textContaining('Boote Fahren (ausgeblendet)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('talents-visibility-tal_b')),
      findsOneWidget,
    );
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('talents-field-tal_a-talentValue')),
    );
    expect(field.readOnly, isFalse);
  });

  testWidgets('save persists edited values and hidden-state changes', (
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

    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-field-tal_a-talentValue')),
      '7',
    );
    final visibilityToggle = find.byKey(
      const ValueKey<String>('talents-visibility-tal_a'),
    );
    await tester.ensureVisible(visibilityToggle);
    await tester.tap(visibilityToggle);
    await tester.pumpAndSettle();
    await actions.save();
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.hiddenTalentIds, contains('tal_a'));
    expect(hero.talents['tal_a']?.talentValue, 7);
    expect(find.text('Athletik'), findsNothing);
  });

  testWidgets('cancel discards local draft changes', (tester) async {
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

    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-field-tal_a-talentValue')),
      '9',
    );
    final visibilityToggle = find.byKey(
      const ValueKey<String>('talents-visibility-tal_a'),
    );
    await tester.ensureVisible(visibilityToggle);
    await tester.tap(visibilityToggle);
    await tester.pumpAndSettle();

    await actions.cancel();
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.hiddenTalentIds, isNot(contains('tal_a')));
    expect(hero.talents['tal_a'], isNull);
    expect(find.text('Athletik'), findsOneWidget);
  });

  testWidgets('non-combat talents use BE (Kampf) for eBE and computed TaW', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          level: 7,
          talents: const <String, HeroTalentEntry>{
            'tal_a': HeroTalentEntry(talentValue: 7, modifier: 1),
          },
          combatConfig: const CombatConfig(
            armor: ArmorConfig(
              pieces: <ArmorPiece>[
                ArmorPiece(name: 'Ruestung', isActive: true, rg1Active: true, be: 4),
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

    await openTalentsTab(tester, repo, buildCatalog());

    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('talents-field-tal_a-ebe-display'),
        ),
        matching: find.text('-6'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('talents-field-tal_a-computed-taw'),
        ),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'temporary BE override updates eBE and computed TaW immediately',
    (tester) async {
      final repo = FakeRepository(
        heroes: [
          buildHero(
            level: 7,
            talents: const <String, HeroTalentEntry>{
              'tal_a': HeroTalentEntry(talentValue: 7, modifier: 1),
            },
            combatConfig: const CombatConfig(
              armor: ArmorConfig(
                pieces: <ArmorPiece>[
                  ArmorPiece(name: 'Ruestung', isActive: true, rg1Active: true, be: 4),
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

      await openTalentsTab(tester, repo, buildCatalog());
      await tester.enterText(
        find.byKey(const ValueKey<String>('talents-be-override-field')),
        '1',
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('talents-field-tal_a-ebe-display'),
          ),
          matching: find.text('-2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('talents-field-tal_a-computed-taw'),
          ),
          matching: find.text('6'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('clearing temporary BE override falls back to BE (Kampf)', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          level: 7,
          talents: const <String, HeroTalentEntry>{
            'tal_a': HeroTalentEntry(talentValue: 7, modifier: 1),
          },
          combatConfig: const CombatConfig(
            armor: ArmorConfig(
              pieces: <ArmorPiece>[
                ArmorPiece(name: 'Ruestung', isActive: true, rg1Active: true, be: 4),
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

    await openTalentsTab(tester, repo, buildCatalog());
    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-be-override-field')),
      '1',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('talents-be-override-clear')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('talents-field-tal_a-ebe-display'),
        ),
        matching: find.text('-6'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('talents-field-tal_a-computed-taw'),
        ),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('temporary BE override is not persisted when saving talents', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          level: 7,
          combatConfig: const CombatConfig(
            armor: ArmorConfig(
              pieces: <ArmorPiece>[
                ArmorPiece(name: 'Ruestung', isActive: true, rg1Active: false, be: 3),
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
    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-be-override-field')),
      '1',
    );
    await tester.pumpAndSettle();

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
    final overrideField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('talents-be-override-field')),
    );
    expect(overrideField.controller?.text ?? '', isEmpty);
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('talents-field-tal_a-ebe-display'),
        ),
        matching: find.text('-6'),
      ),
      findsOneWidget,
    );
  });
}
