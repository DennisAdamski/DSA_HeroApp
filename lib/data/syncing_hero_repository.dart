import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/sync/remote_hero_sync_gateway.dart';
import 'package:dsa_heldenverwaltung/data/sync/sync_metadata_store.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_controller.dart';
import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/sync_object_diff.dart';

/// HeroRepository-Dekorator mit accountgebundenem Remote-Sync.
///
/// Die UI liest und schreibt weiterhin gegen die lokale Repository-Abstraktion.
/// Dieses Repository spiegelt Aenderungen nach Remote, zieht Remote-Aenderungen
/// in den lokalen Cache und erzeugt explizite Konflikte statt stiller
/// Ueberschreibungen, sobald beide Seiten seit der letzten Basisrevision
/// geaendert wurden.
class SyncingHeroRepository implements HeroRepository, AppSyncController {
  /// Erstellt ein synchronisierendes Repository.
  SyncingHeroRepository({
    required this.local,
    required this.remote,
    required this.metadataStore,
    required this.accountId,
    this.accountEmail,
    bool startRemoteListener = true,
  }) {
    if (startRemoteListener) {
      _heroSubscription = remote.watchHeroes().listen(
        (records) => unawaited(_applyRemoteHeroRecords(records)),
        onError: _handleRemoteStreamError,
      );
      final stateGateway = _stateRemote;
      if (stateGateway != null) {
        _stateSubscription = stateGateway.watchHeroStates().listen(
          (records) => unawaited(_applyRemoteStateRecords(records)),
          onError: _handleRemoteStreamError,
        );
      }
    }
  }

  /// Lokales, offline-faehiges Repository.
  final HeroRepository local;

  /// Remote-Gateway fuer private Kontodaten.
  final RemoteHeroSyncGateway remote;

  /// Lokaler Metadatenspeicher fuer Basisrevisionen.
  final SyncMetadataStore metadataStore;

  /// Konto-ID des angemeldeten Users.
  final String accountId;

  /// Anzeigename oder E-Mail des angemeldeten Users.
  final String? accountEmail;

  final StreamController<SyncStatusSnapshot> _statusController =
      StreamController<SyncStatusSnapshot>.broadcast();
  final Map<String, _HeroConflictDetails> _heroConflicts =
      <String, _HeroConflictDetails>{};
  final Map<String, _OfflineHeroConflictDetails> _offlineHeroConflicts =
      <String, _OfflineHeroConflictDetails>{};
  final Map<String, _StateConflictDetails> _stateConflicts =
      <String, _StateConflictDetails>{};
  final Map<String, _DeletedHeroConflictDetails> _deletedHeroConflicts =
      <String, _DeletedHeroConflictDetails>{};
  final Map<String, SyncObjectDiff> _conflictDiffCache =
      <String, SyncObjectDiff>{};
  StreamSubscription<List<RemoteHeroRecord>>? _heroSubscription;
  StreamSubscription<List<RemoteHeroStateRecord>>? _stateSubscription;

  SyncStatusSnapshot _status = const SyncStatusSnapshot();

  RemoteHeroStateSyncGateway? get _stateRemote {
    if (remote is RemoteHeroStateSyncGateway) {
      return remote as RemoteHeroStateSyncGateway;
    }
    return null;
  }

  /// Aktueller Sync-Status fuer nicht-reaktive Aufrufer.
  @override
  SyncStatusSnapshot get currentStatus =>
      _status.copyWith(accountId: accountId, email: accountEmail);

  /// Reaktiver Status-Stream mit initialem Snapshot.
  @override
  Stream<SyncStatusSnapshot> watchStatus() async* {
    yield currentStatus;
    yield* _statusController.stream;
  }

