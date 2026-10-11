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

const _hero = HeroSheet(
  id: 'gruppen-ui',
  name: 'Held',
  level: 1,
  apAvailable: 1000,
  attributes: Attributes(
    mu: 15,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 15,
    ge: 15,
    ko: 15,
    kk: 15,
  ),
);
const _catalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: [],
  spells: [],
  weapons: [],
  combatSpecialAbilities: [
    CombatSpecialAbilityDef(
      id: 'ksf_aufmerksamkeit',
      name: 'Aufmerksamkeit',
      kosten: '10 AP',
    ),
  ],
  generalSpecialAbilities: [
    SpecialAbilityDef(
      id: 'asf_wachsamkeit',
      name: 'Wachsamkeit',
      gruppe: 'allgemein',
      kosten: '10 AP',
    ),
  ],
  maneuvers: [
    ManeuverDef(
      id: 'man_base',
      name: 'Wuchtschlag',
      gruppe: 'bewaffnet',
      kosten: '100 AP',
    ),
    ManeuverDef(
      id: 'man_next',
      name: 'Niederwerfen',
      gruppe: 'bewaffnet',
      kosten: '200 AP',
      voraussetzungenStruktur: [
        SpecialAbilityRequirement(
          art: RequirementArt.manoever,
          name: 'Wuchtschlag',
        ),
      ],
    ),
    ManeuverDef(
      id: 'man_tritt',
      name: 'Tritt',
      gruppe: 'waffenlos',
      kosten: '50 AP',
    ),
  ],
);

const _kopfKampfGrundlagen = 'advancement-group-header-kampfGrundlagen';
const _kopfWaffen = 'advancement-group-header-kampfWaffenmanoever';
const _kopfWaffenlos = 'advancement-group-header-kampfWaffenlosManoever';
const _kopfAllgemein = 'advancement-group-header-allgemeinPraxis';

void main() {
  Future<ProviderContainer> open(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repo = FakeRepository(heroes: [_hero]);
    final container = ProviderContainer(
      overrides: [heroRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container
        .read(advancementSessionProvider(_hero.id).notifier)
        .start(hero: _hero, catalog: _catalog);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: AdvancementCatalog(heroId: 'gruppen-ui')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sonderfertigkeiten'));
    await tester.pumpAndSettle();
    return container;
  }

  Finder knoten(String id) => find.byKey(ValueKey('skill-node-$id'));
  Finder kopf(String key) => find.byKey(ValueKey(key));

  testWidgets('Gruppen starten zugeklappt und lassen sich öffnen', (
    tester,
  ) async {
    await open(tester, const Size(1100, 1000));
    expect(kopf(_kopfKampfGrundlagen), findsOneWidget);
    expect(kopf(_kopfWaffen), findsOneWidget);
    expect(kopf(_kopfWaffenlos), findsOneWidget);
    expect(kopf(_kopfAllgemein), findsOneWidget);
    expect(knoten('maneuver:man_base'), findsNothing);
    expect(knoten('maneuver:man_tritt'), findsNothing);

    await tester.tap(kopf(_kopfWaffen));
    await tester.pumpAndSettle();
    // Ein Zweig mit Vorstufe bleibt als Skilltree erhalten.
    expect(knoten('maneuver:man_base'), findsOneWidget);
    expect(knoten('maneuver:man_next'), findsOneWidget);
    expect(knoten('maneuver:man_tritt'), findsNothing);

    await tester.tap(kopf(_kopfWaffen));
    await tester.pumpAndSettle();
    expect(knoten('maneuver:man_base'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Freistehende Fähigkeiten erscheinen als kompakte Kacheln', (
    tester,
  ) async {
    await open(tester, const Size(1100, 1000));
    await tester.tap(kopf(_kopfKampfGrundlagen));
    await tester.pumpAndSettle();
    final kachel = knoten('combatAbility:ksf_aufmerksamkeit');
    expect(kachel, findsOneWidget);
    expect(
      find.descendant(of: kachel, matching: find.text('10 AP')),
      findsOneWidget,
    );
    await tester.tap(kachel);
    await tester.pumpAndSettle();
    expect(find.text('+ Sonderfertigkeit'), findsOneWidget);
    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sprungleiste öffnet die Gruppe', (tester) async {
    await open(tester, const Size(1100, 1000));
    expect(knoten('maneuver:man_tritt'), findsNothing);
    await tester.tap(
      find.byKey(
        const ValueKey('advancement-group-jump-kampfWaffenlosManoever'),
      ),
    );
    await tester.pumpAndSettle();
    expect(knoten('maneuver:man_tritt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Suche öffnet Treffergruppen und blendet andere aus', (
    tester,
  ) async {
    await open(tester, const Size(1100, 1000));
    await tester.enterText(
      find.byKey(const ValueKey('advancement-search')),
      'Tritt',
    );
    await tester.pumpAndSettle();
    expect(knoten('maneuver:man_tritt'), findsOneWidget);
    expect(kopf(_kopfWaffenlos), findsOneWidget);
    expect(kopf(_kopfWaffen), findsNothing);
    expect(kopf(_kopfAllgemein), findsNothing);
  });

  testWidgets('Bereich und „Nur erlernbar“ schränken die Gruppen ein', (
    tester,
  ) async {
    await open(tester, const Size(1100, 1000));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Allgemein'));
    await tester.pumpAndSettle();
    expect(kopf(_kopfAllgemein), findsOneWidget);
    expect(kopf(_kopfWaffen), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Kampf'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('advancement-skill-tree-only-available')),
    );
    await tester.pumpAndSettle();
    // Niederwerfen ist gesperrt, der Zweig bleibt aber wegen Wuchtschlag.
    expect(knoten('maneuver:man_base'), findsOneWidget);
    expect(knoten('maneuver:man_next'), findsOneWidget);
    expect(kopf(_kopfAllgemein), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Schmale Anzeige bleibt ohne Überlauf bedienbar', (tester) async {
    await open(tester, const Size(390, 844));
    await tester.ensureVisible(kopf(_kopfKampfGrundlagen));
    await tester.pumpAndSettle();
    await tester.tap(kopf(_kopfKampfGrundlagen));
    await tester.pumpAndSettle();
    expect(knoten('combatAbility:ksf_aufmerksamkeit'), findsOneWidget);
    await tester.ensureVisible(kopf(_kopfWaffen));
    await tester.pumpAndSettle();
    await tester.tap(kopf(_kopfWaffen));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
