/// Konfiguration fuer den optionalen Remote-Bezug der Regel-Index-DB.
///
/// Die Zugangsdaten zum WebDAV-Ordner (z. B. Fritz!NAS) werden fuer
/// Release-Builds per `--dart-define` fest eingebettet, damit alle
/// App-Nutzer ohne manuelle Konfiguration versorgt werden. Die hier
/// persistierten Felder dienen nur als optionaler Override (z. B. fuer
/// Entwicklung/Tests gegen einen anderen Server); ein leerer Wert bedeutet
/// „Build-Default verwenden“.
class RulesIndexRemoteConfig {
  const RulesIndexRemoteConfig({
    this.serverUrl = '',
    this.username = '',
    this.password = '',
    this.lastSyncedAt,
  });

  /// Override der Server-URL (WebDAV-Endpunkt der `index.sqlite`).
  final String serverUrl;

  /// Override des WebDAV-Benutzernamens.
  final String username;

  /// Override des WebDAV-Passworts.
  final String password;

  /// Zeitpunkt des letzten erfolgreichen Downloads.
  final DateTime? lastSyncedAt;

  static const String _buildDefaultServerUrl = String.fromEnvironment(
    'RULES_INDEX_SERVER_URL',
  );
  static const String _buildDefaultUsername = String.fromEnvironment(
    'RULES_INDEX_SERVER_USER',
  );
  static const String _buildDefaultPassword = String.fromEnvironment(
    'RULES_INDEX_SERVER_PASSWORD',
  );

  /// Wirksame Server-URL: expliziter Override vor Build-Default.
  String get effectiveServerUrl =>
      serverUrl.isNotEmpty ? serverUrl : _buildDefaultServerUrl;

  /// Wirksamer Benutzername: expliziter Override vor Build-Default.
  String get effectiveUsername =>
      username.isNotEmpty ? username : _buildDefaultUsername;

  /// Wirksames Passwort: expliziter Override vor Build-Default.
  String get effectivePassword =>
      password.isNotEmpty ? password : _buildDefaultPassword;

  /// Ob ein Server (Override oder Build-Default) konfiguriert ist.
  bool get isConfigured => effectiveServerUrl.isNotEmpty;

  RulesIndexRemoteConfig copyWith({
    String? serverUrl,
    String? username,
    String? password,
    Object? lastSyncedAt = _copySentinel,
  }) {
    return RulesIndexRemoteConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      lastSyncedAt: identical(lastSyncedAt, _copySentinel)
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
    );
  }

  Map<String, dynamic> toJson() => {
    'serverUrl': serverUrl,
    'username': username,
    'password': password,
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
  };

  static RulesIndexRemoteConfig fromJson(Map<String, dynamic> json) {
    final rawLastSyncedAt = json['lastSyncedAt'] as String?;
    return RulesIndexRemoteConfig(
      serverUrl: (json['serverUrl'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      password: (json['password'] as String?) ?? '',
      lastSyncedAt: rawLastSyncedAt == null
          ? null
          : DateTime.tryParse(rawLastSyncedAt),
    );
  }
}

const Object _copySentinel = Object();