  /// Fuehrt einen vollstaendigen Pull-/Push-Abgleich aus.
  @override
  Future<void> syncNow() async {
    _emitStatus(_status.copyWith(isSyncing: true, lastFailure: null));
    try {
      final heroApplyFailures = await _syncHeroes();
      final stateApplyFailures = await _syncHeroStates();
      if (heroApplyFailures == 0 && stateApplyFailures == 0) {
        _emitStatus(
          _status.copyWith(
            isSyncing: false,
            lastSuccessfulSync: DateTime.now().toUtc(),
            lastFailure: null,
          ),
        );
      } else {
        // Teilerfolg: lastFailure wurde bereits von den Apply-Methoden
        // gesetzt und bleibt sichtbar.
        _emitStatus(_status.copyWith(isSyncing: false));
      }
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'syncing_hero_repository',
          context: ErrorDescription('Manueller Konto-Sync fehlgeschlagen'),
        ),
      );
      _emitStatus(
        _status.copyWith(
          isSyncing: false,
          lastFailure: SyncFailure.fromError(
            error,
            occurredAt: DateTime.now().toUtc(),
          ),
        ),
      );
    }
  }

  /// Loest einen offenen Konflikt gemaess [resolution] auf.
  @override
  Future<void> resolveConflict(
    String conflictId,
    SyncResolutionChoice resolution,
  ) async {
    final offlineConflict = _offlineHeroConflicts[conflictId];
    if (offlineConflict != null) {
      await _resolveOfflineHeroConflict(offlineConflict, resolution);
      _offlineHeroConflicts.remove(conflictId);
      _conflictDiffCache.remove(conflictId);
      _removeConflictFromStatus(conflictId);
      return;
    }

    final heroConflict = _heroConflicts[conflictId];
    if (heroConflict != null) {
      try {
        await _resolveHeroConflict(heroConflict, resolution);
        _heroConflicts.remove(conflictId);
        _conflictDiffCache.remove(conflictId);
        _removeConflictFromStatus(conflictId);
      } on SyncPreconditionException {
        // Remote hat sich waehrend des offenen Dialogs erneut geaendert:
        // Konflikt mit frischem Remote-Stand neu oeffnen.
        _heroConflicts.remove(conflictId);
        _conflictDiffCache.remove(conflictId);
        _removeConflictFromStatus(conflictId);
        final fresh = await remote.loadHero(heroConflict.localHero.id);
        if (fresh != null) {
          _openHeroConflict(
            localHero: heroConflict.localHero,
            remoteRecord: fresh,
            localTimestamp: heroConflict.localHero.lastModified,
          );
        }
      }
      return;
    }

    final deletedConflict = _deletedHeroConflicts[conflictId];
    if (deletedConflict != null) {
      try {
        await _resolveDeletedHeroConflict(deletedConflict, resolution);
        _deletedHeroConflicts.remove(conflictId);
        _conflictDiffCache.remove(conflictId);
        _removeConflictFromStatus(conflictId);
      } on SyncPreconditionException {
        // Remote hat sich waehrend des offenen Dialogs erneut geaendert.
        _deletedHeroConflicts.remove(conflictId);
        _conflictDiffCache.remove(conflictId);
        _removeConflictFromStatus(conflictId);
        final fresh = await remote.loadHero(deletedConflict.heroId);
        if (fresh != null && !fresh.isDeleted) {
          _openDeletedHeroConflict(
            heroId: deletedConflict.heroId,
            remoteRecord: fresh,
          );
        }
      }
      return;
    }

    final stateConflict = _stateConflicts[conflictId];
    if (stateConflict != null) {
      try {
        await _resolveStateConflict(stateConflict, resolution);
        _stateConflicts.remove(conflictId);
        _conflictDiffCache.remove(conflictId);
        _removeConflictFromStatus(conflictId);
      } on SyncPreconditionException {
        _stateConflicts.remove(conflictId);
        _conflictDiffCache.remove(conflictId);
        _removeConflictFromStatus(conflictId);
        final stateGateway = _stateRemote;
        final fresh = await stateGateway?.loadHeroState(
          stateConflict.remoteRecord.heroId,
        );
        if (fresh != null) {
          _openStateConflict(
            heroId: stateConflict.remoteRecord.heroId,
            localState: stateConflict.localState,
            remoteRecord: fresh,
          );
        }
      }
    }
  }

  /// Berechnet das Feld-Diff eines offenen Konflikts bei Bedarf.
  ///
  /// Das Ergebnis wird pro Konflikt-ID gecacht und beim Aufloesen des
  /// Konflikts wieder verworfen.
  @override
  SyncObjectDiff? conflictDiff(String conflictId) {
    final cached = _conflictDiffCache[conflictId];
    if (cached != null) {
      return cached;
    }
    final diff = _computeConflictDiff(conflictId);
    if (diff != null) {
      _conflictDiffCache[conflictId] = diff;
    }
    return diff;
  }

  SyncObjectDiff? _computeConflictDiff(String conflictId) {
    final offlineConflict = _offlineHeroConflicts[conflictId];
    if (offlineConflict != null) {
      return computeSyncObjectDiff(
        offlineConflict.offlineHero.toJson(),
        offlineConflict.accountHero?.toJson(),
      );
    }
    final heroConflict = _heroConflicts[conflictId];
    if (heroConflict != null) {
      final remoteRecord = heroConflict.remoteRecord;
      return computeSyncObjectDiff(
        heroConflict.localHero.toJson(),
        remoteRecord.isDeleted ? null : remoteRecord.hero?.toJson(),
      );
    }
    final stateConflict = _stateConflicts[conflictId];
    if (stateConflict != null) {
      final remoteRecord = stateConflict.remoteRecord;
      return computeSyncObjectDiff(
        stateConflict.localState.toJson(),
        remoteRecord.isDeleted ? null : remoteRecord.state?.toJson(),
      );
    }
    return null;
  }

  /// Erzeugt Konflikte fuer Offline-Helden beim Wechsel in ein Konto-Profil.
  ///
  /// Die Methode wird nur genutzt, wenn sowohl Offline-Daten als auch bereits
  /// Konto-/Online-Daten vorhanden sind. Dadurch entscheidet der Nutzer bewusst,
  /// ob Offline-Helden ins Konto uebernommen, ignoriert oder als Kopie
  /// erhalten werden.
  Future<void> queueOfflineProfileConflicts({
    required List<HeroSheet> offlineHeroes,
  }) async {
    if (offlineHeroes.isEmpty) {
      return;
    }
    for (final offlineHero in offlineHeroes) {
      final conflictId = 'offlineHero-${offlineHero.id}';
      if (_offlineHeroConflicts.containsKey(conflictId)) {
        continue;
      }
      final accountHero = await local.loadHeroById(offlineHero.id);
      if (accountHero != null &&
          heroContentHash(accountHero) == heroContentHash(offlineHero)) {
        // Inhaltlich identisch: keine Nutzerentscheidung noetig, das Konto
        // enthaelt bereits denselben Stand.
        continue;
      }
      final conflict = SyncConflict(
        id: conflictId,
        objectType: SyncObjectType.hero,
        objectId: offlineHero.id,
        title: 'Offline-Held: ${offlineHero.name}',
        localSummary: offlineHero.name,
        remoteSummary: accountHero == null
            ? 'Konto enthält bereits andere Daten'
            : 'Konto-Version: ${accountHero.name}',
        detectedAt: DateTime.now().toUtc(),
        supportsKeepBoth: true,
        localApTotal: offlineHero.apTotal,
        localApAvailable: offlineHero.apAvailable,
        localUpdatedAt: offlineHero.lastModified,
        remoteApTotal: accountHero?.apTotal,
        remoteApAvailable: accountHero?.apAvailable,
        remoteUpdatedAt: accountHero?.lastModified,
      );
      _offlineHeroConflicts[conflictId] = _OfflineHeroConflictDetails(
        conflict: conflict,
        offlineHero: offlineHero,
        accountHero: accountHero,
      );
      _addConflictToStatus(conflict);
    }
  }

  Future<int> _syncHeroes() async {
    final records = await remote.loadAllHeroes();
    final applyFailures = await _applyRemoteHeroRecords(records);

    final remoteIds = records.map((record) => record.id).toSet();
    final localHeroes = await local.listHeroes();
    for (final hero in localHeroes) {
      if (remoteIds.contains(hero.id)) {
        final record = records.firstWhere((entry) => entry.id == hero.id);
        final metadata = await metadataStore.load(_heroKey(hero.id));
        if (record.revision == metadata?.remoteRevision) {
          final localHash = heroContentHash(hero);
          if (localHash != metadata?.localHash) {
            await _pushHeroIfSafe(hero);
          }
        }
        continue;
      }
      await _pushHeroIfSafe(hero);
    }
    return applyFailures;
  }

  Future<int> _syncHeroStates() async {
    final stateGateway = _stateRemote;
    if (stateGateway == null) {
      return 0;
    }
    final records = await stateGateway.loadAllHeroStates();
    final applyFailures = await _applyRemoteStateRecords(records);

    final remoteIds = records.map((record) => record.heroId).toSet();
    for (final hero in await local.listHeroes()) {
      if (remoteIds.contains(hero.id)) {
        continue;
      }
      final state = await local.loadHeroState(hero.id);
      if (state != null) {
        await _pushHeroStateIfSafe(hero.id, state);
      }
    }
    return applyFailures;
  }

  /// Übernimmt Remote-Helden einzeln und isoliert Fehler pro Datensatz.
  ///
  /// Gibt die Anzahl fehlgeschlagener Datensätze zurück; ein kaputter
  /// Datensatz bricht den Batch nicht mehr ab.
  Future<int> _applyRemoteHeroRecords(List<RemoteHeroRecord> records) async {
    final failedIds = <String>[];
    for (final record in records) {
      try {
        await _applyRemoteHeroRecord(record);
      } on Object catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'syncing_hero_repository',
            context: ErrorDescription(
              'Remote-Held ${record.id} konnte nicht übernommen werden',
            ),
          ),
        );
        failedIds.add(record.id);
      }
    }
    _reportApplyFailures('Helden', failedIds);
    return failedIds.length;
  }

  Future<void> _applyRemoteHeroRecord(RemoteHeroRecord record) async {
    final key = _heroKey(record.id);
    final metadata = await metadataStore.load(key);
    final localHero = await local.loadHeroById(record.id);

    if (record.isDeleted) {
      await _applyRemoteHeroDelete(record, metadata, localHero);
      return;
    }

    final remoteHero = record.hero;
    if (remoteHero == null) {
      return;
    }
    final remoteHash = _remoteHeroHash(record);
    if (localHero == null) {
      if (_isPendingLocalDelete(metadata)) {
        await _completePendingHeroDelete(record, metadata!);
        return;
      }
      await local.saveHero(remoteHero);
      await _saveMetadata(
        key: key,
        localHash: remoteHash,
        remoteHash: remoteHash,
        remoteRevision: record.revision,
      );
      return;
    }

    final localHash = heroContentHash(localHero);
    if (localHash == remoteHash) {
      await _saveMetadata(
        key: key,
        localHash: localHash,
        remoteHash: remoteHash,
        remoteRevision: record.revision,
      );
      return;
    }

    if (metadata != null && metadata.remoteRevision == record.revision) {
      return;
    }

    if (metadata != null && localHash == metadata.localHash) {
      await local.saveHero(remoteHero);
      await _saveMetadata(
        key: key,
        localHash: remoteHash,
        remoteHash: remoteHash,
        remoteRevision: record.revision,
      );
      return;
    }

    _openHeroConflict(
      localHero: localHero,
      remoteRecord: record,
      localTimestamp: localHero.lastModified ?? metadata?.updatedAt,
    );
  }

  /// True, wenn die Metadaten eine lokal ausgefuehrte, remote aber noch
  /// nicht bestaetigte Loeschung markieren (siehe [deleteHero]).
  bool _isPendingLocalDelete(SyncMetadata? metadata) {
    return metadata != null && !metadata.isDeleted && metadata.localHash.isEmpty;
  }

  /// Holt eine lokal bereits ausgefuehrte Loeschung remote nach.
  ///
  /// Bei unveraenderter Remote-Revision wird der Tombstone geschrieben; hat
  /// sich Remote seit der lokalen Loeschung geaendert, entscheidet der Nutzer
  /// ueber den Loesch-Konflikt statt den Helden still wiederzubeleben.
  Future<void> _completePendingHeroDelete(
    RemoteHeroRecord record,
    SyncMetadata metadata,
  ) async {
    if (record.revision != metadata.remoteRevision) {
      _openDeletedHeroConflict(heroId: record.id, remoteRecord: record);
      return;
    }
    final RemoteHeroRecord deleted;
    try {
      deleted = await remote.deleteHero(
        record.id,
        previousRevision: record.revision,
      );
    } on SyncPreconditionException {
      final fresh = await remote.loadHero(record.id);
      if (fresh != null && !fresh.isDeleted) {
        _openDeletedHeroConflict(heroId: record.id, remoteRecord: fresh);
      }
      return;
    }
    await _saveMetadata(
      key: _heroKey(record.id),
      localHash: '',
      remoteHash: '',
      remoteRevision: deleted.revision,
      isDeleted: true,
    );
    await _tombstoneStateBestEffort(record.id);
  }

  Future<void> _applyRemoteHeroDelete(
    RemoteHeroRecord record,
    SyncMetadata? metadata,
    HeroSheet? localHero,
  ) async {
    if (localHero == null) {
      await _saveMetadata(
        key: _heroKey(record.id),
        localHash: '',
        remoteHash: '',
        remoteRevision: record.revision,
        isDeleted: true,
      );
      return;
    }

    final localHash = heroContentHash(localHero);
    if (metadata != null && localHash == metadata.localHash) {
      await local.deleteHero(record.id);
      await _saveMetadata(
        key: _heroKey(record.id),
        localHash: '',
        remoteHash: '',
        remoteRevision: record.revision,
        isDeleted: true,
      );
      return;
    }

    _openHeroConflict(
      localHero: localHero,
      remoteRecord: record,
      localTimestamp: metadata?.updatedAt,
    );
  }

  Future<void> _pushHeroIfSafe(HeroSheet hero) async {
    final key = _heroKey(hero.id);
    final metadata = await metadataStore.load(key);
    final remoteRecord = await remote.loadHero(hero.id);
    final localHash = heroContentHash(hero);

    if (remoteRecord != null &&
        !remoteRecord.isDeleted &&
        _remoteHeroHash(remoteRecord) != localHash) {
      if (metadata == null ||
          remoteRecord.revision != metadata.remoteRevision) {
        _openHeroConflict(
          localHero: hero,
          remoteRecord: remoteRecord,
          localTimestamp: hero.lastModified ?? metadata?.updatedAt,
        );
        return;
      }
    }

    if (remoteRecord != null &&
        remoteRecord.isDeleted &&
        remoteRecord.revision != metadata?.remoteRevision) {
      _openHeroConflict(
        localHero: hero,
        remoteRecord: remoteRecord,
        localTimestamp: hero.lastModified ?? metadata?.updatedAt,
      );
      return;
    }

    final RemoteHeroRecord saved;
    try {
      saved = await remote.saveHero(
        hero,
        previousRevision: metadata?.remoteRevision,
      );
    } on SyncPreconditionException {
      // Paralleler Schreiber zwischen Read und Write: frischen Remote-Stand
      // laden und den regulaeren Konfliktdialog oeffnen.
      final fresh = await remote.loadHero(hero.id);
      if (fresh != null) {
        _openHeroConflict(
          localHero: hero,
          remoteRecord: fresh,
          localTimestamp: hero.lastModified ?? metadata?.updatedAt,
        );
      }
      return;
    }
    final remoteHash = _remoteHeroHash(saved);
    await _saveMetadata(
      key: key,
      localHash: localHash,
      remoteHash: remoteHash,
      remoteRevision: saved.revision,
    );
  }

  /// Übernimmt Remote-Zustände einzeln, analog zu [_applyRemoteHeroRecords].
  Future<int> _applyRemoteStateRecords(
    List<RemoteHeroStateRecord> records,
  ) async {
    final failedIds = <String>[];
    for (final record in records) {
      try {
        await _applyRemoteStateRecord(record);
      } on Object catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'syncing_hero_repository',
            context: ErrorDescription(
              'Remote-Zustand ${record.heroId} konnte nicht übernommen werden',
            ),
          ),
        );
        failedIds.add(record.heroId);
      }
    }
    _reportApplyFailures('Zustands', failedIds);
    return failedIds.length;
  }

  void _reportApplyFailures(String label, List<String> failedIds) {
    if (failedIds.isEmpty) {
      return;
    }
    final shown = failedIds.take(3).join(', ');
    final suffix = failedIds.length > 3 ? ', …' : '';
    _emitStatus(
      _status.copyWith(
        lastFailure: SyncFailure(
          kind: SyncErrorKind.decode,
          message:
              '${failedIds.length} $label-Datensätze konnten nicht '
              'übernommen werden ($shown$suffix).',
          occurredAt: DateTime.now().toUtc(),
        ),
      ),
    );
  }

  Future<void> _applyRemoteStateRecord(RemoteHeroStateRecord record) async {
    final key = _stateKey(record.heroId);
    final metadata = await metadataStore.load(key);
    final localState = await local.loadHeroState(record.heroId);

    if (record.isDeleted) {
      if (localState == null || metadata?.localHash == '') {
        await _saveMetadata(
          key: key,
          localHash: '',
          remoteHash: '',
          remoteRevision: record.revision,
          isDeleted: true,
        );
      } else {
        _openStateConflict(
          heroId: record.heroId,
          localState: localState,
          remoteRecord: record,
        );
      }
      return;
    }

    final remoteState = record.state;
    if (remoteState == null) {
      return;
    }
    final remoteHash = _remoteStateHash(record);
    if (localState == null) {
      await local.saveHeroState(record.heroId, remoteState);
      await _saveMetadata(
        key: key,
        localHash: remoteHash,
        remoteHash: remoteHash,
        remoteRevision: record.revision,
      );
      return;
    }
    final localHash = stableContentHash(localState.toJson());
    if (localHash == remoteHash ||
        (metadata != null && localHash == metadata.localHash)) {
      await local.saveHeroState(record.heroId, remoteState);
      await _saveMetadata(
        key: key,
        localHash: remoteHash,
        remoteHash: remoteHash,
        remoteRevision: record.revision,
      );
      return;
    }
    if (metadata != null && metadata.remoteRevision == record.revision) {
      return;
    }
    _openStateConflict(
      heroId: record.heroId,
      localState: localState,
      remoteRecord: record,
    );
  }

  Future<void> _pushHeroStateIfSafe(String heroId, HeroState state) async {
    final stateGateway = _stateRemote;
    if (stateGateway == null) {
      return;
    }
    final key = _stateKey(heroId);
    final metadata = await metadataStore.load(key);
    final remoteRecord = await stateGateway.loadHeroState(heroId);
    final localHash = stableContentHash(state.toJson());

    if (remoteRecord != null &&
        !remoteRecord.isDeleted &&
        _remoteStateHash(remoteRecord) != localHash &&
        (metadata == null ||
            remoteRecord.revision != metadata.remoteRevision)) {
      _openStateConflict(
        heroId: heroId,
        localState: state,
        remoteRecord: remoteRecord,
      );
      return;
    }

    final RemoteHeroStateRecord saved;
    try {
      saved = await stateGateway.saveHeroState(
        heroId,
        state,
        previousRevision: metadata?.remoteRevision,
      );
    } on SyncPreconditionException {
      final fresh = await stateGateway.loadHeroState(heroId);
      if (fresh != null) {
        _openStateConflict(
          heroId: heroId,
          localState: state,
          remoteRecord: fresh,
        );
      }
      return;
    }
    await _saveMetadata(
      key: key,
      localHash: localHash,
      remoteHash: _remoteStateHash(saved),
      remoteRevision: saved.revision,
    );
  }

  void _openHeroConflict({
    required HeroSheet localHero,
    required RemoteHeroRecord remoteRecord,
    DateTime? localTimestamp,
  }) {
    final conflictId = 'hero-${localHero.id}';
    if (_heroConflicts.containsKey(conflictId)) {
      return;
    }
    final remoteHero = remoteRecord.hero;
    final conflict = SyncConflict(
      id: conflictId,
      objectType: SyncObjectType.hero,
      objectId: localHero.id,
      title: 'Held: ${localHero.name}',
      localSummary: localHero.name,
      remoteSummary: remoteRecord.isDeleted
          ? 'Online geloescht'
          : (remoteHero?.name ?? 'Online-Version'),
      detectedAt: DateTime.now().toUtc(),
      supportsKeepBoth: !remoteRecord.isDeleted,
      localApTotal: localHero.apTotal,
      localApAvailable: localHero.apAvailable,
      localUpdatedAt: localHero.lastModified ?? localTimestamp,
      remoteApTotal: remoteHero?.apTotal,
      remoteApAvailable: remoteHero?.apAvailable,
      remoteUpdatedAt: remoteRecord.updatedAt,
    );
    _heroConflicts[conflictId] = _HeroConflictDetails(
      conflict: conflict,
      localHero: localHero,
      remoteRecord: remoteRecord,
    );
    _addConflictToStatus(conflict);
  }

  /// Oeffnet einen Konflikt "lokal geloescht vs. online geaendert".
  void _openDeletedHeroConflict({
    required String heroId,
    required RemoteHeroRecord remoteRecord,
  }) {
    final conflictId = 'deletedHero-$heroId';
    if (_deletedHeroConflicts.containsKey(conflictId)) {
      return;
    }
    final remoteHero = remoteRecord.hero;
    final conflict = SyncConflict(
      id: conflictId,
      objectType: SyncObjectType.hero,
      objectId: heroId,
      title: 'Held: ${remoteHero?.name ?? heroId}',
      localSummary: 'Lokal gelöscht',
      remoteSummary: remoteHero?.name ?? 'Online-Version',
      detectedAt: DateTime.now().toUtc(),
      supportsKeepBoth: false,
      remoteApTotal: remoteHero?.apTotal,
      remoteApAvailable: remoteHero?.apAvailable,
      remoteUpdatedAt: remoteRecord.updatedAt,
    );
    _deletedHeroConflicts[conflictId] = _DeletedHeroConflictDetails(
      conflict: conflict,
      heroId: heroId,
      remoteRecord: remoteRecord,
    );
    _addConflictToStatus(conflict);
  }

  void _openStateConflict({
    required String heroId,
    required HeroState localState,
    required RemoteHeroStateRecord remoteRecord,
  }) {
    final conflictId = 'heroState-$heroId';
    if (_stateConflicts.containsKey(conflictId)) {
      return;
    }
    final conflict = SyncConflict(
      id: conflictId,
      objectType: SyncObjectType.heroState,
      objectId: heroId,
      title: 'Zustand: $heroId',
      localSummary: 'Lokale Laufzeitwerte',
      remoteSummary: remoteRecord.isDeleted
          ? 'Online geloescht'
          : 'Online-Laufzeitwerte',
      detectedAt: DateTime.now().toUtc(),
    );
    _stateConflicts[conflictId] = _StateConflictDetails(
      conflict: conflict,
      localState: localState,
      remoteRecord: remoteRecord,
    );
    _addConflictToStatus(conflict);
  }

  Future<void> _resolveHeroConflict(
    _HeroConflictDetails details,
    SyncResolutionChoice resolution,
  ) async {
    final remoteRecord = details.remoteRecord;
    final remoteHero = remoteRecord.hero;
    switch (resolution) {
      case SyncResolutionChoice.keepLocal:
        if (remoteRecord.isDeleted) {
          final saved = await remote.saveHero(
            details.localHero,
            previousRevision: remoteRecord.revision,
          );
          await _storeHeroMetadata(details.localHero, saved);
        } else {
          final saved = await remote.saveHero(
            details.localHero,
            previousRevision: remoteRecord.revision,
          );
          await _storeHeroMetadata(details.localHero, saved);
        }
      case SyncResolutionChoice.keepRemote:
        if (remoteRecord.isDeleted || remoteHero == null) {
          await local.deleteHero(details.localHero.id);
          await _saveMetadata(
            key: _heroKey(details.localHero.id),
            localHash: '',
            remoteHash: '',
            remoteRevision: remoteRecord.revision,
            isDeleted: true,
          );
        } else {
          await local.saveHero(remoteHero);
          await _storeHeroMetadata(remoteHero, remoteRecord);
        }
      case SyncResolutionChoice.keepBoth:
        if (remoteHero == null) {
          final saved = await remote.saveHero(
            details.localHero,
            previousRevision: remoteRecord.revision,
          );
          await _storeHeroMetadata(details.localHero, saved);
          return;
        }
        await local.saveHero(remoteHero);
        await _storeHeroMetadata(remoteHero, remoteRecord);

        const uuid = Uuid();
        final copy = details.localHero.copyWith(
          id: uuid.v4(),
          name: '${details.localHero.name} (lokale Kopie)',
        );
        await local.saveHero(copy);
        final savedCopy = await remote.saveHero(copy, previousRevision: null);
        await _storeHeroMetadata(copy, savedCopy);
    }
  }

  /// Loest einen Loesch-Konflikt auf.
  ///
  /// `keepLocal` setzt die lokale Loeschung remote durch; `keepRemote`
  /// stellt die Online-Version lokal wieder her. `keepBoth` wird fuer
  /// Loesch-Konflikte nicht angeboten und verhaelt sich wie `keepRemote`.
  Future<void> _resolveDeletedHeroConflict(
    _DeletedHeroConflictDetails details,
    SyncResolutionChoice resolution,
  ) async {
    final remoteRecord = details.remoteRecord;
    switch (resolution) {
      case SyncResolutionChoice.keepLocal:
        final deleted = await remote.deleteHero(
          details.heroId,
          previousRevision: remoteRecord.revision,
        );
        await _saveMetadata(
          key: _heroKey(details.heroId),
          localHash: '',
          remoteHash: '',
          remoteRevision: deleted.revision,
          isDeleted: true,
        );
        await _tombstoneStateBestEffort(details.heroId);
      case SyncResolutionChoice.keepRemote:
      case SyncResolutionChoice.keepBoth:
        final remoteHero = remoteRecord.hero;
        if (remoteHero == null) {
          await _saveMetadata(
            key: _heroKey(details.heroId),
            localHash: '',
            remoteHash: '',
            remoteRevision: remoteRecord.revision,
            isDeleted: true,
          );
          return;
        }
        await local.saveHero(remoteHero);
        await _storeHeroMetadata(remoteHero, remoteRecord);
    }
  }

  Future<void> _resolveOfflineHeroConflict(
    _OfflineHeroConflictDetails details,
    SyncResolutionChoice resolution,
  ) async {
    switch (resolution) {
      case SyncResolutionChoice.keepRemote:
        return;
      case SyncResolutionChoice.keepLocal:
        await saveHero(details.offlineHero);
      case SyncResolutionChoice.keepBoth:
        const uuid = Uuid();
        final copy = details.offlineHero.copyWith(
          id: uuid.v4(),
          name: '${details.offlineHero.name} (Offline-Kopie)',
        );
        await saveHero(copy);
    }
  }

  Future<void> _resolveStateConflict(
    _StateConflictDetails details,
    SyncResolutionChoice resolution,
  ) async {
    final stateGateway = _stateRemote;
    if (stateGateway == null) {
      return;
    }
    final remoteRecord = details.remoteRecord;
    final remoteState = remoteRecord.state;
    switch (resolution) {
      case SyncResolutionChoice.keepLocal:
      case SyncResolutionChoice.keepBoth:
        final saved = await stateGateway.saveHeroState(
          remoteRecord.heroId,
          details.localState,
          previousRevision: remoteRecord.revision,
        );
        await _storeStateMetadata(
          remoteRecord.heroId,
          details.localState,
          saved,
        );
      case SyncResolutionChoice.keepRemote:
        if (remoteRecord.isDeleted || remoteState == null) {
          await local.saveHeroState(
            remoteRecord.heroId,
            const HeroState.empty(),
          );
          await _saveMetadata(
            key: _stateKey(remoteRecord.heroId),
            localHash: '',
            remoteHash: '',
            remoteRevision: remoteRecord.revision,
            isDeleted: true,
          );
        } else {
          await local.saveHeroState(remoteRecord.heroId, remoteState);
          await _storeStateMetadata(
            remoteRecord.heroId,
            remoteState,
            remoteRecord,
          );
        }
    }
  }

  Future<void> _storeHeroMetadata(
    HeroSheet hero,
    RemoteHeroRecord record,
  ) async {
    await _saveMetadata(
      key: _heroKey(hero.id),
      localHash: heroContentHash(hero),
      remoteHash: _remoteHeroHash(record),
      remoteRevision: record.revision,
      isDeleted: record.isDeleted,
    );
  }

  Future<void> _storeStateMetadata(
    String heroId,
    HeroState state,
    RemoteHeroStateRecord record,
  ) async {
    await _saveMetadata(
      key: _stateKey(heroId),
      localHash: stableContentHash(state.toJson()),
      remoteHash: _remoteStateHash(record),
      remoteRevision: record.revision,
      isDeleted: record.isDeleted,
    );
  }

  Future<void> _saveMetadata({
    required SyncObjectKey key,
    required String localHash,
    required String remoteHash,
    required String remoteRevision,
    bool isDeleted = false,
  }) async {
    await metadataStore.save(
      SyncMetadata(
        key: key,
        localHash: localHash,
        remoteHash: remoteHash,
        remoteRevision: remoteRevision,
        updatedAt: DateTime.now().toUtc(),
        isDeleted: isDeleted,
      ),
    );
  }

  void _addConflictToStatus(SyncConflict conflict) {
    _emitStatus(
      _status.copyWith(
        openConflicts: <SyncConflict>[..._status.openConflicts, conflict],
      ),
    );
  }

  void _removeConflictFromStatus(String conflictId) {
    _emitStatus(
      _status.copyWith(
        openConflicts: _status.openConflicts
            .where((conflict) => conflict.id != conflictId)
            .toList(growable: false),
      ),
    );
  }

  void _emitStatus(SyncStatusSnapshot status) {
    _status = status.copyWith(accountId: accountId, email: accountEmail);
    _statusController.add(currentStatus);
  }

  void _handleRemoteStreamError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'syncing_hero_repository',
        context: ErrorDescription('Remote-Listener-Fehler'),
      ),
    );
    _emitStatus(
      _status.copyWith(
        lastFailure: SyncFailure.fromError(
          error,
          occurredAt: DateTime.now().toUtc(),
        ),
      ),
    );
  }

  String _remoteHeroHash(RemoteHeroRecord record) {
    if (record.contentHash.isNotEmpty) return record.contentHash;
    final hero = record.hero;
    if (hero == null) return stableContentHash(null);
    return heroContentHash(hero);
  }

  String _remoteStateHash(RemoteHeroStateRecord record) {
    return record.contentHash.isNotEmpty
        ? record.contentHash
        : stableContentHash(record.state?.toJson());
  }

  SyncObjectKey _heroKey(String heroId) {
    return SyncObjectKey(type: SyncObjectType.hero, id: heroId);
  }

  SyncObjectKey _stateKey(String heroId) {
    return SyncObjectKey(type: SyncObjectType.heroState, id: heroId);
  }

  @override
  Future<void> deleteHero(String heroId) async {
    await local.deleteHero(heroId);
    final metadata = await metadataStore.load(_heroKey(heroId));
    if (metadata != null && !metadata.isDeleted) {
      // Loesch-Absicht festhalten: leerer localHash bei unveraenderter
      // Remote-Baseline. Verhindert, dass ein fehlgeschlagener Push den
      // Helden beim naechsten Sync aus der Cloud wiederbelebt; der Sync
      // holt die Loeschung stattdessen nach.
      await _saveMetadata(
        key: _heroKey(heroId),
        localHash: '',
        remoteHash: metadata.remoteHash,
        remoteRevision: metadata.remoteRevision,
      );
    }
    await _pushRemoteBestEffort(
      () => _pushHeroDelete(heroId),
      context: 'Loeschung von Held $heroId konnte nicht in die Cloud '
          'uebertragen werden',
    );
  }

  Future<void> _pushHeroDelete(String heroId) async {
    final metadata = await metadataStore.load(_heroKey(heroId));
    final RemoteHeroRecord deleted;
    try {
      deleted = await remote.deleteHero(
        heroId,
        previousRevision: metadata?.remoteRevision,
      );
    } on SyncPreconditionException {
      // Remote wurde parallel geaendert: Loeschung nicht erzwingen, sondern
      // den Loesch-Konflikt mit dem frischen Remote-Stand oeffnen.
      final fresh = await remote.loadHero(heroId);
      if (fresh != null && !fresh.isDeleted) {
        _openDeletedHeroConflict(heroId: heroId, remoteRecord: fresh);
      }
      return;
    }
    await _saveMetadata(
      key: _heroKey(heroId),
      localHash: '',
      remoteHash: '',
      remoteRevision: deleted.revision,
      isDeleted: true,
    );
    await _tombstoneStateBestEffort(heroId);
  }

  /// Loescht das Zustandsdokument eines bereits geloeschten Helden remote.
  ///
  /// Nutzt die frische Remote-Revision, da der Zustand ohne Helden keinen
  /// Wert mehr hat; ein Precondition-Fehler wird still ignoriert und beim
  /// naechsten Sync erneut versucht.
  Future<void> _tombstoneStateBestEffort(String heroId) async {
    final stateGateway = _stateRemote;
    if (stateGateway == null) {
      return;
    }
    final fresh = await stateGateway.loadHeroState(heroId);
    if (fresh == null || fresh.isDeleted) {
      return;
    }
    try {
      final deletedState = await stateGateway.deleteHeroState(
        heroId,
        previousRevision: fresh.revision,
      );
      await _saveMetadata(
        key: _stateKey(heroId),
        localHash: '',
        remoteHash: '',
        remoteRevision: deletedState.revision,
        isDeleted: true,
      );
    } on SyncPreconditionException {
      // Zustandsdokument wurde parallel geaendert; wird beim naechsten
      // Sync bereinigt.
    }
  }

  @override
  Future<List<HeroSheet>> listHeroes() {
    return local.listHeroes();
  }

  @override
  Future<HeroSheet?> loadHeroById(String heroId) {
    return local.loadHeroById(heroId);
  }

  @override
  Future<HeroState?> loadHeroState(String heroId) {
    return local.loadHeroState(heroId);
  }

  @override
  Future<void> saveHero(HeroSheet hero) async {
    final stamped = hero.copyWith(lastModified: DateTime.now().toUtc());
    await local.saveHero(stamped);
    await _pushRemoteBestEffort(
      () => _pushHeroIfSafe(stamped),
      context: 'Held ${hero.id} konnte nicht in die Cloud uebertragen werden',
    );
  }

  @override
  Future<void> saveHeroState(String heroId, HeroState state) async {
    await local.saveHeroState(heroId, state);
    await _pushRemoteBestEffort(
      () => _pushHeroStateIfSafe(heroId, state),
      context:
          'Zustand von Held $heroId konnte nicht in die Cloud '
          'uebertragen werden',
    );
  }

  /// Fuehrt einen Remote-Push local-first aus.
  ///
  /// Auth- und Netzwerkfehler gelten nicht als Fehlschlag des Speicherns:
  /// Der lokale Write bleibt bestehen, der Fehler landet nur im Sync-Status
  /// und der naechste [syncNow] holt den Push nach (localHash weicht dann
  /// von den Sync-Metadaten ab).
  Future<void> _pushRemoteBestEffort(
    Future<void> Function() push, {
    required String context,
  }) async {
    try {
      await push();
    } on SyncException catch (error, stackTrace) {
      if (error is SyncPreconditionException) {
        rethrow;
      }
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'syncing_hero_repository',
          context: ErrorDescription(context),
        ),
      );
      _emitStatus(
        _status.copyWith(
          lastFailure: SyncFailure.fromError(
            error,
            occurredAt: DateTime.now().toUtc(),
          ),
        ),
      );
    }
  }

  @override
  Stream<Map<String, HeroSheet>> watchHeroIndex() {
    return local.watchHeroIndex();
  }

  @override
  Stream<HeroState> watchHeroState(String heroId) {
    return local.watchHeroState(heroId);
  }

  /// Beendet Remote-Subscriptions und Status-Streams.
  Future<void> close() async {
    await _heroSubscription?.cancel();
    await _stateSubscription?.cancel();
    await _statusController.close();
  }
}

class _HeroConflictDetails {
  const _HeroConflictDetails({
    required this.conflict,
    required this.localHero,
    required this.remoteRecord,
  });

  final SyncConflict conflict;
  final HeroSheet localHero;
  final RemoteHeroRecord remoteRecord;
}

class _OfflineHeroConflictDetails {
  const _OfflineHeroConflictDetails({
    required this.conflict,
    required this.offlineHero,
    this.accountHero,
  });

  final SyncConflict conflict;
  final HeroSheet offlineHero;

  /// Bereits im Konto vorhandene Version oder `null`, wenn das Konto den
  /// Helden noch nicht kennt.
  final HeroSheet? accountHero;
}

class _DeletedHeroConflictDetails {
  const _DeletedHeroConflictDetails({
    required this.conflict,
    required this.heroId,
    required this.remoteRecord,
  });

  final SyncConflict conflict;
  final String heroId;
  final RemoteHeroRecord remoteRecord;
}

class _StateConflictDetails {
  const _StateConflictDetails({
    required this.conflict,
    required this.localState,
    required this.remoteRecord,
  });

  final SyncConflict conflict;
  final HeroState localState;
  final RemoteHeroStateRecord remoteRecord;
}
