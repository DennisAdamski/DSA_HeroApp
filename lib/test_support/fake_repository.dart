import 'dart:async';

import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';

class FakeRepository implements HeroRepository {
  FakeRepository({List<HeroSheet>? heroes, Map<String, HeroState>? states})
    : _heroes = heroes ?? <HeroSheet>[],
      _states = states ?? <String, HeroState>{};

  factory FakeRepository.empty() => FakeRepository();

  final List<HeroSheet> _heroes;
  final Map<String, HeroState> _states;
  final StreamController<Map<String, HeroSheet>> _heroIndexController =
      StreamController<Map<String, HeroSheet>>.broadcast();
  final Map<String, StreamController<HeroState>> _stateControllers =
      <String, StreamController<HeroState>>{};

  Map<String, HeroSheet> _heroIndexMap() {
    return Map<String, HeroSheet>.unmodifiable(<String, HeroSheet>{
      for (final hero in _heroes) hero.id: hero,
    });
  }

  StreamController<HeroState> _stateControllerFor(String heroId) {
    return _stateControllers.putIfAbsent(
      heroId,
      () => StreamController<HeroState>.broadcast(),
    );
  }

  @override
  Future<void> deleteHero(String heroId) async {
    _heroes.removeWhere((hero) => hero.id == heroId);
    _states.remove(heroId);
    _heroIndexController.add(_heroIndexMap());
    _stateControllerFor(heroId).add(const HeroState.empty());
  }

  @override
  Stream<Map<String, HeroSheet>> watchHeroIndex() async* {
    yield _heroIndexMap();
    yield* _heroIndexController.stream;
  }

  @override
  Future<List<HeroSheet>> listHeroes() async =>
      List<HeroSheet>.of(_heroes)..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<HeroSheet?> loadHeroById(String heroId) async {
    for (final hero in _heroes) {
      if (hero.id == heroId) {
        return hero;
      }
    }
    return null;
  }

  @override
  Stream<HeroState> watchHeroState(String heroId) async* {
    yield _states[heroId] ?? const HeroState.empty();
    yield* _stateControllerFor(heroId).stream;
  }

  @override
  Future<HeroState?> loadHeroState(String heroId) async => _states[heroId];

  @override
  Future<void> saveHero(HeroSheet hero) async {
    _heroes.removeWhere((item) => item.id == hero.id);
    _heroes.add(hero);
    _heroIndexController.add(_heroIndexMap());
  }

  @override
  Future<void> saveHeroState(String heroId, HeroState state) async {
    _states[heroId] = state;
    _stateControllerFor(heroId).add(state);
  }
}
