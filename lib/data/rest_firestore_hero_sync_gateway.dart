import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/data/firestore_rest_client.dart';
import 'package:dsa_heldenverwaltung/data/sync/remote_hero_sync_gateway.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

/// Firestore-REST-Gateway für privaten Konto-Sync von Helden und Zuständen.
///
/// Diese Implementierung vermeidet den nativen `cloud_firestore`-Pluginpfad
/// und eignet sich deshalb für Windows. Die Authentifizierung läuft über
/// Firebase-ID-Token, sodass Firestore Security Rules weiter greifen.
class RestFirestoreHeroSyncGateway
    implements RemoteHeroSyncGateway, RemoteHeroStateSyncGateway {
  /// Erstellt das REST-Gateway für den privaten User-Subtree.
  RestFirestoreHeroSyncGateway({
    required this.userId,
    required String projectId,
    required Future<String?> Function() idTokenProvider,
    String databaseId = '(default)',
    Duration pollInterval = const Duration(seconds: 30),
    http.Client? httpClient,
    FirestoreRestClient? restClient,
  }) : _pollInterval = pollInterval,
       _rest =
           restClient ??
           FirestoreRestClient(
             projectId: projectId,
             databaseId: databaseId,
             idTokenProvider: idTokenProvider,
             httpClient: httpClient,
           );

  static const Uuid _uuid = Uuid();

  /// UID des angemeldeten Firebase-Users.
  final String userId;

  final Duration _pollInterval;
  final FirestoreRestClient _rest;

  String get _heroesCollectionPath => 'users/$userId/heroes';
  String get _statesCollectionPath => 'users/$userId/hero_states';

  @override
  Future<RemoteHeroRecord> deleteHero(
    String heroId, {
    required String? previousRevision,
  }) async {
    final revision = _newRevision();
    final fields = <String, dynamic>{
      'deleted': true,
      'payload': null,
      'revision': revision,
      'contentHash': '',
      'lastModified': DateTime.now().toUtc(),
    };
    final savedFields = await _rest.patchDocumentFields(
      '$_heroesCollectionPath/$heroId',
      fields,
    );
    return _decodeHeroRecord(heroId, savedFields) ??
        RemoteHeroRecord(
          id: heroId,
          hero: null,
          revision: revision,
          contentHash: '',
          isDeleted: true,
          updatedAt: fields['lastModified'] as DateTime,
        );
  }

  @override
  Future<RemoteHeroStateRecord> deleteHeroState(
    String heroId, {
    required String? previousRevision,
  }) async {
    final revision = _newRevision();
    final fields = <String, dynamic>{
      'deleted': true,
      'payload': null,
      'revision': revision,
      'contentHash': '',
      'lastModified': DateTime.now().toUtc(),
    };
    final savedFields = await _rest.patchDocumentFields(
      '$_statesCollectionPath/$heroId',
      fields,
    );
    return _decodeStateRecord(heroId, savedFields) ??
        RemoteHeroStateRecord(
          heroId: heroId,
          state: null,
          revision: revision,
          contentHash: '',
          isDeleted: true,
          updatedAt: fields['lastModified'] as DateTime,
        );
  }

  @override
  Future<List<RemoteHeroRecord>> loadAllHeroes() async {
    final documents = await _rest.listDocuments(_heroesCollectionPath);
    return documents
        .map((document) => _decodeHeroRecord(document.id, document.fields))
        .whereType<RemoteHeroRecord>()
        .toList(growable: false);
  }

  @override
  Future<List<RemoteHeroStateRecord>> loadAllHeroStates() async {
    final documents = await _rest.listDocuments(_statesCollectionPath);
    return documents
        .map((document) => _decodeStateRecord(document.id, document.fields))
        .whereType<RemoteHeroStateRecord>()
        .toList(growable: false);
  }

  @override
  Future<RemoteHeroRecord?> loadHero(String heroId) async {
    final fields = await _rest.getDocumentFields(
      '$_heroesCollectionPath/$heroId',
    );
    return fields == null ? null : _decodeHeroRecord(heroId, fields);
  }

  @override
  Future<RemoteHeroStateRecord?> loadHeroState(String heroId) async {
    final fields = await _rest.getDocumentFields(
      '$_statesCollectionPath/$heroId',
    );
    return fields == null ? null : _decodeStateRecord(heroId, fields);
  }

  @override
  Future<RemoteHeroRecord> saveHero(
    HeroSheet hero, {
    required String? previousRevision,
  }) async {
    final payload = hero.toJson();
    final contentHash = stableContentHash(payload);
    final revision = _newRevision();
    final fields = <String, dynamic>{
      'deleted': false,
      'payload': payload,
      'revision': revision,
      'contentHash': contentHash,
      'lastModified': DateTime.now().toUtc(),
    };
    final savedFields = await _rest.patchDocumentFields(
      '$_heroesCollectionPath/${hero.id}',
      fields,
    );
    return _decodeHeroRecord(hero.id, savedFields) ??
        RemoteHeroRecord(
          id: hero.id,
          hero: hero,
          revision: revision,
          contentHash: contentHash,
          isDeleted: false,
          updatedAt: fields['lastModified'] as DateTime,
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
    final fields = <String, dynamic>{
      'deleted': false,
      'payload': payload,
      'revision': revision,
      'contentHash': contentHash,
      'lastModified': DateTime.now().toUtc(),
    };
    final savedFields = await _rest.patchDocumentFields(
      '$_statesCollectionPath/$heroId',
      fields,
    );
    return _decodeStateRecord(heroId, savedFields) ??
        RemoteHeroStateRecord(
          heroId: heroId,
          state: state,
          revision: revision,
          contentHash: contentHash,
          isDeleted: false,
          updatedAt: fields['lastModified'] as DateTime,
        );
  }

  @override
  Stream<List<RemoteHeroRecord>> watchHeroes() async* {
    yield await loadAllHeroes();
    yield* Stream<int>.periodic(_pollInterval).asyncMap((_) {
      return loadAllHeroes();
    });
  }

  @override
  Stream<List<RemoteHeroStateRecord>> watchHeroStates() async* {
    yield await loadAllHeroStates();
    yield* Stream<int>.periodic(_pollInterval).asyncMap((_) {
      return loadAllHeroStates();
    });
  }

  RemoteHeroRecord? _decodeHeroRecord(String id, Map<String, dynamic> fields) {
    final deleted = fields['deleted'] as bool? ?? false;
    final updatedAt = _readTimestamp(fields['lastModified']);
    if (deleted) {
      return RemoteHeroRecord(
        id: id,
        hero: null,
        revision: _readRevision(fields, updatedAt),
        contentHash: '',
        isDeleted: true,
        updatedAt: updatedAt,
      );
    }

    final payload = fields['payload'];
    if (payload is! Map) {
      return null;
    }
    final hero = HeroSheet.fromJson(_castMap(payload));
    final contentHash =
        fields['contentHash'] as String? ?? stableContentHash(hero.toJson());
    return RemoteHeroRecord(
      id: id,
      hero: hero,
      revision: _readRevision(fields, updatedAt, fallbackHash: contentHash),
      contentHash: contentHash,
      isDeleted: false,
      updatedAt: updatedAt,
    );
  }

  RemoteHeroStateRecord? _decodeStateRecord(
    String heroId,
    Map<String, dynamic> fields,
  ) {
    final deleted = fields['deleted'] as bool? ?? false;
    final updatedAt = _readTimestamp(fields['lastModified']);
    if (deleted) {
      return RemoteHeroStateRecord(
        heroId: heroId,
        state: null,
        revision: _readRevision(fields, updatedAt),
        contentHash: '',
        isDeleted: true,
        updatedAt: updatedAt,
      );
    }

    final payload = fields['payload'];
    if (payload is! Map) {
      return null;
    }
    final state = HeroState.fromJson(_castMap(payload));
    final contentHash =
        fields['contentHash'] as String? ?? stableContentHash(state.toJson());
    return RemoteHeroStateRecord(
      heroId: heroId,
      state: state,
      revision: _readRevision(fields, updatedAt, fallbackHash: contentHash),
      contentHash: contentHash,
      isDeleted: false,
      updatedAt: updatedAt,
    );
  }

  DateTime? _readTimestamp(Object? raw) {
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  String _readRevision(
    Map<String, dynamic> fields,
    DateTime? updatedAt, {
    String fallbackHash = '',
  }) {
    final revision = fields['revision'] as String?;
    if (revision != null && revision.isNotEmpty) {
      return revision;
    }
    if (updatedAt != null) {
      return 'legacy-${updatedAt.toUtc().microsecondsSinceEpoch}';
    }
    return 'legacy-$fallbackHash';
  }

  Map<String, dynamic> _castMap(Map<dynamic, dynamic> raw) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  String _newRevision() {
    return '${DateTime.now().toUtc().microsecondsSinceEpoch}-${_uuid.v4()}';
  }
}
