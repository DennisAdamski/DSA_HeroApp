import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';

/// Beschreibt die Arten von Nutzerobjekten, die der Konto-Sync verwaltet.
enum SyncObjectType {
  /// Persistiertes Heldenblatt (`HeroSheet`).
  hero,

  /// Laufzeitzustand eines Helden (`HeroState`).
  heroState,

  /// Benutzerdefinierter Katalogeintrag.
  customCatalogEntry,

  /// Importiertes Hausregel-Paket.
  houseRulePack,

  /// Konto-synchronisierte App-Einstellungen oder Geheimnisse.
  settings,
}

/// Nutzerentscheidung fuer einen offenen Sync-Konflikt.
enum SyncResolutionChoice {
  /// Lokale Version behalten und remote damit ueberschreiben.
  keepLocal,

  /// Online-Version uebernehmen und lokal damit ueberschreiben.
  keepRemote,

  /// Beide Versionen erhalten, sofern der Objekttyp Kopien unterstuetzt.
  keepBoth,
}

/// Eindeutiger Schluessel fuer Sync-Metadaten eines Nutzerobjekts.
class SyncObjectKey {
  /// Erstellt einen stabilen Sync-Schluessel aus Typ und Objekt-ID.
  const SyncObjectKey({required this.type, required this.id});

  /// Typ des synchronisierten Objekts.
  final SyncObjectType type;

  /// Stabile Objekt-ID innerhalb des Typs.
  final String id;

  /// Speicherschluessel fuer Hive/Firestore-Metadaten.
  String get storageKey => '${type.name}::$id';

  /// Parst einen zuvor erzeugten [storageKey].
  static SyncObjectKey parse(String raw) {
    final separator = raw.indexOf('::');
    if (separator <= 0 || separator == raw.length - 2) {
      throw FormatException('Ungueltiger Sync-Schluessel: $raw');
    }
    final typeName = raw.substring(0, separator);
    final id = raw.substring(separator + 2);
    final type = SyncObjectType.values.firstWhere(
      (candidate) => candidate.name == typeName,
      orElse: () =>
          throw FormatException('Unbekannter Sync-Objekttyp: $typeName'),
    );
    return SyncObjectKey(type: type, id: id);
  }

  @override
  bool operator ==(Object other) {
    return other is SyncObjectKey && other.type == type && other.id == id;
  }

  @override
  int get hashCode => Object.hash(type, id);
}

/// Persistierte Revisions- und Hash-Information fuer ein Sync-Objekt.
class SyncMetadata {
  /// Erstellt einen Metadatensatz fuer ein synchronisiertes Objekt.
  const SyncMetadata({
    required this.key,
    required this.localHash,
    required this.remoteHash,
    required this.remoteRevision,
    required this.updatedAt,
    this.isDeleted = false,
  });

  /// Objekt, zu dem diese Metadaten gehoeren.
  final SyncObjectKey key;

  /// Hash des lokalen Stands bei der letzten erfolgreichen Synchronisierung.
  final String localHash;

  /// Hash des Remote-Stands bei der letzten erfolgreichen Synchronisierung.
  final String remoteHash;

  /// Remote-Revision bei der letzten erfolgreichen Synchronisierung.
  final String remoteRevision;

  /// Zeitpunkt der letzten Metadaten-Aktualisierung.
  final DateTime updatedAt;

  /// Ob die letzte synchronisierte Remote-Revision ein Tombstone ist.
  final bool isDeleted;

  /// Serialisiert die Metadaten fuer Hive.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'key': key.storageKey,
      'localHash': localHash,
      'remoteHash': remoteHash,
      'remoteRevision': remoteRevision,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  /// Laedt Metadaten tolerant aus Persistenzdaten.
  static SyncMetadata fromJson(Map<String, dynamic> json) {
    final updatedAtRaw = json['updatedAt'] as String?;
    return SyncMetadata(
      key: SyncObjectKey.parse(json['key'] as String? ?? ''),
      localHash: json['localHash'] as String? ?? '',
      remoteHash: json['remoteHash'] as String? ?? '',
      remoteRevision: json['remoteRevision'] as String? ?? '',
      updatedAt: DateTime.tryParse(updatedAtRaw ?? '') ?? DateTime.now(),
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }
}

/// Beschreibt einen offenen Konflikt zwischen lokalem und Online-Stand.
class SyncConflict {
  /// Erstellt einen UI- und Service-tauglichen Konfliktdatensatz.
  const SyncConflict({
    required this.id,
    required this.objectType,
    required this.objectId,
    required this.title,
    required this.localSummary,
    required this.remoteSummary,
    required this.detectedAt,
    this.supportsKeepBoth = false,
    this.localApTotal,
    this.localApAvailable,
    this.localUpdatedAt,
    this.remoteApTotal,
    this.remoteApAvailable,
    this.remoteUpdatedAt,
  });

