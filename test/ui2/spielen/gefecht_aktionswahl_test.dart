import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';

import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

Future<(ProviderContainer, GefechtsTestBestand)> _ansicht(
  WidgetTester tester, {
  int lep = 30,
}) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final snapshot = buildHeroComputedSnapshot(
    hero: testHero().copyWith(
      combatConfig: const CombatConfig(
        weapons: [MainWeaponSlot(id: 'a', name: 'Schwert', distanceClass: 'N')],
      ),
    ),
    state: HeroState(
      currentLep: lep,
      currentAsp: 0,
      currentKap: 0,
      currentAu: 30,
    ),
    catalog: testCatalog,
    epicAdvantagesActive: false,
  );
  final container = ProviderContainer(
    overrides: [
      heroComputedProvider('rondra').overrideWith((ref) => AsyncData(snapshot)),
      rulesCatalogProvider.overrideWith((ref) async => testCatalog),
    ],
  );
  addTearDown(container.dispose);
  container.read(gefechtProvider('rondra').notifier).beginnen(6, dk: 'N');
  final bestand = GefechtsTestBestand();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: GefechtAnsicht(heroId: 'rondra', bestand: bestand),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container, bestand);
}

Future<void> _waehlen(WidgetTester tester, String name) async {
  final knopf = find.byKey(const ValueKey('gefecht-aktionswahl'));
  await tester.ensureVisible(knopf);
  await tester.tap(knopf);
  await tester.pumpAndSettle();
  final eintrag = find.byKey(ValueKey('gefecht-aktion-$name'));
  await tester.ensureVisible(eintrag);
  await tester.pumpAndSettle();
  await tester.tap(eintrag);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Bewegen bucht eine Aktion und setzt die Rundenmarke', (
    tester,
  ) async {
    final (container, _) = await _ansicht(tester);
    await _waehlen(tester, 'bewegen');
    final s = container.read(gefechtProvider('rondra'))!;
    expect(s.bewegt, isTrue);
    expect(s.angriffeVerbraucht + s.paradenVerbraucht, 1);
  });

  testWidgets('Gelungenes Hinwerfen kostet eine freie Aktion und legt hin', (
    tester,
  ) async {
    final (container, bestand) = await _ansicht(tester);
    bestand.w20Wert = 1;
    await _waehlen(tester, 'zuBodenWerfen');
    final s = container.read(gefechtProvider('rondra'))!;
    expect(bestand.anfragen.single.title, contains('GE'));
    expect(s.haltung, Gefechtshaltung.liegend);
    expect(s.freieVerbraucht, 1);
    expect(s.iniVerlust, 0);
    expect(s.auftrag, isNull);
  });

  testWidgets('Niedrige LeP zeigen das Kampfunfähigkeitsbanner', (
    tester,
  ) async {
    await _ansicht(tester, lep: 4);
    expect(find.textContaining('kampfunfähig'), findsWidgets);
  });
}
