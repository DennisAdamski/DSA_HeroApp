import 'dart:async';

import 'package:hive/hive.dart';

import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';

/// Hive-basierte Implementierung von [HeroRepository].
///
/// Persistiert Helden in der Box `heroes_v1` und Zustaende in `hero_states_v1`.
/// Haelt einen In-Memory-Index ([_heroIndex]) aktuell, der ueber
/// Hive-Box-Events synchron gehalten wird.
/// Wird ueber [create] asynchron initialisiert.
class HiveHeroRepository implements HeroRepository {
  HiveHeroRepository._(this._heroesBox, this._statesBox);

  static const _heroesBoxName = 'heroes_v1';
  static const _statesBoxName = 'hero_states_v1';

  final Box<Map> _heroesBox;
  final Box<Map> _statesBox;

  /// In-Memory-Index aller gespeicherten Helden fuer schnellen Zugriff.
  final Map<String, HeroSheet> _heroIndex = <String, HeroSheet>{};

  /// Broadcast-Stream der bei jeder Indexaenderung einen Snapshot ausgibt.
  final StreamController<Map<String, HeroSheet>> _heroIndexController =
      StreamController<Map<String, HeroSheet>>.broadcast();

  StreamSubscription<BoxEvent>? _heroEventSubscription;

  /// Erstellt und initialisiert das Repository asynchron.
  ///
  /// Oeffnet die Boxen im angegebenen [storagePath], baut den In-Memory-Index
  /// auf und abonniert Box-Events fuer reaktive Updates.
  static Future<HiveHeroRepository> create({
    required String storagePath,
  }) async {
    final heroes = await Hive.openBox<Map>(
      _heroesBoxName,
      path: storagePath,
    );
    final states = await Hive.openBox<Map>(
      _statesBoxName,
      path: storagePath,
    );
    final repository = HiveHeroRepository._(heroes, states);
    repository._seedHeroIndex();
    repository._heroEventSubscription = repository._heroesBox.watch().listen(
      repository._handleHeroBoxEvent,
    );
    return repository;
  }

  /// Laedt alle vorhandenen Helden aus der Box in den In-Memory-Index.
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

  /// Verarbeitet ein Hive-Box-Event und aktualisiert den In-Memory-Index.
  ///
  /// Loescht den alten Eintrag, falls sich die Held-ID veraendert hat.
  /// Gibt anschliessend einen neuen Snapshot in [_heroIndexController] aus.
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

  /// Erstellt einen unveraenderlichen Snapshot des aktuellen Index.
  Map<String, HeroSheet> _buildHeroIndexSnapshot() {
    return Map<String, HeroSheet>.unmodifiable(
      Map<String, HeroSheet>.from(_heroIndex),
    );
  }

  /// Gibt einen Stream von Heldenindex-Snapshots aus.
  ///
  /// Gibt sofort den aktuellen Stand aus, danach bei jeder Aenderung.
  @override
  Stream<Map<String, HeroSheet>> watchHeroIndex() async* {
    yield _buildHeroIndexSnapshot();
    yield* _heroIndexController.stream;
  }

  /// Gibt alle Helden alphabetisch sortiert nach Name zurueck.
  @override
  Future<List<HeroSheet>> listHeroes() async {
    final heroes = _heroIndex.values.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
    return heroes;
  }

  /// Sucht einen Helden zuerst im In-Memory-Index, dann in der Box.
  ///
  /// Gibt `null` zurueck wenn kein Held mit [heroId] gefunden wird.
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

  /// Speichert einen Helden dauerhaft in der Box.
  ///
  /// Der In-Memory-Index wird durch das resultierende Box-Event aktualisiert.
  @override
  Future<void> saveHero(HeroSheet hero) async {
    await _heroesBox.put(hero.id, hero.toJson());
  }

  /// Loescht einen Helden und seinen Zustand dauerhaft.
  ///
  /// Entfernt Eintraege aus beiden Boxen (`heroes_v1` und `hero_states_v1`).
  @override
  Future<void> deleteHero(String heroId) async {
    await _heroesBox.delete(heroId);
    await _statesBox.delete(heroId);
  }

  /// Gibt einen reaktiven Stream des Helden-Laufzeitzustands aus.
  ///
  /// Gibt sofort den aktuellen Zustand aus (oder [HeroState.empty] wenn keiner vorhanden).
  /// Folgt danach allen Aenderungen in der Zustands-Box.
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

  /// Laedt den Laufzeitzustand eines Helden einmalig aus der Box.
  ///
  /// Gibt `null` zurueck wenn kein Zustand gespeichert ist.
  @override
  Future<HeroState?> loadHeroState(String heroId) async {
    final raw = _statesBox.get(heroId);
    if (raw == null) {
      return null;
    }
    return HeroState.fromJson(raw.cast<String, dynamic>());
  }

  /// Speichert den Laufzeitzustand eines Helden dauerhaft.
  @override
  Future<void> saveHeroState(String heroId, HeroState state) async {
    await _statesBox.put(heroId, state.toJson());
  }

  /// Gibt alle Stream-Subscriptions und den StreamController frei.
  ///
  /// Muss beim App-Ende aufgerufen werden um Ressourcenlecks zu vermeiden.
  Future<void> close() async {
    await _heroEventSubscription?.cancel();
    await _heroIndexController.close();
    await _heroesBox.close();
    await _statesBox.close();
  }
}
