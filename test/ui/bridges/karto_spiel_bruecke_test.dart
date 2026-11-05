import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_attribute_card.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';

import '../../ui2/shell/karto_test_support.dart';

void main() {
  const adapter = KartoBestandsAdapterImpl();

  Future<ProviderContainer> oeffne(
    WidgetTester tester, {
    required FakeRepository repository,
    KartoRessource ressource = KartoRessource.lebensenergie,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repository),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => adapter.ressourceBearbeiten(
                  context: context,
                  heroId: 'rondra',
                  ressource: ressource,
                ),
                child: const Text('öffnen'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('Blatt nutzt den vorhandenen Vital-Block und speichert', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [testHero()],
      states: {'rondra': const HeroState.empty().copyWith(currentLep: 20)},
    );
    await oeffne(tester, repository: repo);
    expect(find.text('Lebenspunkte anpassen'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('vital-block-minus-5')));
    await tester.pumpAndSettle();
    final gespeichert = await repo.loadHeroState('rondra');
    expect(gespeichert!.currentLep, 15);
  });

  testWidgets('Untergrenze des Bestandswidgets erlaubt negative Werte', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: [testHero()],
      states: {'rondra': const HeroState.empty().copyWith(currentLep: 2)},
    );
    await oeffne(tester, repository: repo);
    await tester.tap(find.byKey(const ValueKey('vital-block-minus-5')));
    await tester.pumpAndSettle();
    final gespeichert = await repo.loadHeroState('rondra');
    expect(gespeichert!.currentLep, -3);
  });

  testWidgets('Speicherfehler erscheint und meldet keinen Erfolg', (
    tester,
  ) async {
    final repo = _SchreibfehlerRepository();
    await oeffne(tester, repository: repo);
    await tester.tap(find.byKey(const ValueKey('vital-block-minus-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('LeP nicht gespeichert'), findsOneWidget);
    expect(find.textContaining('übernommen'), findsNothing);
  });

  testWidgets('Blatt lässt sich wieder schließen', (tester) async {
    await oeffne(tester, repository: FakeRepository(heroes: [testHero()]));
    await tester.tap(find.byKey(const ValueKey('karto-ressource-schliessen')));
    await tester.pumpAndSettle();
    expect(find.text('Lebenspunkte anpassen'), findsNothing);
  });

  testWidgets('jede Ressource trägt ihren eigenen Titel', (tester) async {
    await oeffne(
      tester,
      repository: FakeRepository(heroes: [testHero()]),
      ressource: KartoRessource.karma,
    );
    expect(find.text('Karmapunkte anpassen'), findsOneWidget);
  });
  testWidgets('Ressourcenänderung erhält aktuellere fremde Zustandsfelder', (
    tester,
  ) async {
    final initial = const HeroState.empty().copyWith(
      currentLep: 20,
      currentAsp: 0,
    );
    final repo = FakeRepository(
      heroes: [testHero()],
      states: {'rondra': initial},
    );
    final container = await oeffne(tester, repository: repo);
    await repo.saveHeroState('rondra', initial.copyWith(currentAsp: 7));
    await tester.idle();
    expect(
      container
          .read(heroComputedProvider('rondra'))
          .requireValue
          .state
          .currentAsp,
      7,
    );
    await tester.tap(find.byKey(const ValueKey('vital-block-minus-1')));
    await tester.pumpAndSettle();
    final saved = await repo.loadHeroState('rondra');
    expect(saved!.currentLep, 19);
    expect(
      saved.currentAsp,
      7,
      reason: 'LeP ändern darf neue AsP nicht überschreiben',
    );
  });
  group('Eigenschafts-Schnellproben über die Brücke', () {
    Future<FakeRepository> zeigeProben(
      WidgetTester tester, {
      HeroState? zustand,
      KartoKachelGroesse? groesse,
      double breite = 900,
      double skalierung = 1,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(breite, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeRepository(
        heroes: [testHero()],
        states: {'rondra': ?zustand},
      );
      final container = ProviderContainer(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(skalierung)),
              child: child!,
            ),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final werte = ref
                      .watch(heroComputedProvider('rondra'))
                      .asData
                      ?.value;
                  if (werte == null) {
                    return const CircularProgressIndicator();
                  }
                  final proben = adapter.spielEigenschaftsproben(
                    heroId: 'rondra',
                    werte: werte,
                  );
                  // Wie in der Spielansicht liegt der Baustein in einer Kachel.
                  return groesse == null
                      ? proben
                      : KartoKachelSteuerung(
                          kennung: 'eigenschaften',
                          groesse: groesse,
                          child: proben,
                        );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('Abbrechen schreibt keinen Protokolleintrag', (tester) async {
      final repo = await zeigeProben(tester);
      await tester.tap(find.byKey(const ValueKey('inspector-probe-attr-MU')));
      await tester.pumpAndSettle();
      expect(find.textContaining('MU'), findsWidgets);
      await tester.tap(find.text('Schließen'));
      await tester.pumpAndSettle();
      final zustand = await repo.loadHeroState('rondra');
      expect(zustand?.diceLog ?? const [], isEmpty);
    });

    testWidgets('gewürfelte Probe landet im Protokoll', (tester) async {
      final repo = await zeigeProben(tester);
      await tester.tap(find.byKey(const ValueKey('inspector-probe-attr-MU')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Würfeln').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schließen'));
      await tester.pumpAndSettle();
      final zustand = await repo.loadHeroState('rondra');
      expect(zustand!.diceLog, isNotEmpty);
      expect(zustand.diceLog.last.title, contains('MU'));
    });

    testWidgets('Wunden senken den Probenwert und sind markiert', (
      tester,
    ) async {
      await zeigeProben(tester);
      final ohne = tester.widget<InspectorAttributeCard>(
        find.byKey(const ValueKey('inspector-probe-attr-GE')),
      );
      await tester.pumpWidget(const SizedBox());

      // Eine Beinwunde: GE −2 allgemein und −2 aus der Zone (WdS S. 108 f.).
      await zeigeProben(
        tester,
        zustand: const HeroState.empty().copyWith(
          wpiZustand: const WundZustand(
            wundenProZone: <WundZone, int>{WundZone.linkesBein: 1},
          ),
        ),
      );
      final ge = tester.widget<InspectorAttributeCard>(
        find.byKey(const ValueKey('inspector-probe-attr-GE')),
      );
      expect(ge.value, ohne.value - 4);
      expect(ge.wundAbzug, -4);
      expect(
        find.byTooltip('Wunden −4 (ohne Wunden ${ohne.value})'),
        findsOneWidget,
      );
      final mu = tester.widget<InspectorAttributeCard>(
        find.byKey(const ValueKey('inspector-probe-attr-MU')),
      );
      expect(mu.wundAbzug, 0);
    });

    // Beinwunde: GE −2 allgemein und −2 aus der Zone, zusammen −4.
    const beinwunde = HeroState(
      currentLep: 30,
      currentAsp: 0,
      currentKap: 0,
      currentAu: 30,
      wpiZustand: WundZustand(
        wundenProZone: <WundZone, int>{WundZone.linkesBein: 1},
      ),
    );

    Finder abzugAn(String label, String text) => find.descendant(
      of: find.byKey(ValueKey('inspector-probe-attr-$label')),
      matching: find.text(text),
    );

    testWidgets('weit zeigt den Wundabzug an der Karte, nicht nur im Tooltip', (
      tester,
    ) async {
      await zeigeProben(
        tester,
        zustand: beinwunde,
        groesse: KartoKachelGroesse.weit,
      );
      expect(abzugAn('GE', '\u22124'), findsOneWidget);
      // Der Tooltip bleibt zusätzlich bestehen.
      expect(find.byTooltip(RegExp(r'^Wunden −4')), findsOneWidget);
      // Eigenschaften ohne Abzug tragen keinen.
      expect(abzugAn('MU', '\u22124'), findsNothing);
      expect(find.textContaining('\u2212'), findsOneWidget);
    });

    for (final groesse in <KartoKachelGroesse?>[
      KartoKachelGroesse.kompakt,
      KartoKachelGroesse.normal,
      null,
    ]) {
      testWidgets('${groesse?.name ?? 'ohne Kachel'}: der Abzug steht nur im '
          'Tooltip', (tester) async {
        await zeigeProben(tester, zustand: beinwunde, groesse: groesse);
        expect(find.textContaining('\u2212'), findsNothing);
        expect(find.byTooltip(RegExp(r'^Wunden −4')), findsOneWidget);
      });
    }

    testWidgets('weit ohne Wunden zeigt keinen Abzug', (tester) async {
      await zeigeProben(tester, groesse: KartoKachelGroesse.weit);
      expect(find.textContaining('\u2212'), findsNothing);
    });

    for (final breite in [360.0, 600.0, 900.0, 1400.0]) {
      testWidgets('weit mit Abzug bei $breite dp, Schrift 2, ohne Überlauf', (
        tester,
      ) async {
        await zeigeProben(
          tester,
          zustand: beinwunde,
          groesse: KartoKachelGroesse.weit,
          breite: breite,
          skalierung: 2,
        );
        expect(tester.takeException(), isNull);
        expect(abzugAn('GE', '\u22124'), findsOneWidget);
      });
    }

    testWidgets('alle acht Eigenschaften stehen zur Verfügung', (tester) async {
      await zeigeProben(tester);
      for (final label in ['MU', 'KL', 'IN', 'CH', 'FF', 'GE', 'KO', 'KK']) {
        expect(
          find.byKey(ValueKey('inspector-probe-attr-$label')),
          findsOneWidget,
        );
      }
    });
  });
}

/// Repository, dessen Zustandsschreibweg fehlschlägt.
class _SchreibfehlerRepository extends FakeRepository {
  _SchreibfehlerRepository()
    : super(
        heroes: [testHero()],
        states: {'rondra': const HeroState.empty().copyWith(currentLep: 20)},
      );

  @override
  Future<void> saveHeroState(String heroId, HeroState state) async =>
      throw StateError('Schreibfehler');

  @override
  Future<void> saveHero(HeroSheet hero) async =>
      throw StateError('Schreibfehler');
}
