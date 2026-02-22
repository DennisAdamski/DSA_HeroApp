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

  @override
  Future<void> deleteHero(String heroId) async {
    _heroes.removeWhere((hero) => hero.id == heroId);
    _states.remove(heroId);
  }

  @override
  Future<List<HeroSheet>> listHeroes() async => List<HeroSheet>.of(_heroes);

  @override
  Future<HeroState?> loadHeroState(String heroId) async => _states[heroId];

  @override
  Future<void> saveHero(HeroSheet hero) async {
    _heroes.removeWhere((item) => item.id == hero.id);
    _heroes.add(hero);
  }

  @override
  Future<void> saveHeroState(String heroId, HeroState state) async {
    _states[heroId] = state;
  }
}
