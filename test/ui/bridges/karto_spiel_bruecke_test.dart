import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_base_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';

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
