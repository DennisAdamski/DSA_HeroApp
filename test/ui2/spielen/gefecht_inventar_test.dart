import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';

import '../../test_support/bogen_test_repository.dart';
import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

const _trank = HeroInventoryEntry(
  gegenstand: 'Heiltrank',
  anzahl: '2',
  itemType: InventoryItemType.verbrauchsgegenstand,
);

HeroSheet _held([HeroInventoryEntry? extra]) => testHero().copyWith(
  combatConfig: const CombatConfig(
    weapons: [MainWeaponSlot(id: 'a', name: 'Schwert', distanceClass: 'N')],
  ),
  inventoryEntries: [_trank, ?extra],
  companions: const [
    HeroCompanion(
      id: 'h',
      name: 'Hasso',
      ini: 12,
      angriffe: [HeroCompanionAttack(id: 'b', name: 'Biss', at: 11, tp: '1W6')],
    ),
  ],
);

Future<(ProviderContainer, BogenTestRepository)> _ansicht(
  WidgetTester tester, {
  HeroInventoryEntry? extra,
}) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final held = _held(extra);
  final repo = BogenTestRepository(heroes: [held]);
  final snapshot = buildHeroComputedSnapshot(
    hero: held,
    state: const HeroState(
      currentLep: 30,
      currentAsp: 0,
      currentKap: 0,
      currentAu: 30,
    ),
    catalog: testCatalog,
    epicAdvantagesActive: false,
  );
  final container = ProviderContainer(
    overrides: [
      heroRepositoryProvider.overrideWithValue(repo),
      heroComputedProvider('rondra').overrideWith((ref) => AsyncData(snapshot)),
      rulesCatalogProvider.overrideWith((ref) async => testCatalog),
    ],
  );
  addTearDown(container.dispose);
  container.read(gefechtProvider('rondra').notifier).beginnen(6, dk: 'N');
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: GefechtAnsicht(heroId: 'rondra', bestand: GefechtsTestBestand()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container, repo);
}

