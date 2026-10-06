import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';

import '../shell/karto_test_support.dart';

void main() {
  const gesund = HeroState(
    currentLep: 30,
    currentAsp: 12,
    currentKap: 9,
    currentAu: 30,
  );
  for (final helligkeit in Brightness.values) {
    testWidgets(
      'Kompakte Vitalwerte bleiben bei Ressourcenänderung geschlossen $helligkeit',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var state = gesund.copyWith(
          wpiZustand: const WundZustand(
            wundenProZone: {WundZone.brust: 2},
            unterdrueckteWundenProZone: {WundZone.brust: 2},
          ),
        );
        final bestand = TestBestand();
        final container = ProviderContainer(
          overrides: [
            heroComputedProvider('rondra').overrideWith((ref) {
              return AsyncData(
                buildHeroComputedSnapshot(
                  hero: testHero().copyWith(
                    resourceActivationConfig:
                        const HeroResourceActivationConfig(
                          magicEnabledOverride: true,
                          divineEnabledOverride: true,
                        ),
                  ),
                  state: state,
                  catalog: testCatalog,
                  epicAdvantagesActive: false,
                ),
              );
            }),
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
              home: GefechtAnsicht(heroId: 'rondra', bestand: bestand),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Vitalwerte'), findsOneWidget);
        expect(find.textContaining('LeP 30 /'), findsOneWidget);
        expect(find.textContaining('AsP 12 /'), findsOneWidget);
        expect(find.text('Brust: 2 Wunden'), findsOneWidget);
        expect(find.text('Schaden erhalten'), findsNothing);
        expect(find.text('Effekte verwalten'), findsNothing);
        expect(find.text('Ausdauer'), findsNothing);
        expect(find.text('Karmapunkte'), findsNothing);
        expect(tester.takeException(), isNull);

        // Auch ein jetzt kritischer LeP-Stand respektiert die geschlossene Karte.
        state = state.copyWith(currentLep: 5, currentAsp: 8);
        container.invalidate(heroComputedProvider('rondra'));
        await tester.pumpAndSettle();
        expect(find.textContaining('LeP 5 /'), findsOneWidget);
        expect(find.textContaining('AsP 8 /'), findsOneWidget);
        expect(find.text('Schaden erhalten'), findsNothing);

        await tester.ensureVisible(find.text('Vitalwerte'));
        await tester.tap(find.text('Vitalwerte'));
        await tester.pumpAndSettle();
        expect(find.text('Schaden erhalten'), findsOneWidget);
        expect(find.text('Zustand rondra'), findsOneWidget);
        expect(find.text('Effekte rondra'), findsOneWidget);
        expect(find.text('Ausdauer'), findsOneWidget);
        expect(find.text('Karmapunkte'), findsOneWidget);
        expect(tester.takeException(), isNull);

        final ressourcen = find.byTooltip('Lebenspunkte ändern');
        await tester.ensureVisible(ressourcen);
        await tester.tap(ressourcen);
        await tester.pumpAndSettle();
        expect(bestand.aufrufe, contains('ressource:rondra:lebensenergie'));
        state = state.copyWith(currentLep: 30);
        container.invalidate(heroComputedProvider('rondra'));
        await tester.pumpAndSettle();
        expect(find.text('Schaden erhalten'), findsOneWidget);
        await tester.ensureVisible(find.text('Schaden erhalten'));
        await tester.tap(find.text('Schaden erhalten'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Effekte verwalten'));
        await tester.tap(find.text('Effekte verwalten'));
        await tester.pumpAndSettle();
        expect(bestand.aufrufe, contains('schadenErhalten:rondra'));
        expect(bestand.aufrufe, contains('effekte:rondra'));

        await tester.ensureVisible(find.text('Vitalwerte'));
        await tester.tap(find.text('Vitalwerte'));
        await tester.pumpAndSettle();
        state = state.copyWith(currentLep: 4);
        container.invalidate(heroComputedProvider('rondra'));
        await tester.pumpAndSettle();
        expect(find.text('Schaden erhalten'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final wunde in [false, true]) {
    testWidgets(
      'Kritische Vitalwerte öffnen initial und bleiben nach Heilung offen, Wunde $wunde',
      (tester) async {
        var state = wunde
            ? gesund.copyWith(
                wpiZustand: const WundZustand(
                  wundenProZone: {WundZone.brust: 1},
                ),
              )
            : gesund.copyWith(currentLep: 5);
        final container = ProviderContainer(
          overrides: [
            heroComputedProvider('rondra').overrideWith(
              (ref) => AsyncData(
                buildHeroComputedSnapshot(
                  hero: testHero(),
                  state: state,
                  catalog: testCatalog,
                  epicAdvantagesActive: false,
                ),
              ),
            ),
            rulesCatalogProvider.overrideWith((ref) async => testCatalog),
          ],
        );
        addTearDown(container.dispose);
        container.read(gefechtProvider('rondra').notifier).beginnen(6);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: GefechtAnsicht(heroId: 'rondra', bestand: TestBestand()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Vitalwerte'), findsOneWidget);
        expect(find.text('Schaden erhalten'), findsOneWidget);
        state = gesund;
        container.invalidate(heroComputedProvider('rondra'));
        await tester.pumpAndSettle();
        expect(find.text('Schaden erhalten'), findsOneWidget);
        expect(find.textContaining('AsP '), findsNothing);
        expect(find.textContaining('Wunden'), findsNothing);
      },
    );
  }
}
