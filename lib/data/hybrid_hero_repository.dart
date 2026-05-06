import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:dsa_heldenverwaltung/data/firestore_hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/hive_hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';

/// Kombiniert lokales [HiveHeroRepository] mit optionalem
/// [FirestoreHeroRepository].
///
/// - Reads: immer aus dem lokalen Hive (schnell, offline verfuegbar).
/// - Writes: write-through auf beide; Remote-Fehler verwerfen die lokale
///   Aenderung nicht.
/// - Remote-Listener: spiegelt eingehende Aenderungen zurueck nach Hive.
/// - Bootstrap: zieht beim Start einmal alle Remote-Helden, pusht lokale
///   Helden hoch, die remote noch nicht existieren.
///
/// Remote-Loeschungen werden in v1 NICHT automatisch nach lokal propagiert;
/// das verhindert Datenverlust durch zeitweise Listener-Inkonsistenzen.
class HybridHeroRepository implements HeroRepository {
  HybridHeroRepository._(this._local, this._remote);

  final HiveHeroRepository _local;
  final FirestoreHeroRepository? _remote;
  StreamSubscription<Map<String, HeroSheet>>? _remoteSub;

  /// Erstellt das hybride Repository und fuehrt initiale Reconciliation aus.
  static Future<HybridHeroRepository> create({
    required HiveHeroRepository local,
    FirestoreHeroRepository? remote,
  }) async {
    final repo = HybridHeroRepository._(local, remote);
    if (remote != null) {
      await repo._reconcileOnce();
      repo._startRemoteListener();
    }
    return repo;
  }

  /// Einmaliger Abgleich: Remote → Lokal, dann lokale Sonderlinge → Remote.
  Future<void> _reconcileOnce() async {
    final remote = _remote;
    if (remote == null) {
      return;
    }
    try {
      final remoteHeroes = await remote.loadAllHeroes();
      final remoteIds = <String>{};
      for (final hero in remoteHeroes) {
        remoteIds.add(hero.id);
        await _writeLocalIfDifferent(hero);
      }
      final localHeroes = await _local.listHeroes();
      for (final hero in localHeroes) {
        if (!remoteIds.contains(hero.id)) {
          await remote.saveHero(hero);
        }
      }
    } on Object catch (error, stackTrace) {
      _logRemoteError('Reconcile fehlgeschlagen', error, stackTrace);
    }
  }

  void _startRemoteListener() {
    final remote = _remote;
    if (remote == null) {
      return;
    }
    _remoteSub = remote.watchHeroIndex().listen(
      (heroes) async {
        for (final hero in heroes.values) {
          await _writeLocalIfDifferent(hero);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _logRemoteError('Remote-Listener-Fehler', error, stackTrace);
      },
    );
  }

  Future<void> _writeLocalIfDifferent(HeroSheet remoteHero) async {
    final existing = await _local.loadHeroById(remoteHero.id);
    if (existing != null &&
        jsonEncode(existing.toJson()) == jsonEncode(remoteHero.toJson())) {
      return;
    }
    await _local.saveHero(remoteHero);
  }

  void _logRemoteError(String message, Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'hybrid_hero_repository',
        context: ErrorDescription(message),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HeroRepository — Lesepfade
  // ---------------------------------------------------------------------------

  @override
  Stream<Map<String, HeroSheet>> watchHeroIndex() => _local.watchHeroIndex();

  @override
  Future<List<HeroSheet>> listHeroes() => _local.listHeroes();

  @override
  Future<HeroSheet?> loadHeroById(String heroId) =>
      _local.loadHeroById(heroId);

  @override
  Stream<HeroState> watchHeroState(String heroId) =>
      _local.watchHeroState(heroId);

  @override
  Future<HeroState?> loadHeroState(String heroId) =>
      _local.loadHeroState(heroId);

  // ---------------------------------------------------------------------------
  // HeroRepository — Schreibpfade (write-through)
  // ---------------------------------------------------------------------------

  @override
  Future<void> saveHero(HeroSheet hero) async {
    await _local.saveHero(hero);
    final remote = _remote;
    if (remote == null) {
      return;
    }
    try {
      await remote.saveHero(hero);
    } on Object catch (error, stackTrace) {
      _logRemoteError('Remote-saveHero fehlgeschlagen', error, stackTrace);
    }
  }

  @override
  Future<void> deleteHero(String heroId) async {
    await _local.deleteHero(heroId);
    final remote = _remote;
    if (remote == null) {
      return;
    }
    try {
      await remote.deleteHero(heroId);
    } on Object catch (error, stackTrace) {
      _logRemoteError('Remote-deleteHero fehlgeschlagen', error, stackTrace);
    }
  }

  @override
  Future<void> saveHeroState(String heroId, HeroState state) async {
    await _local.saveHeroState(heroId, state);
    final remote = _remote;
    if (remote == null) {
      return;
    }
    try {
      await remote.saveHeroState(heroId, state);
    } on Object catch (error, stackTrace) {
      _logRemoteError('Remote-saveHeroState fehlgeschlagen', error, stackTrace);
    }
  }

  /// Beendet alle Remote-Subscriptions.
  Future<void> close() async {
    await _remoteSub?.cancel();
    _remoteSub = null;
  }
}
