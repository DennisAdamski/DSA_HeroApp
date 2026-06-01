import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/data/sync/remote_hero_sync_gateway.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

/// Firestore-Gateway fuer privaten Konto-Sync von Helden und Zustaenden.
class FirestoreHeroSyncGateway
    implements RemoteHeroSyncGateway, RemoteHeroStateSyncGateway {
  /// Erstellt das Gateway fuer den privaten User-Subtree.
  FirestoreHeroSyncGateway({required this.userId, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const Uuid _uuid = Uuid();

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
    final revision = _newRevision();
    await _heroesCollection.doc(heroId).set(<String, dynamic>{
      'deleted': true,
      'payload': null,
      'revision': revision,
      'contentHash': '',
      'lastModified': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    final revision = _newRevision();
    await _statesCollection.doc(heroId).set(<String, dynamic>{
      'deleted': true,
      'payload': null,
      'revision': revision,
      'contentHash': '',
      'lastModified': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    final snapshot = await _heroesCollection.get();
    return snapshot.docs
        .map(_decodeHeroRecord)
        .whereType<RemoteHeroRecord>()
        .toList(growable: false);
  }

  @override
  Future<List<RemoteHeroStateRecord>> loadAllHeroStates() async {
    final snapshot = await _statesCollection.get();
    return snapshot.docs
        .map(_decodeStateRecord)
        .whereType<RemoteHeroStateRecord>()
        .toList(growable: false);
  }

  @override
  Future<RemoteHeroRecord?> loadHero(String heroId) async {
    final doc = await _heroesCollection.doc(heroId).get();
    return _decodeHeroRecord(doc);
  }

  @override
  Future<RemoteHeroStateRecord?> loadHeroState(String heroId) async {
    final doc = await _statesCollection.doc(heroId).get();
    return _decodeStateRecord(doc);
  }

  @override
  Future<RemoteHeroRecord> saveHero(
    HeroSheet hero, {
    required String? previousRevision,
  }) async {
    final payload = hero.toJson();
    final contentHash = heroContentHash(hero);
    final revision = _newRevision();
    await _heroesCollection.doc(hero.id).set(<String, dynamic>{
      'deleted': false,
      'payload': payload,
      'revision': revision,
      'contentHash': contentHash,
      'lastModified': FieldValue.serverTimestamp(),
    });
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
    final revision = _newRevision();
    await _statesCollection.doc(heroId).set(<String, dynamic>{
      'deleted': false,
      'payload': payload,
      'revision': revision,
      'contentHash': contentHash,
      'lastModified': FieldValue.serverTimestamp(),
    });
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
    return _heroesCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map(_decodeHeroRecord)
          .whereType<RemoteHeroRecord>()
          .toList(growable: false);
    });
  }

  @override
  Stream<List<RemoteHeroStateRecord>> watchHeroStates() {
    return _statesCollection.snapshots().map((snapshot) {
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
    final deleted = data['deleted'] as bool? ?? false;
    final updatedAt = _readTimestamp(data['lastModified']);
    if (deleted) {
      return RemoteHeroRecord(
        id: doc.id,
        hero: null,
        revision: _readRevision(data, updatedAt),
        contentHash: '',
        isDeleted: true,
        updatedAt: updatedAt,
      );
    }

    final payload = data['payload'];
    if (payload is! Map) {
      return null;
    }
    final hero = HeroSheet.fromJson(_castMap(payload));
    final contentHash =
        data['contentHash'] as String? ?? heroContentHash(hero);
    return RemoteHeroRecord(
      id: doc.id,
      hero: hero,
      revision: _readRevision(data, updatedAt, fallbackHash: contentHash),
      contentHash: contentHash,
      isDeleted: false,
      updatedAt: updatedAt,
    );
  }

  RemoteHeroStateRecord? _decodeStateRecord(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      return null;
    }
    final deleted = data['deleted'] as bool? ?? false;
    final updatedAt = _readTimestamp(data['lastModified']);
    if (deleted) {
      return RemoteHeroStateRecord(
        heroId: doc.id,
        state: null,
        revision: _readRevision(data, updatedAt),
        contentHash: '',
        isDeleted: true,
        updatedAt: updatedAt,
      );
    }

    final payload = data['payload'];
    if (payload is! Map) {
      return null;
    }
    final state = HeroState.fromJson(_castMap(payload));
    final contentHash =
        data['contentHash'] as String? ?? stableContentHash(state.toJson());
    return RemoteHeroStateRecord(
      heroId: doc.id,
      state: state,
      revision: _readRevision(data, updatedAt, fallbackHash: contentHash),
      contentHash: contentHash,
      isDeleted: false,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> _castMap(Map<dynamic, dynamic> raw) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  DateTime? _readTimestamp(Object? raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    return null;
  }

  String _readRevision(
    Map<String, dynamic> data,
    DateTime? updatedAt, {
    String fallbackHash = '',
  }) {
    final revision = data['revision'] as String?;
    if (revision != null && revision.isNotEmpty) {
      return revision;
    }
    if (updatedAt != null) {
      return 'legacy-${updatedAt.toUtc().microsecondsSinceEpoch}';
    }
    return 'legacy-$fallbackHash';
  }

  String _newRevision() {
    return '${DateTime.now().toUtc().microsecondsSinceEpoch}-${_uuid.v4()}';
  }
}
