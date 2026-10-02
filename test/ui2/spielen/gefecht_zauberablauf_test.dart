import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';

import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

void main() {
  for (final kosten in [1, 2]) {
    for (final abbrechen in [false, true]) {
      testWidgets('Zauber Dauer zwei und Kosten $kosten: Abbruch=$abbrechen', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1200, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final katalog = RulesCatalog(
          version: 'test',
          source: 'test',
          talents: [],
          weapons: [],
          maneuvers: [],
          spells: [
            SpellDef.fromJson({
              'id': 'spell_blitz',
              'name': 'Blitz',
              'attributes': ['MU', 'KL', 'IN'],
              'castingTime': '2 Aktionen',
            }),
          ],
        );
        final snapshot = buildHeroComputedSnapshot(
          hero: testHero().copyWith(
            resourceActivationConfig: const HeroResourceActivationConfig(
              magicEnabledOverride: true,
            ),
            spells: {
              'spell_blitz': const HeroSpellEntry(spellValue: 7, modifier: 2),
            },
          ),
          state: const HeroState.empty(),
          catalog: katalog,
          epicAdvantagesActive: false,
        );
        final container = ProviderContainer(
          overrides: [
            heroComputedProvider('rondra')
                .overrideWith((ref) => AsyncData(snapshot)),
            rulesCatalogProvider.overrideWith((ref) async => katalog),
          ],
        );
        addTearDown(container.dispose);
        container.read(gefechtProvider('rondra').notifier).beginnen(6);
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
        await tester.ensureVisible(find.text('Blitz · prüfen'));
        await tester.tap(find.text('Blitz · prüfen'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Weiter'));
        await tester.pumpAndSettle();
        final zahlen = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(zahlen.at(1), '2');
        await tester.enterText(zahlen.at(2), '$kosten');
        await tester.ensureVisible(
          find.byKey(const ValueKey('gefecht-kontext-bestaetigen')),
        );
        await tester.tap(
          find.byKey(const ValueKey('gefecht-kontext-bestaetigen')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('gefecht-auftrag-starten')));
        await tester.pumpAndSettle();
        if (kosten == 1) {
          expect(bestand.anfragen, isEmpty);
          expect(
            container.read(gefechtProvider('rondra'))!.handlung!.probe,
            isNotNull,
          );
          await tester.ensureVisible(find.text('Fortsetzen'));
          await tester.tap(find.text('Fortsetzen'));
          await tester.pumpAndSettle();
        }
        expect(bestand.anfragen.length, 1);
        expect(bestand.anfragen.single.basePool, 9);
        expect(bestand.anfragen.single.targets.map((t) => t.value), [
          14,
          12,
          13,
        ]);
        final s = container.read(gefechtProvider('rondra'))!;
        expect(s.angriffeVerbraucht, kosten == 1 || !abbrechen ? 1 : 0);
        expect(s.paradenVerbraucht, abbrechen ? 0 : 1);
        if (kosten == 1 && abbrechen) {
          expect(s.handlung!.verbleibend, 1);
        } else {
          expect(s.handlung, isNull);
        }
        expect(s.auftrag, isNull);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