  /// Eindeutige Konflikt-ID.
  final String id;

  /// Typ des betroffenen Objekts.
  final SyncObjectType objectType;

  /// Objekt-ID des betroffenen Objekts.
  final String objectId;

  /// Kurztitel fuer Konfliktlisten.
  final String title;

  /// Zusammenfassung der lokalen Seite.
  final String localSummary;

  /// Zusammenfassung der Remote-Seite.
  final String remoteSummary;

  /// Zeitpunkt der Konflikterkennung.
  final DateTime detectedAt;

  /// Ob `Beide behalten` fuer diesen Konflikt sinnvoll anwendbar ist.
  final bool supportsKeepBoth;

  /// Gesamt-AP der lokalen Version (nur fuer Hero-Konflikte).
  final int? localApTotal;

  /// Freie AP der lokalen Version (nur fuer Hero-Konflikte).
  final int? localApAvailable;

  /// Letzter Speicherzeitpunkt der lokalen Version.
  final DateTime? localUpdatedAt;

  /// Gesamt-AP der Remote-Version (nur fuer Hero-Konflikte).
  final int? remoteApTotal;

  /// Freie AP der Remote-Version (nur fuer Hero-Konflikte).
  final int? remoteApAvailable;

  /// Letzter Speicherzeitpunkt der Remote-Version.
  final DateTime? remoteUpdatedAt;
}

/// Sichtbarer Laufzeitstatus des Konto-Syncs.
class SyncStatusSnapshot {
  /// Erstellt einen unveraenderlichen Sync-Status fuer Provider und UI.
  const SyncStatusSnapshot({
    this.accountId,
    this.email,
    this.isSyncing = false,
    this.lastSuccessfulSync,
    this.lastFailure,
    this.openConflicts = const <SyncConflict>[],
  });

  /// ID des angemeldeten Kontos oder `null` im Offline-Modus.
  final String? accountId;

  /// Angezeigte E-Mail-Adresse des angemeldeten Kontos.
  final String? email;

  /// Ob gerade ein manueller oder automatischer Sync laeuft.
  final bool isSyncing;

  /// Zeitpunkt des letzten vollstaendig erfolgreichen Syncs.
  final DateTime? lastSuccessfulSync;

  /// Letzter Sync-Fehler mit Kategorie fuer die UI.
  final SyncFailure? lastFailure;

  /// Letzter Sync-Fehler als benutzerlesbarer Text.
  String? get lastError => lastFailure?.message;

  /// Noch nicht geloeste Konflikte.
  final List<SyncConflict> openConflicts;

  /// True, wenn gerade ein Konto mit dem Sync verbunden ist.
  bool get isOnlineAccount => accountId != null && accountId!.isNotEmpty;

  /// Erstellt eine angepasste Kopie fuer Status-Updates.
  SyncStatusSnapshot copyWith({
    String? accountId,
    String? email,
    bool? isSyncing,
    Object? lastSuccessfulSync = _copySentinel,
    Object? lastFailure = _copySentinel,
    List<SyncConflict>? openConflicts,
  }) {
    return SyncStatusSnapshot(
      accountId: accountId ?? this.accountId,
      email: email ?? this.email,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSuccessfulSync: identical(lastSuccessfulSync, _copySentinel)
          ? this.lastSuccessfulSync
          : lastSuccessfulSync as DateTime?,
      lastFailure: identical(lastFailure, _copySentinel)
          ? this.lastFailure
          : lastFailure as SyncFailure?,
      openConflicts: openConflicts ?? this.openConflicts,
    );
  }
}

const Object _copySentinel = Object();

/// Erzeugt einen stabilen Content-Hash fuer ein [HeroSheet].
///
/// Schliesst [HeroSheet.lastModified] aus, damit Zeitstempel-Aenderungen
/// allein keine Sync-Konflikte ausloesen.
String heroContentHash(HeroSheet hero) {
  final json = hero.toJson()..remove('lastModified');
  return stableContentHash(json);
}

/// Erzeugt einen stabilen SHA-256-Hash fuer JSON-kompatible Daten.
///
/// Map-Schluessel werden rekursiv sortiert, damit unterschiedliche
/// Einfuege-Reihenfolgen denselben Hash ergeben.
String stableContentHash(Object? value) {
  final canonical = _canonicalize(value);
  final json = jsonEncode(canonical);
  final bytes = Uint8List.fromList(utf8.encode(json));
  final digest = SHA256Digest().process(bytes);
  return base64Url.encode(digest);
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final sortedKeys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in sortedKeys) key: _canonicalize(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList(growable: false);
  }
  return value;
}
