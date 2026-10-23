import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_remote_client.dart';

/// Veroeffentlichte Fassung der Regel-Wissensbasis samt Download-URL.
class RulesIndexRelease {
  /// Erstellt eine Beschreibung der Veroeffentlichung.
  const RulesIndexRelease({
    required this.url,
    required this.version,
    required this.sha256,
    required this.sizeBytes,
  });

  /// Kurzlebige, signierte URL auf die gepackte Datei.
  final Uri url;

  /// Veroeffentlichungszeitpunkt (ISO 8601); dient als Versionskennung.
  final String version;

  /// SHA-256 der entpackten SQLite-Datei (hex).
  final String sha256;

  /// Groesse der entpackten Datei in Byte.
  final int sizeBytes;
}

/// Austauschbarer Zugang zur Veroeffentlichung, fuer Tests ersetzbar.
abstract interface class RulesIndexAccessGateway {
  /// Fragt die URL der aktuellen Fassung ab.
  ///
  /// [proof] ist der Passwortnachweis (`rulesIndexProof`). Wirft eine
  /// [RulesIndexDownloadException] mit sprechender Meldung.
  Future<RulesIndexRelease> requestAccess({required String proof});
}

/// HTTP-Client fuer die Cloud Function `rulesIndexApi`.
///
/// Sendet Firebase-ID-Token, App-Check-Token und den Passwortnachweis; die
/// Antwort enthaelt eine wenige Minuten gueltige URL. Der Download selbst
/// laeuft ueber [RulesIndexRemoteClient.downloadSigned], ohne Kopfzeilen.
class RulesIndexAccessClient implements RulesIndexAccessGateway {
  /// Erstellt den Client mit injizierbaren Netzwerk- und Tokenabhaengigkeiten.
  RulesIndexAccessClient({
    required this.endpoint,
    required this.idTokenProvider,
    required this.appCheckTokenProvider,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 20),
  }) : _http = httpClient ?? http.Client();

  /// URL der Cloud Function (Build-Konfiguration `RULES_INDEX_API_URL`).
  final Uri endpoint;

  /// Liefert unmittelbar vor dem Aufruf das aktuelle Firebase-ID-Token.
  final Future<String?> Function() idTokenProvider;

  /// Liefert unmittelbar vor dem Aufruf einen frischen App-Check-Token.
  final Future<String?> Function() appCheckTokenProvider;

  /// Maximale Wartezeit auf die Antwort der Function.
  final Duration timeout;

  final http.Client _http;

  @override
  Future<RulesIndexRelease> requestAccess({required String proof}) async {
    final idToken = (await _tokenOrNull(idTokenProvider))?.trim() ?? '';
    if (idToken.isEmpty) {
      throw const RulesIndexDownloadException(
        RulesIndexDownloadErrorKind.unauthorized,
        'Zum Laden der Wissensbasis bitte anmelden.',
      );
    }
    final appCheck = (await _tokenOrNull(appCheckTokenProvider))?.trim() ?? '';
    if (appCheck.isEmpty) {
      throw const RulesIndexDownloadException(
        RulesIndexDownloadErrorKind.unauthorized,
        'Die App konnte sich nicht beim Server ausweisen (App Check).',
      );
    }

    final http.Response response;
    try {
      response = await _http
          .post(
            endpoint,
            headers: <String, String>{
              'authorization': 'Bearer $idToken',
              'x-firebase-appcheck': appCheck,
              'content-type': 'application/json',
            },
            body: jsonEncode(<String, String>{'proof': proof}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const RulesIndexDownloadException(
        RulesIndexDownloadErrorKind.network,
        'Der Server antwortet nicht rechtzeitig.',
      );
    } on Object catch (error) {
      throw RulesIndexDownloadException(
        RulesIndexDownloadErrorKind.network,
        'Server nicht erreichbar: $error',
      );
    }
    return _decode(response);
  }

  // Ein fehlendes Konto liefert `null`, ein Fehler beim Holen gilt als
  // fehlendes Token; beides endet in einer verstaendlichen Meldung.
  Future<String?> _tokenOrNull(Future<String?> Function() provider) async {
    try {
      return await provider();
    } on Object {
      return null;
    }
  }

  RulesIndexRelease _decode(http.Response response) {
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) json = decoded.cast<String, dynamic>();
    } on Object {
      json = null;
    }
    final code = json?['code'] as String?;
    switch (response.statusCode) {
      case 200:
        final url = Uri.tryParse(json?['url'] as String? ?? '');
        final version = json?['version'] as String?;
        final sha = json?['sha256'] as String?;
        final size = (json?['sizeBytes'] as num?)?.toInt();
        if (url == null ||
            !url.hasScheme ||
            version == null ||
            sha == null ||
            size == null ||
            size <= 0) {
          throw const RulesIndexDownloadException(
            RulesIndexDownloadErrorKind.other,
            'Unerwartete Antwort des Servers.',
          );
        }
        return RulesIndexRelease(
          url: url,
          version: version,
          sha256: sha,
          sizeBytes: size,
        );
      case 401:
        throw RulesIndexDownloadException(
          RulesIndexDownloadErrorKind.unauthorized,
          code != null && code.startsWith('APP_CHECK')
              ? 'Die App konnte sich nicht beim Server ausweisen (App Check).'
              : 'Die Anmeldung wurde vom Server abgelehnt. Bitte neu anmelden.',
        );
      case 403:
        throw RulesIndexDownloadException(
          RulesIndexDownloadErrorKind.unauthorized,
          code == 'PROOF_INVALID'
              ? 'Das Katalogpasswort passt nicht zum Server. Der Betreiber '
                    'muss es dort neu hinterlegen.'
              : 'Zugriff vom Server abgelehnt.',
        );
      case 404:
        throw const RulesIndexDownloadException(
          RulesIndexDownloadErrorKind.notFound,
          'Es ist noch keine Wissensbasis veröffentlicht.',
        );
      case 503:
        throw const RulesIndexDownloadException(
          RulesIndexDownloadErrorKind.other,
          'Der Dienst für die Wissensbasis ist gerade nicht verfügbar.',
        );
      default:
        throw RulesIndexDownloadException(
          RulesIndexDownloadErrorKind.other,
          'Unerwartete Serverantwort (${response.statusCode}).',
        );
    }
  }
}
