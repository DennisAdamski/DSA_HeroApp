import 'dart:convert';

import 'package:http/http.dart' as http;

/// Welches Token für einen Function-Aufruf fehlt.
enum CloudFunctionTokenArt {
  /// Firebase-ID-Token des angemeldeten Kontos.
  konto,

  /// App-Check-Token der App.
  appCheck,
}

/// Ein benötigtes Token fehlt oder ließ sich nicht holen.
///
/// Jeder Client übersetzt es in seinen eigenen, nutzerlesbaren Fehler.
class CloudFunctionTokenFehlt implements Exception {
  /// Fehlendes Token der [art].
  const CloudFunctionTokenFehlt(this.art);

  /// Art des fehlenden Tokens.
  final CloudFunctionTokenArt art;

  @override
  String toString() => 'CloudFunctionTokenFehlt(${art.name})';
}

/// Gemeinsamer HTTP-Transport für die Cloud Functions der App.
///
/// Bündelt, was Feedback, Registrierungstickets und Wissensbasis gleich
/// machen: Tokens unmittelbar vor dem Aufruf holen, Kopfzeilen setzen
/// (`authorization`, `x-firebase-appcheck`), Routen unter dem Endpunkt bilden,
/// Zeitlimit anwenden und die Antwort tolerant als JSON lesen. Was ein Status
/// oder Fehlercode bedeutet, entscheidet weiter der jeweilige Client.
class CloudFunctionTransport {
  /// Transport zu [endpoint]; ohne [idTokenProvider] nur mit App Check.
  CloudFunctionTransport({
    required this.endpoint,
    required this.appCheckTokenProvider,
    this.idTokenProvider,
    http.Client? httpClient,
    this.timeout,
  }) : _http = httpClient ?? http.Client();

  /// Basis-URL der Function.
  final Uri endpoint;

  /// Liefert vor jedem Aufruf einen frischen App-Check-Token.
  final Future<String?> Function() appCheckTokenProvider;

  /// Liefert vor jedem Aufruf das aktuelle Firebase-ID-Token; `null` für
  /// Functions ohne Konto.
  final Future<String?> Function()? idTokenProvider;

  /// Zeitlimit je Aufruf; `null` wartet unbegrenzt. Ein Ablauf erreicht den
  /// Client als `TimeoutException`.
  final Duration? timeout;

  final http.Client _http;

  /// Route [child] unter dem Endpunkt; leer ist der Endpunkt selbst.
  Uri route(String child) {
    if (child.isEmpty) return endpoint;
    final base = endpoint.path.endsWith('/')
        ? endpoint.path
        : '${endpoint.path}/';
    return endpoint.replace(path: '$base$child');
  }

  /// POST mit JSON-[body] an [ziel].
  ///
  /// Wirft [CloudFunctionTokenFehlt], bevor etwas gesendet wird.
  Future<http.Response> postJson(Uri ziel, Object? body) async {
    final kopf = await _kopfzeilen(json: true);
    return _mitZeitlimit(
      _http.post(ziel, headers: kopf, body: jsonEncode(body)),
    );
  }

  /// GET an [ziel]; wirft [CloudFunctionTokenFehlt] vor dem Senden.
  Future<http.Response> get(Uri ziel) async {
    final kopf = await _kopfzeilen(json: false);
    return _mitZeitlimit(_http.get(ziel, headers: kopf));
  }

  /// Liest den Antworttext als JSON-Objekt; `null`, wenn er keins ist.
  static Map<String, dynamic>? leseJson(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } on Object {
      return null;
    }
  }

  Future<Map<String, String>> _kopfzeilen({required bool json}) async {
    final kopf = <String, String>{};
    final konto = idTokenProvider;
    if (konto != null) {
      final idToken = await _hole(konto);
      if (idToken == null) {
        throw const CloudFunctionTokenFehlt(CloudFunctionTokenArt.konto);
      }
      kopf['authorization'] = 'Bearer $idToken';
    }
    final appCheck = await _hole(appCheckTokenProvider);
    if (appCheck == null) {
      throw const CloudFunctionTokenFehlt(CloudFunctionTokenArt.appCheck);
    }
    kopf['x-firebase-appcheck'] = appCheck;
    if (json) kopf['content-type'] = 'application/json';
    return kopf;
  }

  // Ein fehlendes Konto liefert `null`; ein Fehler beim Holen gilt ebenso als
  // fehlendes Token und endet beim Client in einer verständlichen Meldung.
  Future<String?> _hole(Future<String?> Function() provider) async {
    try {
      final token = (await provider())?.trim() ?? '';
      return token.isEmpty ? null : token;
    } on Object {
      return null;
    }
  }

  Future<http.Response> _mitZeitlimit(Future<http.Response> anfrage) {
    final limit = timeout;
    return limit == null ? anfrage : anfrage.timeout(limit);
  }
}
