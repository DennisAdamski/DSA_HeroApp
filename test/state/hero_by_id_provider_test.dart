import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

void main() {
  HeroSheet buildHero(String id, String name) {
    return HeroSheet(
      id: id,
      name: name,
      level: 1,
      attributes: const Attributes(
        mu: 8,
        kl: 8,
        inn: 8,
        ch: 8,
        ff: 8,
        ge: 8,
        ko: 8,
        kk: 8,
      ),
    );
  }

  ProviderContainer buildContainer(FakeRepository repo) {
    final container = ProviderContainer(
      overrides: [heroRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('findHeroById returns hero or null', () {
    final heroes = <HeroSheet>[
      buildHero('h-1', 'A'),
      buildHero('h-2', 'B'),
    ];

    expect(findHeroById(heroes, 'h-2')?.name, 'B');
    expect(findHeroById(heroes, 'missing'), isNull);
  });

  test('heroByIdProvider resolves existing hero after list load', () async {
    final repo = FakeRepository(
      heroes: <HeroSheet>[
        buildHero('h-1', 'A'),
        buildHero('h-2', 'B'),
      ],
    );
    final container = buildContainer(repo);

    final heroListSub = container.listen<AsyncValue<List<HeroSheet>>>(
      heroListProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(heroListSub.close);
    for (var attempt = 0; attempt < 20; attempt++) {
      if (heroListSub.read().hasValue) {
        break;
      }
      await container.pump();
    }
    expect(heroListSub.read().hasValue, isTrue);
    final hero = container.read(heroByIdProvider('h-2'));

    expect(hero, isNotNull);
    expect(hero!.name, 'B');
  });

  test('heroByIdProvider and heroByIdFutureProvider return null for missing id', () async {
    final repo = FakeRepository(heroes: <HeroSheet>[buildHero('h-1', 'A')]);
    final container = buildContainer(repo);

    final heroListSub = container.listen<AsyncValue<List<HeroSheet>>>(
      heroListProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(heroListSub.close);
    for (var attempt = 0; attempt < 20; attempt++) {
      if (heroListSub.read().hasValue) {
        break;
      }
      await container.pump();
    }
    expect(heroListSub.read().hasValue, isTrue);
    expect(container.read(heroByIdProvider('missing')), isNull);
    expect(await container.read(heroByIdFutureProvider('missing').future), isNull);
  });
}
