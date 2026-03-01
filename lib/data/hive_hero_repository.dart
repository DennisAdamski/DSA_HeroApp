import 'dart:async';

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
  final Map<String, HeroSheet> _heroIndex = <String, HeroSheet>{};
  final StreamController<Map<String, HeroSheet>> _heroIndexController =
      StreamController<Map<String, HeroSheet>>.broadcast();
  StreamSubscription<BoxEvent>? _heroEventSubscription;

  static Future<HiveHeroRepository> create() async {
    await Hive.initFlutter();
    final heroes = await Hive.openBox<Map>(_heroesBoxName);
    final states = await Hive.openBox<Map>(_statesBoxName);
    final repository = HiveHeroRepository._(heroes, states);
    repository._seedHeroIndex();
    repository._heroEventSubscription = repository._heroesBox.watch().listen(
      repository._handleHeroBoxEvent,
    );
    return repository;
  }

  void _seedHeroIndex() {
    _heroIndex.clear();
    for (final key in _heroesBox.keys) {
      final raw = _heroesBox.get(key);
      if (raw is! Map) {
        continue;
      }
      final hero = HeroSheet.fromJson(raw.cast<String, dynamic>());
      _heroIndex[hero.id] = hero;
    }
  }

  void _handleHeroBoxEvent(BoxEvent event) {
    final key = event.key?.toString();
    if (key == null || key.trim().isEmpty) {
      return;
    }
    final raw = event.value;
    if (raw is Map) {
      final hero = HeroSheet.fromJson(raw.cast<String, dynamic>());
      _heroIndex[hero.id] = hero;
      if (hero.id != key) {
        _heroIndex.remove(key);
      }
    } else {
      _heroIndex.remove(key);
    }
    _heroIndexController.add(_buildHeroIndexSnapshot());
  }

  Map<String, HeroSheet> _buildHeroIndexSnapshot() {
    return Map<String, HeroSheet>.unmodifiable(
      Map<String, HeroSheet>.from(_heroIndex),
    );
  }

  @override
  Stream<Map<String, HeroSheet>> watchHeroIndex() async* {
    yield _buildHeroIndexSnapshot();
    yield* _heroIndexController.stream;
  }

  @override
  Future<List<HeroSheet>> listHeroes() async {
    final heroes = _heroIndex.values.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
    return heroes;
  }

  @override
  Future<HeroSheet?> loadHeroById(String heroId) async {
    final cached = _heroIndex[heroId];
    if (cached != null) {
      return cached;
    }
    final raw = _heroesBox.get(heroId);
    if (raw is! Map) {
      return null;
    }
    final hero = HeroSheet.fromJson(raw.cast<String, dynamic>());
    _heroIndex[hero.id] = hero;
    return hero;
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
  Stream<HeroState> watchHeroState(String heroId) async* {
    yield (await loadHeroState(heroId)) ?? const HeroState.empty();
    await for (final event in _statesBox.watch(key: heroId)) {
      final raw = event.value;
      if (raw is! Map) {
        yield const HeroState.empty();
        continue;
      }
      yield HeroState.fromJson(raw.cast<String, dynamic>());
    }
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

  Future<void> close() async {
    await _heroEventSubscription?.cancel();
    await _heroIndexController.close();
  }
}
