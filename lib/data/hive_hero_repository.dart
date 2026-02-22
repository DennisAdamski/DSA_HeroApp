import 'package:hive_flutter/hive_flutter.dart';

import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';

class HiveHeroRepository implements HeroRepository {
  HiveHeroRepository._(this._heroesBox, this._statesBox);

  static const _heroesBoxName = 'heroes_v1';
  static const _statesBoxName = 'hero_states_v1';

  final Box<Map> _heroesBox;
  final Box<Map> _statesBox;

  static Future<HiveHeroRepository> create() async {
    await Hive.initFlutter();
    final heroes = await Hive.openBox<Map>(_heroesBoxName);
    final states = await Hive.openBox<Map>(_statesBoxName);
    return HiveHeroRepository._(heroes, states);
  }

  @override
  Future<List<HeroSheet>> listHeroes() async {
    final heroes = _heroesBox.values
        .map((entry) => HeroSheet.fromJson(entry.cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return heroes;
  }

  @override
  Future<void> saveHero(HeroSheet hero) async {
    await _heroesBox.put(hero.id, hero.toJson());
  }

  @override
  Future<void> deleteHero(String heroId) async {
    await _heroesBox.delete(heroId);
    await _statesBox.delete(heroId);
  }

  @override
  Future<HeroState?> loadHeroState(String heroId) async {
    final raw = _statesBox.get(heroId);
    if (raw == null) {
      return null;
    }
    return HeroState.fromJson(raw.cast<String, dynamic>());
  }

  @override
  Future<void> saveHeroState(String heroId, HeroState state) async {
    await _statesBox.put(heroId, state.toJson());
  }
}
