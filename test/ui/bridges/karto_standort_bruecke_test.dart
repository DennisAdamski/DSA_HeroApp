import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

import '../../test_support/fake_repository.dart';

import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';

import '../../ui2/shell/karto_test_support.dart';

const _nebel = HeroAdventureEntry(
  id: 'nebel',
  title: 'Die Spuren im Nebel',
  currentAventurianDate: HeroAdventureDateValue(
    day: '7',
    month: 'boron',
    year: '1043',
  ),
);

void main() {
  const adapter = KartoBestandsAdapterImpl();

  Future<(FakeRepository, ProviderContainer, void Function(String))> baue(
    WidgetTester tester, {
    String standort = 'Gareth',
    List<HeroReiseStation> stationen = const <HeroReiseStation>[],
    bool planOffen = false,
  }) async {
    final held = testHero().copyWith(
      adventures: const [_nebel],
      reiseStationen: stationen,
    );
    final repo = FakeRepository(
      heroes: [held],
      states: {'rondra': const HeroState.empty().copyWith(standort: standort)},
    );
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      ],
    );
    addTearDown(container.dispose);
    if (planOffen) {
      container
          .read(advancementSessionProvider('rondra').notifier)
          .start(hero: held, catalog: testCatalog);
    }
    late BuildContext kontext;
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                kontext = context;
                widgetRef = ref;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    void setze(String neu) {
      adapter.standortSetzen(
        context: kontext,
        ref: widgetRef,
        heroId: 'rondra',
        standort: neu,
      );
    }

    return (repo, container, setze);
  }

  testWidgets('ein Ortswechsel legt eine Station der Reiseroute an', (
    tester,
  ) async {
    final (repo, _, setze) = await baue(tester);

    setze('Havena');
    await tester.pumpAndSettle();

    final zustand = await repo.loadHeroState('rondra');
    expect(zustand!.standort, 'Havena');
    final held = await repo.loadHeroById('rondra');
    final station = held!.reiseStationen.single;
    expect(station.ort, 'Havena');
    expect(station.adventureId, 'nebel');
    expect(station.datum.year, '1043');
  });

  testWidgets('derselbe Ort und das Entfernen legen keine Station an', (
    tester,
  ) async {
    final (repo, _, setze) = await baue(tester);

    setze('Gareth');
    await tester.pumpAndSettle();
    setze('');
    await tester.pumpAndSettle();

    final held = await repo.loadHeroById('rondra');
    expect(held!.reiseStationen, isEmpty);
    expect((await repo.loadHeroState('rondra'))!.standort, isEmpty);
  });

  testWidgets('zweimal derselbe neue Ort ergibt eine Station', (tester) async {
    final (repo, _, setze) = await baue(tester);

    setze('Havena');
    await tester.pumpAndSettle();
    setze('Gareth');
    await tester.pumpAndSettle();
    setze('Gareth');
    await tester.pumpAndSettle();

    final held = await repo.loadHeroById('rondra');
    expect([for (final s in held!.reiseStationen) s.ort], ['Havena', 'Gareth']);
  });

  testWidgets('während einer Planung bleibt der Standort, die Station fehlt', (
    tester,
  ) async {
    final (repo, _, setze) = await baue(tester, planOffen: true);

    setze('Havena');
    await tester.pumpAndSettle();

    expect((await repo.loadHeroState('rondra'))!.standort, 'Havena');
    expect((await repo.loadHeroById('rondra'))!.reiseStationen, isEmpty);
    expect(
      find.textContaining('Standort gespeichert, Reiseroute nicht ergänzt'),
      findsOneWidget,
    );
  });
}
