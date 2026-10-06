import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_freigabe_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';

import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

Gefechtspruefung _p({
  Gefechtsfreigabe status = Gefechtsfreigabe.bereit,
  List<String> sperren = const [],
  List<String> fehlend = const [],
  List<String> entscheidungen = const [],
  List<String> hinweise = const [],
  int? zielwert,
}) => Gefechtspruefung(
  aktion: Gefechtsaktion.angriff,
  status: status,
  gruende: [...sperren, ...fehlend, ...entscheidungen, ...hinweise],
  sperrgruende: sperren,
  fehlendeAngaben: fehlend,
  entscheidungen: entscheidungen,
  hinweise: hinweise,
  zielwert: zielwert,
);

Future<(ProviderContainer, GefechtsTestBestand)> _ansicht(
  WidgetTester tester, {
  double breite = 1200,
  String? dk = 'N',
}) async {
  tester.view.physicalSize = Size(breite, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final snapshot = buildHeroComputedSnapshot(
    hero: testHero().copyWith(
      combatConfig: const CombatConfig(
        weapons: [MainWeaponSlot(id: 'a', name: 'Schwert', distanceClass: 'N')],
      ),
    ),
    state: const HeroState.empty(),
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
  container.read(gefechtProvider('rondra').notifier).beginnen(6, dk: dk);
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

void main() {
  test('Hauptgrund folgt Sperre, Angabe, Entscheidung, Hinweis', () {
    expect(gefechtsHauptgrund(_p()), isNull);
    expect(
      gefechtsHauptgrund(
        _p(
          status: Gefechtsfreigabe.gesperrt,
          sperren: ['Gesperrt.'],
          fehlend: ['Fehlt.'],
        ),
      ),
      'Gesperrt.',
    );
    expect(
      gefechtsHauptgrund(
        _p(
          status: Gefechtsfreigabe.pruefen,
          fehlend: ['Fehlt.'],
          entscheidungen: ['Klären.'],
        ),
      ),
      'Fehlt.',
    );
    expect(
      gefechtsHauptgrund(_p(entscheidungen: ['Klären.'], hinweise: ['Info.'])),
      'Klären.',
    );
    expect(gefechtsKnopfstatus(_p(zielwert: 14)), 'Würfeln · 14');
    expect(
      gefechtsKnopfstatus(
        _p(status: Gefechtsfreigabe.pruefen, entscheidungen: ['x']),
      ),
      'Klären',
    );
    expect(
      gefechtsKnopfstatus(_p(status: Gefechtsfreigabe.pruefen, fehlend: ['x'])),
      'Angabe fehlt',
    );
  });

  testWidgets('Knöpfe zeigen Zielwert oder ihren wichtigsten Grund', (
    tester,
  ) async {
    await _ansicht(tester);
    expect(find.textContaining('Würfeln · '), findsWidgets);
    expect(find.text('Angabe fehlt'), findsNothing);
  });

  testWidgets('Ohne DK nennt der Knopf die fehlende Angabe direkt', (
    tester,
  ) async {
    await _ansicht(tester, dk: null);
    expect(find.text('Angabe fehlt'), findsWidgets);
    expect(find.text('Tatsächliche DK und Waffen-DK festlegen.'), findsWidgets);
  });

  testWidgets('Schnellleiste öffnet die Attacke mit derselben Prüfung', (
    tester,
  ) async {
    final (container, bestand) = await _ansicht(tester, breite: 390);
    await tester.tap(find.byKey(const ValueKey('gefecht-leiste-attacke')));
    await tester.pumpAndSettle();
    expect(find.text('Angreifen'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('gefecht-auftrag-starten')));
    await tester.pumpAndSettle();
    expect(bestand.anfragen, hasLength(1));
    expect(container.read(gefechtProvider('rondra'))!.angriffeVerbraucht, 1);
    await tester.tap(find.byKey(const ValueKey('gefecht-leiste-runde')));
    await tester.pumpAndSettle();
    final s = container.read(gefechtProvider('rondra'))!;
    expect(s.runde, 2);
    expect(s.angriffeVerbraucht, 0);
  });
}
