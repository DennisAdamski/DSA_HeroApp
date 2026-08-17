import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/special_ability_chain_card.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

/// Prueft die Voraussetzungs-Anzeige der Kampf-Sonderfertigkeiten:
/// Stufenkarte statt loser Chips, sichtbare Sperre und Meisterentscheid.
void main() {
  // GE 10 erfuellt Ausweichen I, aber nicht Ausweichen II (GE 12).
  HeroSheet buildHero({CombatConfig combatConfig = const CombatConfig()}) {
    return HeroSheet(
      id: 'demo',
      name: 'Rondra',
      level: 7,
      apTotal: 5000,
      attributes: const Attributes(
        mu: 14,
        kl: 12,
        inn: 13,
        ch: 11,
        ff: 10,
        ge: 10,
        ko: 14,
        kk: 13,
      ),
      combatConfig: combatConfig,
    );
  }

  RulesCatalog buildCatalog() {
    return const RulesCatalog(
      version: 'test_catalog',
      source: 'test',
      talents: <TalentDef>[],
      spells: <SpellDef>[],
      weapons: <WeaponDef>[],
      combatSpecialAbilities: <CombatSpecialAbilityDef>[
        CombatSpecialAbilityDef(
          id: 'ksf_aufmerksamkeit',
          name: 'Aufmerksamkeit',
          beschreibung: 'Deaktiviert INI-Würfeln.',
          kosten: '100 AP',
          voraussetzungenStruktur: <SpecialAbilityRequirement>[
            SpecialAbilityRequirement(
              art: RequirementArt.eigenschaft,
              code: 'IN',
              min: 12,
            ),
          ],
        ),
        CombatSpecialAbilityDef(
          id: 'ksf_ausweichen_i',
          name: 'Ausweichen I',
          kosten: '100 AP',
          kette: SpecialAbilityChainRef(
            id: 'ausweichen',
            stufe: 1,
            label: 'Ausweichen',
          ),
          voraussetzungenStruktur: <SpecialAbilityRequirement>[
            SpecialAbilityRequirement(
              art: RequirementArt.eigenschaft,
              code: 'GE',
              min: 10,
            ),
          ],
        ),
        CombatSpecialAbilityDef(
          id: 'ksf_ausweichen_ii',
          name: 'Ausweichen II',
          kosten: '200 AP',
          kette: SpecialAbilityChainRef(id: 'ausweichen', stufe: 2),
          voraussetzungenStruktur: <SpecialAbilityRequirement>[
            SpecialAbilityRequirement(
              art: RequirementArt.eigenschaft,
              code: 'GE',
              min: 12,
            ),
            SpecialAbilityRequirement(
              art: RequirementArt.sonderfertigkeit,
              name: 'Ausweichen I',
            ),
          ],
        ),
        CombatSpecialAbilityDef(
          id: 'ksf_blindkampf',
          name: 'Blindkampf',
          beschreibung: 'Begrenzt Sichtabzüge im Nahkampf.',
          kosten: '300 AP',
          voraussetzungenStruktur: <SpecialAbilityRequirement>[
            SpecialAbilityRequirement(
              art: RequirementArt.eigenschaft,
              code: 'GE',
              min: 12,
            ),
            SpecialAbilityRequirement(
              art: RequirementArt.sonderfertigkeit,
              name: 'Kampfgespür',
            ),
          ],
        ),
      ],
    );
  }

  Future<WorkspaceTabEditActions> openCombatTab(
    WidgetTester tester,
    FakeRepository repo,
  ) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

  FakeRepository buildRepo({CombatConfig combatConfig = const CombatConfig()}) {
    return FakeRepository(
      heroes: <HeroSheet>[buildHero(combatConfig: combatConfig)],
      states: <String, HeroState>{
        'demo': const HeroState(
          currentLep: 30,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 30,
        ),
      },
    );
  }

  Future<void> openRulesTab(WidgetTester tester) async {
    final finder = find.widgetWithText(Tab, 'Kampfregeln');
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> expandCombatGroup(WidgetTester tester, String titel) async {
    await tester.tap(find.textContaining('$titel (').first);
    await tester.pumpAndSettle();
  }

  testWidgets('eine Stufenkette erscheint als eine Karte', (tester) async {
    await openCombatTab(tester, buildRepo());
    await openRulesTab(tester);
    await expandCombatGroup(tester, 'Allgemeine Kampf-Sonderfertigkeiten');

    expect(find.byKey(const ValueKey<String>('sf-chain-ausweichen')), findsOneWidget);
    // Der Kettenname steht auf der Karte, die Einzelstufen nicht mehr als Chip.
    expect(find.text('Ausweichen'), findsOneWidget);
    expect(find.text('Ausweichen I'), findsNothing);
  });

  testWidgets('die Kettenkarte nennt die offenen Punkte der naechsten Stufe', (
    tester,
  ) async {
    await openCombatTab(
      tester,
      buildRepo(
        combatConfig: const CombatConfig(
          specialRules: CombatSpecialRules(ausweichenI: true),
        ),
      ),
    );
    await openRulesTab(tester);
    await expandCombatGroup(tester, 'Allgemeine Kampf-Sonderfertigkeiten');

    // Stufe I ist aktiv, Stufe II scheitert an GE 12 — der Held hat GE 10.
    // Die Checkliste rendert Soll und Ist als ein Text.rich, deshalb
    // textContaining statt text.
    expect(find.textContaining('Stufe I von II'), findsOneWidget);
    expect(find.textContaining('GE 12'), findsOneWidget);
    expect(find.textContaining('Held hat 10'), findsOneWidget);
  });

  testWidgets('ein gesperrter Chip zeigt die Zahl der offenen Punkte', (
    tester,
  ) async {
    await openCombatTab(tester, buildRepo());
    await openRulesTab(tester);
    await expandCombatGroup(tester, 'Allgemeine Kampf-Sonderfertigkeiten');

    // Blindkampf verlangt GE 12 und SF Kampfgespür — beides fehlt.
    expect(find.text('2 Voraussetzungen offen'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
  });

  testWidgets('ein erfuellter Chip bleibt ohne Sperrhinweis', (tester) async {
    await openCombatTab(tester, buildRepo());
    await openRulesTab(tester);
    await expandCombatGroup(tester, 'Allgemeine Kampf-Sonderfertigkeiten');

    // Aufmerksamkeit verlangt IN 12; der Held hat IN 13.
    expect(find.text('Deaktiviert INI-Würfeln.'), findsOneWidget);
    expect(find.text('1 Voraussetzung offen'), findsNothing);
  });

  testWidgets('der Erwerb bei offenen Punkten verlangt den Meisterentscheid', (
    tester,
  ) async {
    final actions = await openCombatTab(tester, buildRepo());
    actions.startEdit();
    await tester.pumpAndSettle();
    await openRulesTab(tester);
    await expandCombatGroup(tester, 'Allgemeine Kampf-Sonderfertigkeiten');

    final chip = find
        .ancestor(
          of: find.text('Blindkampf'),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    await tester.tap(find.descendant(of: chip, matching: find.byType(Switch)));
    await tester.pumpAndSettle();

    // Der Dialog zeigt die Checkliste und sperrt den Knopf bis zur Bestaetigung.
    expect(find.textContaining('Trotzdem erwerben'), findsOneWidget);
    expect(find.textContaining('SF Kampfgespür'), findsOneWidget);
    final erwerben = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Erwerben'),
    );
    expect(erwerben.onPressed, isNull);
  });

  testWidgets('die Stufenkarte ist auch ohne erworbene Stufe da', (
    tester,
  ) async {
    await openCombatTab(tester, buildRepo());
    await openRulesTab(tester);
    await expandCombatGroup(tester, 'Allgemeine Kampf-Sonderfertigkeiten');

    expect(find.byType(SpecialAbilityChainCard<CombatSpecialAbilityDef>),
        findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('sf-chain-acquire-ksf_ausweichen_i')),
      findsOneWidget,
    );
  });
}
