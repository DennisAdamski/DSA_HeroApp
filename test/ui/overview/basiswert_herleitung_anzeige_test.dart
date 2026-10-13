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
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

import '../../test_support/bogen_test_repository.dart';

// ARCH-04: Die Basiswerttabelle und der Modifikatordialog zeigen die
// Herleitung des Regelmoduls, statt Modifikatoren selbst zu addieren.

const _katalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: <TalentDef>[],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
);

HeroSheet _held() => HeroSheet(
  id: 'demo',
  name: 'Rondra',
  level: 1,
  schemaVersion: 30,
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
  statModifiers: <String, List<HeroTalentModifier>>{
    'lep': <HeroTalentModifier>[
      HeroTalentModifier(modifier: 2, description: 'Zäh'),
    ],
  },
  combatConfig: const CombatConfig(
    specialRules: CombatSpecialRules(kampfreflexe: true),
  ),
);

void main() {
  Future<void> zeige(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = BogenTestRepository(
      heroes: [_held()],
      states: const {
        'demo': HeroState(
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
          rulesCatalogProvider.overrideWith((ref) async => _katalog),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HeroOverviewTab(
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
  }

  Future<Finder> zelle(WidgetTester tester, String statKey) async {
    final ziel = find.byKey(ValueKey('overview-stat-modifier-$statKey'));
    await tester.scrollUntilVisible(
      ziel,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    return ziel;
  }

  testWidgets('Sonderfertigkeiten zählen zum Modifikator, nicht zum Start', (
    tester,
  ) async {
    await zeige(tester);
    // INI-Basis: round((14 + 14 + 13 + 12) / 5) = 11, Kampfreflexe +4.
    final ini = await zelle(tester, 'iniBase');
    expect(find.descendant(of: ini, matching: find.text('4')), findsOneWidget);
  });

  testWidgets('der Dialog zeigt Rechenweg, Quellen und Ergebnis', (
    tester,
  ) async {
    await zeige(tester);
    final lep = await zelle(tester, 'lep');
    // Stufe 1 und der eigene Modifikator „Zäh“ (+2).
    expect(find.descendant(of: lep, matching: find.text('3')), findsOneWidget);

    await tester.tap(lep);
    await tester.pumpAndSettle();

    expect(find.text('Herleitung (gespeicherter Stand)'), findsOneWidget);
    expect(find.text('(KO 14 + KO 14 + KK 13) / 2'), findsOneWidget);
    expect(find.text('Eigener Modifikator'), findsOneWidget);
    final ergebnis = find.byKey(const ValueKey('stat-herleitung-ergebnis'));
    // 21 + Stufe 1 + Zäh 2.
    expect(
      find.descendant(of: ergebnis, matching: find.text('24')),
      findsOneWidget,
    );
  });
}
