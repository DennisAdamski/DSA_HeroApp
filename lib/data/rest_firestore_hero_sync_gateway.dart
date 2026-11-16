import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:dsa_heldenverwaltung/data/firestore_rest_client.dart';
import 'package:dsa_heldenverwaltung/data/sync/hero_sync_record_codec.dart';
import 'package:dsa_heldenverwaltung/data/sync/remote_hero_sync_gateway.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';
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
    this._pollInterval = const Duration(seconds: 30),
    http.Client? httpClient,
    FirestoreRestClient? restClient,
  }) : _rest =
           restClient ??
           FirestoreRestClient(
             projectId: projectId,
             databaseId: databaseId,
             idTokenProvider: idTokenProvider,
             httpClient: httpClient,
           );

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
    final revision = newSyncRevision();
    final lastModified = DateTime.now().toUtc();
    final fields = encodeSyncTombstoneWriteFields(
      revision: revision,
      lastModifiedValue: lastModified,
    );
    final savedFields = await _guardedPatch(
      '$_heroesCollectionPath/$heroId',
      fields,
      previousRevision: previousRevision,
      art: SyncDokumentArt.held,
    );
    return _decodeHeroRecord(heroId, savedFields) ??
        RemoteHeroRecord(
          id: heroId,
          hero: null,
          revision: revision,
          contentHash: '',
          isDeleted: true,
          updatedAt: lastModified,
        );
  }

  @override
  Future<RemoteHeroStateRecord> deleteHeroState(
    String heroId, {
    required String? previousRevision,
  }) async {
    final revision = newSyncRevision();
    final lastModified = DateTime.now().toUtc();
    final fields = encodeSyncTombstoneWriteFields(
      revision: revision,
      lastModifiedValue: lastModified,
    );
    final savedFields = await _guardedPatch(
      '$_statesCollectionPath/$heroId',
      fields,
      previousRevision: previousRevision,
      art: SyncDokumentArt.zustand,
    );
    return _decodeStateRecord(heroId, savedFields) ??
        RemoteHeroStateRecord(
          heroId: heroId,
          state: null,
          revision: revision,
          contentHash: '',
          isDeleted: true,
          updatedAt: lastModified,
        );
  }

  @override
  Future<List<RemoteHeroRecord>> loadAllHeroes() async {
    final documents = await _rest.listDocuments(_heroesCollectionPath);
    return dekodiereEinzeln(
      documents,
      (document) => _decodeHeroRecord(document.id, document.fields),
      melde: (document, fehler, stack) =>
          meldeUnlesbaresSyncDokument('Held', document.id, fehler, stack),
    );
  }

  @override
  Future<List<RemoteHeroStateRecord>> loadAllHeroStates() async {
    final documents = await _rest.listDocuments(_statesCollectionPath);
    return dekodiereEinzeln(
      documents,
      (document) => _decodeStateRecord(document.id, document.fields),
      melde: (document, fehler, stack) =>
          meldeUnlesbaresSyncDokument('Zustand', document.id, fehler, stack),
    );
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
    final contentHash = heroContentHash(hero);
    final revision = newSyncRevision();
    final lastModified = DateTime.now().toUtc();
    final fields = encodeSyncPayloadWriteFields(
      payload: hero.toJson(),
      revision: revision,
      contentHash: contentHash,
      lastModifiedValue: lastModified,
    );
    final savedFields = await _guardedPatch(
      '$_heroesCollectionPath/${hero.id}',
      fields,
      previousRevision: previousRevision,
      art: SyncDokumentArt.held,
    );
    return _decodeHeroRecord(hero.id, savedFields) ??
        RemoteHeroRecord(
          id: hero.id,
          hero: hero,
          revision: revision,
          contentHash: contentHash,
          isDeleted: false,
          updatedAt: lastModified,
        );
  }

  @override
  Future<RemoteHeroStateRecord> saveHeroState(
    String heroId,
    HeroState state, {
    required String? previousRevision,
  }) async {
    final payload = state.toJson();
    final contentHash = heroStateContentHash(state);
    final revision = newSyncRevision();
    final lastModified = DateTime.now().toUtc();
    final fields = encodeSyncPayloadWriteFields(
      payload: payload,
      revision: revision,
      contentHash: contentHash,
      lastModifiedValue: lastModified,
    );
    final savedFields = await _guardedPatch(
      '$_statesCollectionPath/$heroId',
      fields,
      previousRevision: previousRevision,
      art: SyncDokumentArt.zustand,
    );
    return _decodeStateRecord(heroId, savedFields) ??
        RemoteHeroStateRecord(
          heroId: heroId,
          state: state,
          revision: revision,
          contentHash: contentHash,
          isDeleted: false,
          updatedAt: lastModified,
        );
  }

  @override
  Stream<List<RemoteHeroRecord>> watchHeroes() => _beobachte(loadAllHeroes);

  @override
  Stream<List<RemoteHeroStateRecord>> watchHeroStates() {
    return _beobachte(loadAllHeroStates);
  }

  /// Fragt [lade] sofort und danach im Abstand von [_pollInterval] ab.
  ///
  /// Ein Fehlschlag wird als Fehlerereignis gemeldet und beendet die
  /// Beobachtung nicht: Startet die App ohne Netz, liefe sonst bis zum
  /// Neustart kein Abgleich mehr, weil niemand neu abonniert.
  Stream<T> _beobachte<T>(Future<T> Function() lade) async* {
    while (true) {
      try {
        yield await lade();
      } on Object catch (error, stackTrace) {
        yield* Stream<T>.error(error, stackTrace);
      }
      await Future<void>.delayed(_pollInterval);
    }
  }

  /// Schreibt per PATCH und erzwingt [previousRevision] serverseitig.
  ///
  /// Bei gesetzter Revision wird das Dokument zuerst gelesen; weicht die
  /// Revision ab, fliegt eine [SyncPreconditionException] ohne Write. Der
  /// anschließende PATCH traegt eine `currentDocument.updateTime`-Precondition,
  /// damit auch ein Schreiber zwischen Read und Write als Konflikt auffällt.
  /// Ohne [previousRevision] bleibt es beim Blind-Write (bewusst z. B. für
  /// frisch angelegte Dokumente und `keepBoth`-Kopien).
  Future<Map<String, dynamic>> _guardedPatch(
    String documentPath,
    Map<String, dynamic> fields, {
    required String? previousRevision,
    required SyncDokumentArt art,
  }) async {
    if (previousRevision == null) {
      return _rest.patchDocumentFields(documentPath, fields);
    }
    final current = await _rest.getDocument(documentPath);
    if (current == null) {
      throw SyncPreconditionException(
        'Remote-Dokument fehlt, erwartet war Revision $previousRevision.',
        expectedRevision: previousRevision,
      );
    }
    final currentRevision = revisionAusDokument(
      current.fields,
      _readTimestamp(current.fields[HeroSyncRecordFields.lastModified]),
      art: art,
    );
    if (currentRevision != previousRevision) {
      throw SyncPreconditionException(
        'Remote-Revision hat sich geändert '
        '($previousRevision -> $currentRevision).',
        expectedRevision: previousRevision,
        actualRevision: currentRevision,
      );
    }
    return _rest.patchDocumentFields(
      documentPath,
      fields,
      updateTimePrecondition: current.updateTime,
    );
  }

  RemoteHeroRecord? _decodeHeroRecord(String id, Map<String, dynamic> fields) {
    return decodeRemoteHeroRecord(
      id: id,
      data: fields,
      updatedAt: _readTimestamp(fields[HeroSyncRecordFields.lastModified]),
    );
  }

  RemoteHeroStateRecord? _decodeStateRecord(
    String heroId,
    Map<String, dynamic> fields,
  ) {
    return decodeRemoteHeroStateRecord(
      heroId: heroId,
      data: fields,
      updatedAt: _readTimestamp(fields[HeroSyncRecordFields.lastModified]),
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
}
