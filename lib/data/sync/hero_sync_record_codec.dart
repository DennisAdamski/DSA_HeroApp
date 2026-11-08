import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/data/sync/remote_hero_sync_gateway.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

/// Feldnamen des Firestore-Dokumentschemas für den Konto-Sync.
///
/// Das Wire-Format wird vom cloud_firestore-Plugin und vom REST-Transport
/// gemeinsam genutzt und darf nicht divergieren.
abstract final class HeroSyncRecordFields {
  static const String deleted = 'deleted';
  static const String payload = 'payload';
  static const String revision = 'revision';
  static const String contentHash = 'contentHash';
  static const String lastModified = 'lastModified';
}

const Uuid _uuid = Uuid();

/// Erzeugt eine neue, zeitlich sortierbare Revision (Micros + UUID).
String newSyncRevision() {
  return '${DateTime.now().toUtc().microsecondsSinceEpoch}-${_uuid.v4()}';
}

/// Liest die Revision eines Remote-Dokuments inklusive Legacy-Fallbacks
/// für Dokumente, die vor der Revisions-Einführung geschrieben wurden.
String readSyncRevision(
  Map<String, dynamic> data,
  DateTime? updatedAt, {
  String fallbackHash = '',
}) {
  final revision = data[HeroSyncRecordFields.revision] as String?;
  if (revision != null && revision.isNotEmpty) {
    return revision;
  }
  if (updatedAt != null) {
    return 'legacy-${updatedAt.toUtc().microsecondsSinceEpoch}';
  }
  return 'legacy-$fallbackHash';
}

/// Art eines Sync-Dokuments; bestimmt den Inhalts-Hash alter Dokumente.
enum SyncDokumentArt {
  /// Heldenbogen unter `heroes/`.
  held,

  /// Laufzeitzustand unter `hero_states/`.
  zustand,
}

/// Liest die Revision eines gespeicherten Dokuments so, wie die Decoder sie
/// melden.
///
/// Die Vorbedingung beim Schreiben vergleicht mit der Revision, die der
/// Client beim Lesen bekommen hat. Für alte Dokumente ohne Revision und ohne
/// Zeitstempel muss deshalb derselbe Rückfall-Hash entstehen wie in
/// [decodeRemoteHeroRecord] und [decodeRemoteHeroStateRecord]; sonst schlägt
/// jeder Push dauerhaft mit einer Vorbedingungsverletzung fehl.
String revisionAusDokument(
  Map<String, dynamic> data,
  DateTime? updatedAt, {
  required SyncDokumentArt art,
}) {
  final gespeichert = data[HeroSyncRecordFields.revision] as String?;
  final geloescht = data[HeroSyncRecordFields.deleted] as bool? ?? false;
  if ((gespeichert != null && gespeichert.isNotEmpty) ||
      updatedAt != null ||
      geloescht) {
    return readSyncRevision(data, updatedAt);
  }
  final payload = data[HeroSyncRecordFields.payload];
  if (payload is! Map) {
    return readSyncRevision(data, updatedAt);
  }
  return readSyncRevision(
    data,
    updatedAt,
    fallbackHash: _inhaltsHash(data, _castMap(payload), art),
  );
}

String _inhaltsHash(
  Map<String, dynamic> data,
  Map<String, dynamic> payload,
  SyncDokumentArt art,
) =>
    data[HeroSyncRecordFields.contentHash] as String? ??
    switch (art) {
      SyncDokumentArt.held => heroContentHash(HeroSheet.fromJson(payload)),
      SyncDokumentArt.zustand => heroStateContentHash(
        HeroState.fromJson(payload),
      ),
    };

/// Schreib-Felder für einen Helden- oder Zustands-Payload.
///
/// [lastModifiedValue] ist transportspezifisch: `FieldValue.serverTimestamp()`
/// beim Plugin, `DateTime.now().toUtc()` beim REST-Transport.
Map<String, dynamic> encodeSyncPayloadWriteFields({
  required Map<String, dynamic> payload,
  required String revision,
  required String contentHash,
  required Object lastModifiedValue,
}) {
  return <String, dynamic>{
    HeroSyncRecordFields.deleted: false,
    HeroSyncRecordFields.payload: payload,
    HeroSyncRecordFields.revision: revision,
    HeroSyncRecordFields.contentHash: contentHash,
    HeroSyncRecordFields.lastModified: lastModifiedValue,
  };
}

/// Schreib-Felder für einen Tombstone (gelöschtes Dokument).
Map<String, dynamic> encodeSyncTombstoneWriteFields({
  required String revision,
  required Object lastModifiedValue,
}) {
  return <String, dynamic>{
    HeroSyncRecordFields.deleted: true,
    HeroSyncRecordFields.payload: null,
    HeroSyncRecordFields.revision: revision,
    HeroSyncRecordFields.contentHash: '',
    HeroSyncRecordFields.lastModified: lastModifiedValue,
  };
}

/// Dekodiert ein Helden-Dokument aus bereits transport-normalisierten Feldern.
///
/// [updatedAt] liefert der Transport (Plugin: `Timestamp.toDate()`,
/// REST: `DateTime`/ISO-String), da nur das Timestamp-Lesen
/// transportspezifisch ist.
RemoteHeroRecord? decodeRemoteHeroRecord({
  required String id,
  required Map<String, dynamic> data,
  required DateTime? updatedAt,
}) {
  final deleted = data[HeroSyncRecordFields.deleted] as bool? ?? false;
  if (deleted) {
    return RemoteHeroRecord(
      id: id,
      hero: null,
      revision: readSyncRevision(data, updatedAt),
      contentHash: '',
      isDeleted: true,
      updatedAt: updatedAt,
    );
  }

  final payload = data[HeroSyncRecordFields.payload];
  if (payload is! Map) {
    return null;
  }
  final hero = HeroSheet.fromJson(_castMap(payload));
  final contentHash =
      data[HeroSyncRecordFields.contentHash] as String? ??
      heroContentHash(hero);
  // Dieselbe Formel wie `revisionAusDokument` (Schreibvorbedingung).
  return RemoteHeroRecord(
    id: id,
    hero: hero,
    revision: readSyncRevision(data, updatedAt, fallbackHash: contentHash),
    contentHash: contentHash,
    isDeleted: false,
    updatedAt: updatedAt,
  );
}

/// Dekodiert ein Zustands-Dokument aus transport-normalisierten Feldern.
RemoteHeroStateRecord? decodeRemoteHeroStateRecord({
  required String heroId,
  required Map<String, dynamic> data,
  required DateTime? updatedAt,
}) {
  final deleted = data[HeroSyncRecordFields.deleted] as bool? ?? false;
  if (deleted) {
    return RemoteHeroStateRecord(
      heroId: heroId,
      state: null,
      revision: readSyncRevision(data, updatedAt),
      contentHash: '',
      isDeleted: true,
      updatedAt: updatedAt,
    );
  }

  final payload = data[HeroSyncRecordFields.payload];
  if (payload is! Map) {
    return null;
  }
  final state = HeroState.fromJson(_castMap(payload));
  final contentHash =
      data[HeroSyncRecordFields.contentHash] as String? ??
      heroStateContentHash(state);
  return RemoteHeroStateRecord(
    heroId: heroId,
    state: state,
    revision: readSyncRevision(data, updatedAt, fallbackHash: contentHash),
    contentHash: contentHash,
    isDeleted: false,
    updatedAt: updatedAt,
  );
}

Map<String, dynamic> _castMap(Map<dynamic, dynamic> raw) {
  return raw.map((key, value) => MapEntry(key.toString(), value));
}
