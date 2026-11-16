import 'dart:async';

import 'package:flutter/foundation.dart';
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
///
/// Beobachtet wird per Abfrage (SYNC-11): zuerst alle Dokumente, danach nur
/// die seit der letzten Abfrage geänderten (Feld `lastModified`, mit
/// [ueberlappung] als Sicherheitsrand gegen Uhrabweichungen anderer
/// REST-Schreiber), und alle [vollabgleichAlle] wieder alle. Solange [aktiv]
/// `false` meldet (Fenster minimiert), ruht die Abfrage.
class RestFirestoreHeroSyncGateway
    implements
        RemoteHeroSyncGateway,
        RemoteHeroStateSyncGateway,
        RemoteTombstoneBereinigung {
  /// Erstellt das REST-Gateway für den privaten User-Subtree.
  RestFirestoreHeroSyncGateway({
    required this.userId,
    required String projectId,
    required Future<String?> Function() idTokenProvider,
    String databaseId = '(default)',
    this._pollInterval = const Duration(seconds: 30),
    this.vollabgleichAlle = const Duration(minutes: 15),
    this.ueberlappung = const Duration(minutes: 5),
    this.aktiv,
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

  /// Abstand, in dem die Beobachtung wieder alle Dokumente liest.
  final Duration vollabgleichAlle;

  /// Sicherheitsrand der inkrementellen Abfrage vor dem letzten Cursor.
  final Duration ueberlappung;

  /// Ob die App sichtbar ist; ohne Angabe gilt sie als immer sichtbar.
  final ValueListenable<bool>? aktiv;

  String get _userPath => 'users/$userId';
  String get _heroesCollectionPath => '$_userPath/heroes';
  String get _statesCollectionPath => '$_userPath/hero_states';

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
  Stream<List<RemoteHeroRecord>> watchHeroes() => _beobachte(
    'heroes',
    (document) => _decodeHeroRecord(document.id, document.fields),
    'Held',
  );

  @override
  Stream<List<RemoteHeroStateRecord>> watchHeroStates() => _beobachte(
    'hero_states',
    (document) => _decodeStateRecord(document.id, document.fields),
    'Zustand',
  );

  @override
  Future<void> entferneHeldenTombstone(
    String heroId, {
    required String revision,
  }) => _entferneTombstone(
    '$_heroesCollectionPath/$heroId',
    revision,
    SyncDokumentArt.held,
  );

  @override
  Future<void> entferneZustandsTombstone(
    String heroId, {
    required String revision,
  }) => _entferneTombstone(
    '$_statesCollectionPath/$heroId',
    revision,
    SyncDokumentArt.zustand,
  );

  // Liest das Dokument frisch und löscht nur den unveränderten Tombstone.
  Future<void> _entferneTombstone(
    String documentPath,
    String revision,
    SyncDokumentArt art,
  ) async {
    final current = await _rest.getDocument(documentPath);
    if (current == null) return;
    final geloescht =
        current.fields[HeroSyncRecordFields.deleted] as bool? ?? false;
    final aktuelleRevision = revisionAusDokument(
      current.fields,
      _readTimestamp(current.fields[HeroSyncRecordFields.lastModified]),
      art: art,
    );
    final updateTime = current.updateTime;
    if (!geloescht || aktuelleRevision != revision || updateTime == null) {
      return;
    }
    await _rest.deleteDocument(
      documentPath,
      updateTimePrecondition: updateTime,
    );
  }

  /// Fragt die Collection [collectionId] sofort und danach im Abstand von
  /// [_pollInterval] ab: zunächst alles, dann nur Geändertes (SYNC-11).
  ///
  /// Ein Fehlschlag wird als Fehlerereignis gemeldet und beendet die
  /// Beobachtung nicht: Startet die App ohne Netz, liefe sonst bis zum
  /// Neustart kein Abgleich mehr, weil niemand neu abonniert. Nach einem
  /// Fehlschlag fragt die nächste Runde wieder alles ab.
  Stream<List<T>> _beobachte<T extends Object>(
    String collectionId,
    T? Function(FirestoreRestDocument document) dekodiere,
    String art,
  ) async* {
    DateTime? cursor;
    DateTime? letzterVollabgleich;
    while (true) {
      final jetzt = DateTime.now();
      final voll =
          cursor == null ||
          letzterVollabgleich == null ||
          jetzt.difference(letzterVollabgleich) >= vollabgleichAlle;
      try {
        final abfrage = await _rest.runQuery(
          _userPath,
          collectionId,
          geaendertSeit: voll ? null : cursor.subtract(ueberlappung),
        );
        if (voll) letzterVollabgleich = jetzt;
        // Ohne Serverzeit bleibt die nächste Runde vorsichtshalber voll.
        cursor = abfrage.lesezeit;
        yield dekodiereEinzeln(
          abfrage.dokumente,
          dekodiere,
          melde: (document, fehler, stack) =>
              meldeUnlesbaresSyncDokument(art, document.id, fehler, stack),
        );
      } on Object catch (error, stackTrace) {
        cursor = null;
        yield* Stream<List<T>>.error(error, stackTrace);
      }
      await Future<void>.delayed(_pollInterval);
      await _warteAufAktiv();
    }
  }

  // Ruht, solange [aktiv] `false` meldet; kehrt beim Sichtbarwerden zurück.
  Future<void> _warteAufAktiv() async {
    final signal = aktiv;
    if (signal == null || signal.value) return;
    final fertig = Completer<void>();
    void pruefe() {
      if (signal.value && !fertig.isCompleted) fertig.complete();
    }

    signal.addListener(pruefe);
    try {
      await fertig.future;
    } finally {
      signal.removeListener(pruefe);
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
