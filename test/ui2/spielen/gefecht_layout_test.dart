import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';

import '../shell/karto_test_support.dart';

void main() {
  for (final breite in [390.0, 820.0, 1200.0, 1440.0]) {
    for (final helligkeit in Brightness.values) {
      testWidgets(
        'Gefecht $breite $helligkeit ohne Überlauf und Ressourcen nach Aktionen',
        (tester) async {
          tester.view.physicalSize = Size(breite, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final snapshot = buildHeroComputedSnapshot(
            hero: testHero(),
            state: const HeroState(
              currentLep: 30,
              currentAsp: 0,
              currentKap: 0,
              currentAu: 30,
            ),
            epicAdvantagesActive: false,
            catalog: testCatalog,
          );
          final container = ProviderContainer(
            overrides: [
              heroComputedProvider('rondra')
                  .overrideWith((ref) => AsyncData(snapshot)),
              rulesCatalogProvider.overrideWith((ref) async => testCatalog),
            ],
          );
          addTearDown(container.dispose);
          container.read(gefechtProvider('rondra').notifier).beginnen(6);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: ThemeData(brightness: helligkeit),
                home: GefechtAnsicht(heroId: 'rondra', bestand: TestBestand()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Runde 1'), findsOneWidget);
          expect(find.text('Angriff'), findsWidgets);
          expect(find.text('Vitalwerte'), findsOneWidget);
          expect(tester.takeException(), isNull);
          final leiste = find.byKey(const ValueKey('gefecht-leiste-attacke'));
          if (breite == 390) {
            // Schmal: Vitalwerte vor den Aktionen, Verteidigung direkt nach
            // dem Angriff und eine feste Schnellleiste.
            double oben(Finder f) => tester.getTopLeft(f).dy;
            expect(
              oben(find.text('Vitalwerte')),
              lessThan(oben(find.text('Angriff').first)),
            );
            expect(
              oben(find.text('Angriff').first),
              lessThan(oben(find.text('Verteidigung').first)),
            );
            expect(
              oben(find.text('Verteidigung').first),
              lessThan(oben(find.text('Manöver').first)),
            );
            expect(leiste, findsOneWidget);
          } else {
            expect(leiste, findsNothing);
          }
        },
      );
    }
  }
}
