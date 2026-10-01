import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_einstieg.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';

import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

void main() {
  for (final aufmerksamkeit in [false, true]) {
    for (final klingentaenzer in [false, true]) {
      testWidgets(
        'Start Aufmerksamkeit=$aufmerksamkeit Klingentänzer=$klingentaenzer; Navigation erhält Sitzung',
        (tester) async {
          final held = testHero().copyWith(
            combatConfig: CombatConfig(
              specialRules: CombatSpecialRules(
                aufmerksamkeit: aufmerksamkeit,
                klingentaenzer: klingentaenzer,
              ),
            ),
          );
          final snapshot = buildHeroComputedSnapshot(
            hero: held,
            state: const HeroState.empty(),
            catalog: testCatalog,
            epicAdvantagesActive: false,
          );
          final container = ProviderContainer(
            overrides: [
              heroComputedProvider('rondra')
                  .overrideWith((ref) => AsyncData(snapshot)),
              rulesCatalogProvider.overrideWith((ref) async => testCatalog),
            ],
          );
          addTearDown(container.dispose);
          final bestand = GefechtsTestBestand();
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                home: Scaffold(
                  body: GefechtEinstieg(
                    heroId: 'rondra',
                    werte: snapshot,
                    bestand: bestand,
                    aktion: (f) => f(),
                    vorBearbeitung: () async => true,
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Gefecht beginnen'));
          await tester.pumpAndSettle();
          expect(find.byType(GefechtAnsicht), findsOneWidget);
          expect(bestand.anfragen.length, aufmerksamkeit ? 0 : 1);
          if (!aufmerksamkeit) {
            expect(
              bestand.anfragen.single.diceSpec.count,
              klingentaenzer ? 2 : 1,
            );
          }
          expect(
            container.read(gefechtProvider('rondra'))!.iniWurf,
            klingentaenzer ? 12 : 6,
          );
          tester.state<NavigatorState>(find.byType(Navigator).first).pop();
          await tester.pumpAndSettle();
          expect(find.text('Gefecht läuft'), findsOneWidget);
          await tester.tap(find.text('Gefecht läuft'));
          await tester.pumpAndSettle();
          expect(bestand.anfragen.length, aufmerksamkeit ? 0 : 1);
          await tester.tap(find.text('Beenden').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Beenden').last);
          await tester.pumpAndSettle();
          expect(container.read(gefechtProvider('rondra')), isNull);
          expect(find.text('Gefecht beginnen'), findsOneWidget);
        },
      );
    }
  }
  for (final abbrechen in [false, true]) {
    testWidgets(
      'Aktionsauftrag Abbruch=$abbrechen; Doppelcallback bucht nur einmal',
      (tester) async {
        final snapshot = buildHeroComputedSnapshot(
          hero: testHero().copyWith(
            combatConfig: const CombatConfig(
              weapons: [MainWeaponSlot(name: 'Schwert', distanceClass: 'N')],
            ),
          ),
          state: const HeroState.empty(),
          catalog: testCatalog,
          epicAdvantagesActive: false,
        );
        final container = ProviderContainer(
          overrides: [
            heroComputedProvider('rondra')
                .overrideWith((ref) => AsyncData(snapshot)),
            rulesCatalogProvider.overrideWith((ref) async => testCatalog),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(gefechtProvider('rondra').notifier);
        controller.beginnen(6);
        controller.setzen(
          container.read(gefechtProvider('rondra'))!.copyWith(dk: 'N'),
        );
        final bestand = GefechtsTestBestand()
          ..abbrechen = abbrechen
          ..doppelt = true;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: GefechtAnsicht(heroId: 'rondra', bestand: bestand),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Angreifen').first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('gefecht-kontext-bestaetigen')),
        );
        await tester.tap(
          find.byKey(const ValueKey('gefecht-kontext-bestaetigen')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('gefecht-auftrag-starten')));
        await tester.tap(find.byKey(const ValueKey('gefecht-auftrag-starten')));
        await tester.pumpAndSettle();
        expect(bestand.anfragen.length, 1);
        expect(
          container.read(gefechtProvider('rondra'))!.angriffeVerbraucht,
          abbrechen ? 0 : 1,
        );
        expect(container.read(gefechtProvider('rondra'))!.auftrag, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