Future<void> _tippe(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

const _armschiene = HeroInventoryEntry(
  gegenstand: 'Armschiene',
  isMagisch: true,
  artefaktDaten: ArtefaktDaten(
    ausloeserAktionen: 2,
    zauber: <ArtefaktZauber>[ArtefaktZauber(name: 'Gardianum', kostenAsp: 9)],
  ),
);

void main() {
  testWidgets('Matrixgeber mit einer Aktion öffnet sofort den Auslösedialog', (
    tester,
  ) async {
    final (container, repo) = await _ansicht(
      tester,
      extra: _armschiene.copyWith(
        artefaktDaten: _armschiene.artefaktDaten!.copyWith(
          ausloeserAktionen: 1,
        ),
      ),
    );
    await _tippe(tester, find.byKey(const ValueKey('gefecht-inventar')));
    // Der Trank steht unter „Verbrauchsgüter“, der Matrixgeber danach.
    await _tippe(tester, find.widgetWithText(TextButton, 'Benutzen').last);

    // Kein Aufbewahrungsdialog und keine Abbuchungsfrage.
    expect(
      find.byKey(const ValueKey('gefecht-gegenstand-starten')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('gefecht-gegenstand-abbuchen')),
      findsNothing,
    );
    expect(find.text('Armschiene auslösen'), findsOneWidget);
    final s = container.read(gefechtProvider('rondra'))!;
    expect(s.angriffeVerbraucht + s.paradenVerbraucht, 1);
    expect(s.handlung, isNull);
    expect(repo.bogenSpeicherungen, 0);
  });

  testWidgets('Matrixgeber mit zwei Aktionen bleibt bis zum Abschluss offen', (
    tester,
  ) async {
    final (container, repo) = await _ansicht(tester, extra: _armschiene);
    await _tippe(tester, find.byKey(const ValueKey('gefecht-inventar')));
    await _tippe(tester, find.widgetWithText(TextButton, 'Benutzen').last);

    expect(find.text('Armschiene auslösen'), findsNothing);
    final s = container.read(gefechtProvider('rondra'))!;
    expect(s.angriffeVerbraucht + s.paradenVerbraucht, 1);
    expect(s.handlung?.verbleibend, 1);
    expect(s.handlung?.gegenstand?.gegenstand, 'Armschiene');
    expect(repo.bogenSpeicherungen, 0);
  });

  testWidgets('Griffbereiter Trank: eine Aktion, Abbuchung frisch', (
    tester,
  ) async {
    final (container, repo) = await _ansicht(tester);
    // Ein anderer Schreibweg ändert den Namen; er muss erhalten bleiben.
    repo.fremdeAenderung = (h) => h.copyWith(name: 'Rondra die Kühne');
    await _tippe(tester, find.byKey(const ValueKey('gefecht-inventar')));
    expect(find.text('Verbrauchsgüter'), findsOneWidget);
    await _tippe(tester, find.widgetWithText(TextButton, 'Benutzen'));
    await _tippe(
      tester,
      find.byKey(const ValueKey('gefecht-aufbewahrung-griffbereit')),
    );
    await _tippe(
      tester,
      find.byKey(const ValueKey('gefecht-gegenstand-starten')),
    );
    await _tippe(
      tester,
      find.byKey(const ValueKey('gefecht-gegenstand-abbuchen')),
    );
    final s = container.read(gefechtProvider('rondra'))!;
    expect(s.angriffeVerbraucht + s.paradenVerbraucht, 1);
    expect(s.handlung, isNull);
    final gespeichert = await repo.gespeichert('rondra');
    // Die Normalisierung ergänzt den verknüpften Waffeneintrag; der Trank
    // ist genau einmal abgebucht.
    expect(
      gespeichert.inventoryEntries
          .singleWhere((e) => e.gegenstand == 'Heiltrank')
          .anzahl,
      '1',
    );
    expect(gespeichert.name, 'Rondra die Kühne');
  });

  testWidgets('Gürteltasche bleibt als Handlung offen und bucht noch nicht', (
    tester,
  ) async {
    final (container, repo) = await _ansicht(tester);
    await _tippe(tester, find.byKey(const ValueKey('gefecht-inventar')));
    await _tippe(tester, find.widgetWithText(TextButton, 'Benutzen'));
    await _tippe(
      tester,
      find.byKey(const ValueKey('gefecht-gegenstand-starten')),
    );
    final s = container.read(gefechtProvider('rondra'))!;
    expect(s.handlung?.verbleibend, 9);
    expect(s.handlung?.gegenstand?.gegenstand, 'Heiltrank');
    expect(repo.bogenSpeicherungen, 0);
  });

  testWidgets('Letztes Fortsetzen fragt nach der Abbuchung', (tester) async {
    final (container, repo) = await _ansicht(tester);
    final ctl = container.read(gefechtProvider('rondra').notifier);
    ctl.setzen(
      container
          .read(gefechtProvider('rondra'))!
          .copyWith(
            handlung: const Gefechtshandlung(
              titel: 'Gegenstand benutzen · Heiltrank',
              verbleibend: 1,
              gegenstand: _trank,
            ),
          ),
    );
    await tester.pumpAndSettle();
    await _tippe(tester, find.widgetWithText(FilledButton, 'Fortsetzen'));
    await _tippe(
      tester,
      find.byKey(const ValueKey('gefecht-gegenstand-abbuchen')),
    );
    expect(container.read(gefechtProvider('rondra'))!.handlung, isNull);
    final gespeichert = await repo.gespeichert('rondra');
    expect(
      gespeichert.inventoryEntries
          .singleWhere((e) => e.gegenstand == 'Heiltrank')
          .anzahl,
      '1',
    );
  });

  testWidgets('Begleiter erscheinen mit wirksamen Werten', (tester) async {
    await _ansicht(tester);
    expect(find.text('Begleiter'), findsOneWidget);
    await _tippe(tester, find.text('Hasso'));
    expect(find.textContaining('Biss · AT 11'), findsOneWidget);
  });
}
