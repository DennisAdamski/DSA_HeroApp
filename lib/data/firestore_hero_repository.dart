import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';

/// Firestore-basierter Remote-Speicher fuer Helden eines Benutzers.
///
/// Helden werden unter `users/{userId}/heroes/{heroId}` abgelegt; Laufzeit-
/// zustaende unter `users/{userId}/hero_states/{heroId}`. Das Wrapping-
/// Dokument enthaelt:
///   - `payload` ... vollstaendiges HeroSheet-/HeroState-JSON
///   - `lastModified` ... `serverTimestamp()` fuer Konflikt-Aufloesung
///
/// Dieses Repository implementiert bewusst NICHT [HeroRepository] — es ist
/// die Remote-Seite eines [HybridHeroRepository] und wird nur ueber dieses
/// genutzt.
class FirestoreHeroRepository {
  FirestoreHeroRepository({
    required this.userId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String userId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _heroesCollection =>
      _firestore.collection('users').doc(userId).collection('heroes');

  CollectionReference<Map<String, dynamic>> get _statesCollection =>
      _firestore.collection('users').doc(userId).collection('hero_states');

  /// Liest alle Helden des Users einmalig.
  Future<List<HeroSheet>> loadAllHeroes() async {
    final snapshot = await _heroesCollection.get();
    return snapshot.docs
        .map(_decodeHero)
        .whereType<HeroSheet>()
        .toList(growable: false);
  }

  /// Reaktiver Stream aller Helden des Users.
  Stream<Map<String, HeroSheet>> watchHeroIndex() {
    return _heroesCollection.snapshots().map((snapshot) {
      final result = <String, HeroSheet>{};
      for (final doc in snapshot.docs) {
        final hero = _decodeHero(doc);
        if (hero != null) {
          result[hero.id] = hero;
        }
      }
      return Map<String, HeroSheet>.unmodifiable(result);
    });
  }

  /// Speichert einen Helden im Firestore (Upsert).
  Future<void> saveHero(HeroSheet hero) async {
    await _heroesCollection.doc(hero.id).set({
      'payload': hero.toJson(),
      'lastModified': FieldValue.serverTimestamp(),
    });
  }

  /// Loescht einen Helden samt Zustand.
  Future<void> deleteHero(String heroId) async {
    await _heroesCollection.doc(heroId).delete();
    // Best-effort: Zustand entfernen, falls vorhanden.
    final stateDoc = await _statesCollection.doc(heroId).get();
    if (stateDoc.exists) {
      await _statesCollection.doc(heroId).delete();
    }
  }

  /// Speichert den Laufzeitzustand eines Helden.
  Future<void> saveHeroState(String heroId, HeroState state) async {
    await _statesCollection.doc(heroId).set({
      'payload': state.toJson(),
      'lastModified': FieldValue.serverTimestamp(),
    });
  }

  /// Liest den Laufzeitzustand eines Helden einmalig.
  Future<HeroState?> loadHeroState(String heroId) async {
    final doc = await _statesCollection.doc(heroId).get();
    return _decodeState(doc);
  }

  /// Reaktiver Stream des Laufzeitzustands.
  Stream<HeroState?> watchHeroState(String heroId) {
    return _statesCollection.doc(heroId).snapshots().map(_decodeState);
  }

  HeroSheet? _decodeHero(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return null;
    }
    final payload = data['payload'];
    if (payload is! Map) {
      return null;
    }
    return HeroSheet.fromJson(_castMap(payload));
  }

  HeroState? _decodeState(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return null;
    }
    final payload = data['payload'];
    if (payload is! Map) {
      return null;
    }
    return HeroState.fromJson(_castMap(payload));
  }

  Map<String, dynamic> _castMap(Map<dynamic, dynamic> raw) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
}
