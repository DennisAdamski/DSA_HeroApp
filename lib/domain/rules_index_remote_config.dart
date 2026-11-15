import 'package:dsa_heldenverwaltung/domain/copy_with_sentinel.dart';

/// Stand der über die Cloud bezogenen Regel-Wissensbasis auf diesem Gerät.
///
/// Gerätelokal in den App-Einstellungen. Der frühere WebDAV-Bezug (Server-URL,
/// Benutzer, Passwort) ist entfallen; gespeicherte Zugangsdaten daraus werden
/// beim Lesen übergangen und beim nächsten Speichern verworfen.
class RulesIndexRemoteConfig {
  const RulesIndexRemoteConfig({this.lastSyncedAt, this.installedVersion = ''});

  /// Zeitpunkt des letzten erfolgreichen Downloads.
  final DateTime? lastSyncedAt;

  /// Version der zuletzt über den Cloud-Zugang installierten Wissensbasis
  /// (Veröffentlichungszeitpunkt); leer, solange keine installiert wurde oder
  /// die Cache-Datei von Hand ersetzt wurde.
  final String installedVersion;

  RulesIndexRemoteConfig copyWith({
    Object? lastSyncedAt = keepFieldValue,
    String? installedVersion,
  }) {
    return RulesIndexRemoteConfig(
      lastSyncedAt: identical(lastSyncedAt, keepFieldValue)
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
      installedVersion: installedVersion ?? this.installedVersion,
    );
  }

  Map<String, dynamic> toJson() => {
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    if (installedVersion.isNotEmpty) 'installedVersion': installedVersion,
  };

  static RulesIndexRemoteConfig fromJson(Map<String, dynamic> json) {
    final rawLastSyncedAt = json['lastSyncedAt'] as String?;
    return RulesIndexRemoteConfig(
      lastSyncedAt: rawLastSyncedAt == null
          ? null
          : DateTime.tryParse(rawLastSyncedAt),
      installedVersion: (json['installedVersion'] as String?) ?? '',
    );
  }
}
