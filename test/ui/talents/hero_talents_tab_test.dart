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
        'BE',
        'eBE',
        'TaW',
        'max TaW',
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

  testWidgets('edit mode allows editing talent values', (
    tester,
  ) async {
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

    // Im Edit-Modus sind die Felder bearbeitbar.
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('talents-field-tal_a-talentValue')),
    );
    expect(field.readOnly, isFalse);

    // Katalog-Button erscheint im Edit-Modus.
    expect(
      find.byKey(const ValueKey<String>('talents-catalog-open')),
      findsOneWidget,
    );
  });

  testWidgets('save persists edited talent values', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{
            'tal_a': HeroTalentEntry(),
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

  testWidgets('cancel discards local draft changes', (tester) async {
    final repo = FakeRepository(
      heroes: [
        buildHero(
          talents: const <String, HeroTalentEntry>{
            'tal_a': HeroTalentEntry(),
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

    await tester.enterText(
      find.byKey(const ValueKey<String>('talents-field-tal_a-talentValue')),
      '9',
    );

    await actions.cancel();
    await tester.pumpAndSettle();

    final heroes = await repo.listHeroes();
    final hero = heroes.firstWhere((entry) => entry.id == 'demo');
    expect(hero.talents['tal_a']?.talentValue, 0);
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
}
