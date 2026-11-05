import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Fehlerarten beim Download der Regel-Index-Datenbank vom Server.
enum RulesIndexDownloadErrorKind {
  /// Zugangsdaten wurden vom Server abgelehnt (401/403).
  unauthorized,

  /// Die Datei existiert unter der URL nicht (404).
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

/// Laedt die veroeffentlichte Regel-Wissensbasis von einer signierten URL
/// (`RulesIndexRelease.url`), ohne Zugangsdaten.
class RulesIndexRemoteClient {
  RulesIndexRemoteClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Laedt eine Datei von einer **signierten** URL, ohne Zugangsdaten, und
  /// meldet den Fortschritt.
  ///
  /// [onProgress] bekommt die bisher empfangenen Bytes. Wegen
  /// `Content-Encoding: gzip` sind das bereits entpackte Bytes, sie lassen
  /// sich also gegen die entpackte Groesse (`RulesIndexRelease.sizeBytes`)
  /// halten. Wirft eine [RulesIndexDownloadException].
  Future<Uint8List> downloadSigned(
    Uri url, {
    void Function(int received)? onProgress,
  }) async {
    final http.StreamedResponse response;
    try {
      response = await _httpClient.send(http.Request('GET', url));
    } on Object catch (error) {
      throw RulesIndexDownloadException(
        RulesIndexDownloadErrorKind.network,
        'Server nicht erreichbar: $error',
      );
    }
    switch (response.statusCode) {
      case 200:
        break;
      case 401:
      case 403:
        throw const RulesIndexDownloadException(
          RulesIndexDownloadErrorKind.unauthorized,
          'Die Download-Adresse ist abgelaufen. Bitte erneut laden.',
        );
      case 404:
        throw const RulesIndexDownloadException(
          RulesIndexDownloadErrorKind.notFound,
          'Die Wissensbasis wurde auf dem Server nicht gefunden.',
        );
      default:
        throw RulesIndexDownloadException(
          RulesIndexDownloadErrorKind.other,
          'Unerwartete Serverantwort (${response.statusCode}).',
        );
    }
    final builder = BytesBuilder(copy: false);
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        builder.add(chunk);
        received += chunk.length;
        onProgress?.call(received);
      }
    } on Object catch (error) {
      throw RulesIndexDownloadException(
        RulesIndexDownloadErrorKind.network,
        'Download abgebrochen: $error',
      );
    }
    return builder.takeBytes();
  }
}
