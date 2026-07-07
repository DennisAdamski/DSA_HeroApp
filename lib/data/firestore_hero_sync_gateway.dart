import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:dsa_heldenverwaltung/data/sync/hero_sync_record_codec.dart';
import 'package:dsa_heldenverwaltung/data/sync/remote_hero_sync_gateway.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

/// Firestore-Gateway fuer privaten Konto-Sync von Helden und Zustaenden.
class FirestoreHeroSyncGateway
    implements RemoteHeroSyncGateway, RemoteHeroStateSyncGateway {
  /// Erstellt das Gateway fuer den privaten User-Subtree.
  FirestoreHeroSyncGateway({required this.userId, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// UID des angemeldeten Firebase-Users.
  final String userId;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _heroesCollection =>
      _firestore.collection('users').doc(userId).collection('heroes');

  CollectionReference<Map<String, dynamic>> get _statesCollection =>
      _firestore.collection('users').doc(userId).collection('hero_states');

  @override
  Future<RemoteHeroRecord> deleteHero(
    String heroId, {
    required String? previousRevision,
  }) async {
    final revision = newSyncRevision();
    await _guardedSet(
      _heroesCollection.doc(heroId),
      encodeSyncTombstoneWriteFields(
        revision: revision,
        lastModifiedValue: FieldValue.serverTimestamp(),
      ),
      previousRevision: previousRevision,
      setOptions: SetOptions(merge: true),
    );
    return RemoteHeroRecord(
      id: heroId,
      hero: null,
      revision: revision,
      contentHash: '',
      isDeleted: true,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<RemoteHeroStateRecord> deleteHeroState(
    String heroId, {
    required String? previousRevision,
  }) async {
    final revision = newSyncRevision();
    await _guardedSet(
      _statesCollection.doc(heroId),
      encodeSyncTombstoneWriteFields(
        revision: revision,
        lastModifiedValue: FieldValue.serverTimestamp(),
      ),
      previousRevision: previousRevision,
      setOptions: SetOptions(merge: true),
    );
    return RemoteHeroStateRecord(
      heroId: heroId,
      state: null,
      revision: revision,
      contentHash: '',
      isDeleted: true,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<List<RemoteHeroRecord>> loadAllHeroes() async {
    final snapshot = await _mapFirestoreErrors(() => _heroesCollection.get());
    return snapshot.docs
        .map(_decodeHeroRecord)
        .whereType<RemoteHeroRecord>()
        .toList(growable: false);
  }

  @override
  Future<List<RemoteHeroStateRecord>> loadAllHeroStates() async {
    final snapshot = await _mapFirestoreErrors(() => _statesCollection.get());
    return snapshot.docs
        .map(_decodeStateRecord)
        .whereType<RemoteHeroStateRecord>()
        .toList(growable: false);
  }

  @override
  Future<RemoteHeroRecord?> loadHero(String heroId) async {
    final doc = await _mapFirestoreErrors(
      () => _heroesCollection.doc(heroId).get(),
    );
    return _decodeHeroRecord(doc);
  }

  @override
  Future<RemoteHeroStateRecord?> loadHeroState(String heroId) async {
    final doc = await _mapFirestoreErrors(
      () => _statesCollection.doc(heroId).get(),
    );
    return _decodeStateRecord(doc);
  }

  @override
  Future<RemoteHeroRecord> saveHero(
    HeroSheet hero, {
    required String? previousRevision,
  }) async {
    final contentHash = heroContentHash(hero);
    final revision = newSyncRevision();
    await _guardedSet(
      _heroesCollection.doc(hero.id),
      encodeSyncPayloadWriteFields(
        payload: hero.toJson(),
        revision: revision,
        contentHash: contentHash,
        lastModifiedValue: FieldValue.serverTimestamp(),
      ),
      previousRevision: previousRevision,
    );
    return RemoteHeroRecord(
      id: hero.id,
      hero: hero,
      revision: revision,
      contentHash: contentHash,
      isDeleted: false,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<RemoteHeroStateRecord> saveHeroState(
    String heroId,
    HeroState state, {
    required String? previousRevision,
  }) async {
    final payload = state.toJson();
    final contentHash = stableContentHash(payload);
    final revision = newSyncRevision();
    await _guardedSet(
      _statesCollection.doc(heroId),
      encodeSyncPayloadWriteFields(
        payload: payload,
        revision: revision,
        contentHash: contentHash,
        lastModifiedValue: FieldValue.serverTimestamp(),
      ),
      previousRevision: previousRevision,
    );
    return RemoteHeroStateRecord(
      heroId: heroId,
      state: state,
      revision: revision,
      contentHash: contentHash,
      isDeleted: false,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Stream<List<RemoteHeroRecord>> watchHeroes() {
    return _mapStreamErrors(_heroesCollection.snapshots()).map((snapshot) {
      return snapshot.docs
          .map(_decodeHeroRecord)
          .whereType<RemoteHeroRecord>()
          .toList(growable: false);
    });
  }

  @override
  Stream<List<RemoteHeroStateRecord>> watchHeroStates() {
    return _mapStreamErrors(_statesCollection.snapshots()).map((snapshot) {
      return snapshot.docs
          .map(_decodeStateRecord)
          .whereType<RemoteHeroStateRecord>()
          .toList(growable: false);
    });
  }

  RemoteHeroRecord? _decodeHeroRecord(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      return null;
    }
    return decodeRemoteHeroRecord(
      id: doc.id,
      data: data,
      updatedAt: _readTimestamp(data[HeroSyncRecordFields.lastModified]),
    );
  }

  RemoteHeroStateRecord? _decodeStateRecord(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      return null;
    }
    return decodeRemoteHeroStateRecord(
      heroId: doc.id,
      data: data,
      updatedAt: _readTimestamp(data[HeroSyncRecordFields.lastModified]),
    );
  }

  DateTime? _readTimestamp(Object? raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    return null;
  }

  /// Schreibt ein Dokument und erzwingt [previousRevision] serverseitig.
  ///
  /// Mit gesetzter Revision laeuft der Write als Transaktion: Die aktuelle
  /// Revision wird gelesen und bei Abweichung eine [SyncPreconditionException]
  /// geworfen, ohne zu schreiben. Ohne Revision bleibt es beim direkten
  /// `set()` (bewusst z. B. fuer frisch angelegte Dokumente und
  /// `keepBoth`-Kopien; behaelt ausserdem das Offline-Queueing des Plugins).
  Future<void> _guardedSet(
    DocumentReference<Map<String, dynamic>> docRef,
    Map<String, dynamic> fields, {
    required String? previousRevision,
    SetOptions? setOptions,
  }) async {
    if (previousRevision == null) {
      await _mapFirestoreErrors(() => docRef.set(fields, setOptions));
      return;
    }
    await _mapFirestoreErrors(
      () => _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        final data = snapshot.data();
        final currentRevision = snapshot.exists && data != null
            ? readSyncRevision(
                data,
                _readTimestamp(data[HeroSyncRecordFields.lastModified]),
              )
            : null;
        if (currentRevision != previousRevision) {
          throw SyncPreconditionException(
            'Remote-Revision hat sich geändert '
            '($previousRevision -> $currentRevision).',
            expectedRevision: previousRevision,
            actualRevision: currentRevision,
          );
        }
        transaction.set(docRef, fields, setOptions);
      }),
    );
  }

  /// Führt eine Firestore-Operation aus und übersetzt [FirebaseException]s
  /// in typisierte Sync-Fehler.
  Future<T> _mapFirestoreErrors<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  /// Übersetzt Fehler eines Firestore-Streams in typisierte Sync-Fehler.
  Stream<T> _mapStreamErrors<T>(Stream<T> stream) {
    return stream.transform(
      StreamTransformer<T, T>.fromHandlers(
        handleError: (error, stackTrace, sink) {
          if (error is FirebaseException) {
            sink.addError(_mapFirebaseException(error), stackTrace);
            return;
          }
          sink.addError(error, stackTrace);
        },
      ),
    );
  }

  Object _mapFirebaseException(FirebaseException error) {
    final message = error.message ?? 'Firestore-Fehler (${error.code}).';
    switch (error.code) {
      case 'unauthenticated':
      case 'permission-denied':
        return SyncAuthException(message, cause: error);
      case 'unavailable':
      case 'deadline-exceeded':
        return SyncNetworkException(message, cause: error);
      case 'aborted':
      case 'failed-precondition':
        return SyncPreconditionException(message, cause: error);
      default:
        return error;
    }
  }
}
