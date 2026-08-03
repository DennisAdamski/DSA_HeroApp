import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Fehlerarten beim Download der Regel-Index-Datenbank vom Server.
enum RulesIndexDownloadErrorKind {
  /// Zugangsdaten wurden vom Server abgelehnt (401/403).
  unauthorized,

  /// Die Datei existiert unter der konfigurierten URL nicht (404).
  notFound,

  /// Server nicht erreichbar (DNS/TLS/Verbindungsfehler).
  network,

  /// Sonstiger, unerwarteter HTTP-Status.
  other,
}

/// Fehler beim Download der Regel-Index-Datenbank.
class RulesIndexDownloadException implements Exception {
  const RulesIndexDownloadException(this.kind, this.message);

  final RulesIndexDownloadErrorKind kind;
  final String message;

  @override
  String toString() => message;
}

/// Laedt die Regel-Index-Datenbank per HTTP(S) GET von einem Server-Ordner
/// (z. B. einer Fritz!NAS/WebDAV-Freigabe) herunter.
///
/// Der Dateipfad ist fest konfiguriert (keine Verzeichnis-Navigation
/// noetig), daher reicht ein einfacher GET mit selbst gebautem
/// Basic-Auth-Header — ein dediziertes WebDAV-Package ist nicht noetig.
class RulesIndexRemoteClient {
  RulesIndexRemoteClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Laedt die Index-Datenbank herunter und liefert die Rohbytes.
  ///
  /// Wirft eine [RulesIndexDownloadException], wenn der Server nicht
  /// erreichbar ist oder einen Fehlerstatus liefert.
  Future<Uint8List> download({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final Uri uri;
    try {
      uri = Uri.parse(serverUrl);
    } on FormatException {
      throw RulesIndexDownloadException(
        RulesIndexDownloadErrorKind.other,
        'Ungültige Server-URL: $serverUrl',
      );
    }

    final headers = <String, String>{
      if (username.isNotEmpty || password.isNotEmpty)
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$username:$password'))}',
    };

    final http.Response response;
    try {
      response = await _httpClient.get(uri, headers: headers);
    } on Object catch (error) {
      throw RulesIndexDownloadException(
        RulesIndexDownloadErrorKind.network,
        'Server nicht erreichbar: $error',
      );
    }

    switch (response.statusCode) {
      case 200:
        return response.bodyBytes;
      case 401:
      case 403:
        throw const RulesIndexDownloadException(
          RulesIndexDownloadErrorKind.unauthorized,
          'Zugangsdaten für den Server wurden abgelehnt.',
        );
      case 404:
        throw const RulesIndexDownloadException(
          RulesIndexDownloadErrorKind.notFound,
          'Die Index-Datei wurde auf dem Server nicht gefunden.',
        );
      default:
        throw RulesIndexDownloadException(
          RulesIndexDownloadErrorKind.other,
          'Unerwartete Serverantwort (${response.statusCode}).',
        );
    }
  }
}
