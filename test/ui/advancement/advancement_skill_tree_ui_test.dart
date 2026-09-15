import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_catalog.dart';

const _hero = HeroSheet(id: 'tree', name: 'Held', level: 1, apAvailable: 1000,
  attributes: Attributes(mu: 15, kl: 12, inn: 12, ch: 12,
    ff: 15, ge: 15, ko: 15, kk: 15));
const _catalog = RulesCatalog(version: 'test', source: 'test',
  talents: [], spells: [], weapons: [], maneuvers: [
    ManeuverDef(id: 'man_base', name: 'Wuchtschlag', kosten: '100 AP'),
    ManeuverDef(id: 'man_next', name: 'Niederwerfen', kosten: '200 AP',
      voraussetzungenStruktur: [SpecialAbilityRequirement(
        art: RequirementArt.manoever, name: 'Wuchtschlag')]),
  ]);

void main() {
  Future<ProviderContainer> open(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repo = FakeRepository(heroes: [_hero]);
    final container = ProviderContainer(overrides: [
      heroRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container.read(advancementSessionProvider(_hero.id).notifier)
        .start(hero: _hero, catalog: _catalog);
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: const MaterialApp(home: Scaffold(
        body: AdvancementCatalog(heroId: 'tree')))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sonderfertigkeiten'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('Manöver direkt im Baum erwerben und Folgepfad freischalten', (tester) async {
    final container = await open(tester, const Size(1100,900));
    final next = find.byKey(const ValueKey('skill-node-maneuver:man_next'));
    expect(find.descendant(of: next, matching: find.text('Gesperrt')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('skill-node-maneuver:man_base')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Manöver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vormerken'));
    await tester.pumpAndSettle();
    final session = container.read(advancementSessionProvider(_hero.id))!;
    expect(session.preview.apAvailable, 900);
    expect(session.preview.combatConfig.specialRules.activeManeuvers, ['man_base']);
    expect(find.descendant(of: next, matching: find.text('Erlernbar')), findsOneWidget);
    final repo = container.read(heroRepositoryProvider);
    expect((await repo.loadHeroById(_hero.id))!.combatConfig.specialRules.activeManeuvers,
        isEmpty);
    container.read(advancementSessionProvider(_hero.id).notifier)
        .remove(session.entries.single.id);
    await tester.pumpAndSettle();
    expect(find.descendant(of: next, matching: find.text('Gesperrt')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Schmaler Baum erhält Vorstufen bei Suche und öffnet Details', (tester) async {
    await open(tester, const Size(390,844));
    await tester.enterText(find.byKey(const ValueKey('advancement-search')), 'Niederwerfen');
    await tester.pumpAndSettle();
    final base = find.byKey(const ValueKey('skill-node-maneuver:man_base'));
    final next = find.byKey(const ValueKey('skill-node-maneuver:man_next'));
    expect(base, findsOneWidget);
    expect(next, findsOneWidget);
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('+ Manöver'), findsOneWidget);
    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
