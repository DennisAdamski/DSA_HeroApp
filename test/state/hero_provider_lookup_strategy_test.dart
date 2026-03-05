import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

class _SpyRepository implements HeroRepository {
  _SpyRepository(this._heroesById);

  final Map<String, HeroSheet> _heroesById;
  int listHeroesCalls = 0;
  int loadHeroByIdCalls = 0;

  @override
  Stream<Map<String, HeroSheet>> watchHeroIndex() async* {
    yield Map<String, HeroSheet>.from(_heroesById);
  }

  @override
  Future<List<HeroSheet>> listHeroes() async {
    listHeroesCalls++;
    return _heroesById.values.toList(growable: false);
  }

  @override
  Future<HeroSheet?> loadHeroById(String heroId) async {
    loadHeroByIdCalls++;
    return _heroesById[heroId];
  }

  @override
  Future<void> saveHero(HeroSheet hero) async {
    _heroesById[hero.id] = hero;
  }

  @override
  Future<void> deleteHero(String heroId) async {
    _heroesById.remove(heroId);
  }

  @override
  Stream<HeroState> watchHeroState(String heroId) async* {
    yield const HeroState.empty();
  }

  @override
  Future<HeroState?> loadHeroState(String heroId) async {
    return const HeroState.empty();
  }

  @override
  Future<void> saveHeroState(String heroId, HeroState state) async {}
}

void main() {
  HeroSheet buildHero(String id) {
    return HeroSheet(
      id: id,
      name: id,
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

  test('heroById providers avoid list scan and use index/loadById', () async {
    final repo = _SpyRepository(<String, HeroSheet>{'h-1': buildHero('h-1')});
    final container = ProviderContainer(
      overrides: [heroRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final heroIndexSub = container.listen(
      heroIndexProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(heroIndexSub.close);
    for (var attempt = 0; attempt < 20; attempt++) {
      if (heroIndexSub.read().hasValue) {
        break;
      }
      await container.pump();
    }
    expect(heroIndexSub.read().hasValue, isTrue);
    expect(repo.listHeroesCalls, 0);

    final byId = container.read(heroByIdProvider('h-1'));
    expect(byId, isNotNull);
    expect(repo.listHeroesCalls, 0);

    final byIdFuture = await container.read(
      heroByIdFutureProvider('h-1').future,
    );
    expect(byIdFuture, isNotNull);
    expect(repo.loadHeroByIdCalls, 1);
    expect(repo.listHeroesCalls, 0);
  });
}
