import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';

import '../../rules/gefecht_ansagen_paket2_test.dart' as fixture;
import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

void main() {
  for (final zweiterErfolg in [false, true]) {
    testWidgets(
      'Offene Treffer nach zweiter AT Erfolg=$zweiterErfolg bleiben einzeln gebunden',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final snapshot = fixture.ansageSnapshot(sf: true, kampfgespuer: true);
        var aktuell = snapshot;
        final container = ProviderContainer(
          overrides: [
            heroComputedProvider('rondra')
                .overrideWith((ref) => AsyncData(aktuell)),
            rulesCatalogProvider.overrideWith((ref) async => testCatalog),
          ],
        );
        addTearDown(container.dispose);
        final ctl = container.read(gefechtProvider('rondra').notifier)
          ..beginnen(6);
        ctl.setzen(
          container.read(gefechtProvider('rondra'))!.copyWith(dk: 'N'),
        );
        final bestand = GefechtsTestBestand()
          ..w20Wert = 1
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
        await tester.enterText(
          find.byKey(const ValueKey('gefecht-finte')),
          '3',
        );
        final wucht = find.byKey(const ValueKey('gefecht-wuchtschlag'));
        await tester.ensureVisible(wucht);
        await tester.enterText(wucht, '4');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('gefecht-auftrag-starten')));
        await tester.pumpAndSettle();
        expect(bestand.anfragen, hasLength(1));
        expect(
          container.read(gefechtProvider('rondra'))!.angriffeVerbraucht,
          1,
        );
        expect(
          container.read(gefechtProvider('rondra'))!.angriffsergebnis!.tpBonus,
          4,
        );
        final andereWaffe = snapshot.hero.combatConfig.selectedWeapon.copyWith(
          id: 'b',
          name: 'Axt',
          tpFlat: 20,
        );
        aktuell = buildHeroComputedSnapshot(
          hero: snapshot.hero.copyWith(
            combatConfig: snapshot.hero.combatConfig.copyWith(
              weapons: [andereWaffe],
            ),
          ),
          state: const HeroState.empty(),
          catalog: testCatalog,
          epicAdvantagesActive: false,
        );
        container.invalidate(heroComputedProvider('rondra'));
        await tester.pumpAndSettle();
        final ersterTreffer = container
            .read(gefechtProvider('rondra'))!
            .angriffsergebnis!;
        final umwandlung = find.text('2 AT');
        await tester.ensureVisible(umwandlung);
        await tester.tap(umwandlung);
        await tester.pumpAndSettle();
        bestand.w20Wert = zweiterErfolg ? 1 : 20;
        final zweiteAt = find.textContaining('Angreifen').first;
        await tester.ensureVisible(zweiteAt);
        await tester.tap(zweiteAt);
        await tester.pumpAndSettle();
        final zweiteWucht = find.byKey(const ValueKey('gefecht-wuchtschlag'));
        await tester.ensureVisible(zweiteWucht);
        await tester.enterText(zweiteWucht, '2');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('gefecht-auftrag-starten')),
              )
              .onPressed,
          isNotNull,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .join(' '),
        );
        await tester.tap(find.byKey(const ValueKey('gefecht-auftrag-starten')));
        await tester.pumpAndSettle();
        expect(
          container
              .read(gefechtProvider('rondra'))!
              .angriffsergebnisse
              .first
              .auftragId,
          ersterTreffer.auftragId,
          reason: 'Ein Fehlschlag darf den vorherigen Treffer nicht löschen.',
        );
        expect(
          container.read(gefechtProvider('rondra'))!.angriffsergebnisse,
          hasLength(zweiterErfolg ? 2 : 1),
        );
        final allgemein = find.text('Schaden würfeln');
        await tester.ensureVisible(allgemein);
        await tester.tap(allgemein);
        await tester.pumpAndSettle();
        expect(bestand.anfragen.last.type, ProbeType.damage);
        expect(
          bestand.anfragen.last.diceSpec.modifier,
          aktuell.combatPreviewStats.damageDiceSpec.modifier,
        );
        final gebunden = find
            .byKey(const ValueKey('gefecht-angriffsschaden'))
            .first;
        await tester.ensureVisible(gebunden);
        await tester.tap(gebunden);
        await tester.pumpAndSettle();
        expect(bestand.anfragen.last.subtitle, contains('Schwert'));
        expect(
          bestand.anfragen.last.diceSpec.modifier,
          snapshot.combatPreviewStats.damageDiceSpec.modifier + 4,
        );
        if (zweiterErfolg) {
          expect(
            container.read(gefechtProvider('rondra'))!.angriffsergebnisse,
            hasLength(1),
          );
          final zweiterSchaden = find.byKey(
            const ValueKey('gefecht-angriffsschaden'),
          );
          await tester.ensureVisible(zweiterSchaden);
          await tester.tap(zweiterSchaden);
          await tester.pumpAndSettle();
          expect(bestand.anfragen.last.subtitle, contains('Axt'));
          expect(
            bestand.anfragen.last.diceSpec.modifier,
            aktuell.combatPreviewStats.damageDiceSpec.modifier + 2,
          );
        }
        expect(
          container.read(gefechtProvider('rondra'))!.angriffsergebnis,
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
