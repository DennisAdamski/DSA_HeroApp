import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';

import '../../rules/gefecht_ansagen_paket2_test.dart' as fixture;
import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

void main() {
  for (final schritte in [1, -1, 2, -2]) {
    testWidgets('Eigene DK-Aktion $schritte verwendet AT und freien Schritt', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final snap = fixture.ansageSnapshot(sf: true);
      final container = ProviderContainer(
        overrides: [
          heroComputedProvider('rondra').overrideWith((ref) => AsyncData(snap)),
          rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        ],
      );
      addTearDown(container.dispose);
      final ctl = container.read(gefechtProvider('rondra').notifier)
        ..beginnen(6);
      final dk = schritte > 0 ? 'N' : 'S';
      ctl.setzen(container.read(gefechtProvider('rondra'))!.copyWith(dk: dk));
      final bestand = GefechtsTestBestand()..w20Wert = 1;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: GefechtAnsicht(heroId: 'rondra', bestand: bestand),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Angreifen'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('gefecht-angriffsabsicht')),
        findsNothing,
      );
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      final entry = find.text('Distanzklasse ändern');
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('gefecht-wuchtschlag')), findsNothing);
      expect(find.byKey(const ValueKey('gefecht-fk-ansage')), findsNothing);
      expect(find.byKey(const ValueKey('gefecht-finte')), findsOneWidget);
      final selector = find.byKey(const ValueKey('gefecht-distanzschritte'));
      final dropdown = tester.widget<DropdownButtonFormField<int>>(selector);
      expect(dropdown.initialValue, -1);
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      final label = switch (schritte) {
        -1 => 'Eine DK annähern (kein Schaden)',
        -2 => 'Zwei DK annähern (+8)',
        1 => 'Eine DK entfernen (+4)',
        _ => 'Zwei DK entfernen (+8)',
      };
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('gefecht-auftrag-starten')));
      await tester.pumpAndSettle();
      if (schritte < 0) {
        expect(find.text('Annäherung abwickeln'), findsOneWidget);
        expect(container.read(gefechtProvider('rondra'))!.dk, dk);
        await tester.tap(find.text('Nicht abgewehrt'));
        await tester.pumpAndSettle();
      }
      final result = container.read(gefechtProvider('rondra'))!;
      expect(result.dk, switch (schritte) {
        1 => 'S',
        2 => 'P',
        -1 => 'N',
        _ => 'H',
      });
      expect(result.angriffeVerbraucht, 1);
      expect(result.freieVerbraucht, 1);
      expect(result.paradenVerbraucht, 0);
      expect(bestand.anfragen, hasLength(1));
      final zuschlag = schritte > 0
          ? schritte * 4
          : schritte == -2
          ? 8
          : 0;
      expect(
        bestand.anfragen.single.targets.single.value,
        gefechtswerteFuer(snap).at - zuschlag,
      );
      expect(result.angriffsergebnisse.every((e) => e.tpBonus == 0), true);
      expect(
        find.byKey(const ValueKey('gefecht-angriffsschaden')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final fall in [
    'Abbrechen',
    'Probeabbruch',
    'Keine Schritte',
    'Abgewehrt',
    'Misslungen',
  ]) {
    testWidgets('DK-Dialog: $fall verändert keine Distanz', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final snap = fixture.ansageSnapshot(sf: true);
      final container = ProviderContainer(
        overrides: [
          heroComputedProvider('rondra').overrideWith((ref) => AsyncData(snap)),
          rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        ],
      );
      addTearDown(container.dispose);
      final ctl = container.read(gefechtProvider('rondra').notifier)
        ..beginnen(6);
      ctl.setzen(
        container
            .read(gefechtProvider('rondra'))!
            .copyWith(
              dk: 'S',
              freieVerbraucht: fall == 'Keine Schritte' ? 2 : 0,
            ),
      );
      final bestand = GefechtsTestBestand()
        ..w20Wert = fall == 'Misslungen' ? 20 : 1
        ..abbrechen = fall == 'Probeabbruch';
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: GefechtAnsicht(heroId: 'rondra', bestand: bestand),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final entry = find.text('Distanzklasse ändern');
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      if (fall == 'Keine Schritte') {
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('gefecht-auftrag-starten')),
              )
              .onPressed,
          isNull,
        );
        expect(
          find.byKey(const ValueKey('gefecht-ausfuehrung-gruende')),
          findsOneWidget,
        );
        expect(find.textContaining('freie Aktion'), findsWidgets);
      }
      if (fall == 'Abbrechen' || fall == 'Keine Schritte') {
        await tester.tap(find.text('Abbrechen'));
      } else {
        await tester.tap(find.byKey(const ValueKey('gefecht-auftrag-starten')));
        await tester.pumpAndSettle();
        if (fall == 'Abgewehrt') await tester.tap(find.text('Abgewehrt'));
      }
      await tester.pumpAndSettle();
      final result = container.read(gefechtProvider('rondra'))!;
      expect(result.dk, 'S');
      final bezahlt = fall == 'Misslungen' || fall == 'Abgewehrt';
      expect(result.angriffeVerbraucht, bezahlt ? 1 : 0);
      expect(
        result.freieVerbraucht,
        fall == 'Keine Schritte'
            ? 2
            : bezahlt
            ? 1
            : 0,
      );
      expect(result.auftrag, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
