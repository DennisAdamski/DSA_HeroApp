import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:pointycastle/digests/sha256.dart';

import 'package:dsa_heldenverwaltung/data/freesound/freesound_client.dart';

/// Kennung der App bei Freesound (öffentlich, kein Geheimnis).
///
/// Freesound registriert Apps als öffentliche OAuth-Clients: Mit PKCE braucht
/// weder der Codetausch noch die Erneuerung ein Client-Secret. Das Secret
/// gehört laut Freesound nie in eine verteilte App.
const String kFreesoundClientId = String.fromEnvironment(
  'FREESOUND_CLIENT_ID',
  defaultValue: 'e2CD6o6RHAlwDs4qwlhI',
);

/// Rücksprungadresse, wie sie bei der App-Registrierung hinterlegt ist.
///
/// Voreinstellung ist die Freesound-eigene Seite, die den Code zum Kopieren
/// anzeigt; so braucht keine Plattform einen eigenen Rücksprung.
const String kFreesoundRedirectUri = String.fromEnvironment(
  'FREESOUND_REDIRECT_URI',
  defaultValue:
      'https://freesound.org/home/app_permissions/permission_granted/',
);

/// Zugang einer Nutzerin zu Freesound (OAuth2).
class FreesoundZugang {
  /// Erstellt den Zugang.
  const FreesoundZugang({
    required this.accessToken,
    required this.refreshToken,
    required this.ablauf,
  });

  /// Liest einen gespeicherten Zugang; `null` bei unlesbaren Daten.
  static FreesoundZugang? ausJson(Object? json) {
    if (json is! Map) return null;
    final access = json['access'];
    final refresh = json['refresh'];
    final ablauf = DateTime.tryParse('${json['ablauf']}');
    if (access is! String || refresh is! String || ablauf == null) return null;
    return FreesoundZugang(
      accessToken: access,
      refreshToken: refresh,
      ablauf: ablauf,
    );
  }

  /// Bearer-Token für die API.
  final String accessToken;

  /// Token zum Erneuern ohne erneute Anmeldung.
  final String refreshToken;

  /// Ablauf des [accessToken] (UTC).
  final DateTime ablauf;

  /// Ob das Token bald abläuft und erneuert werden sollte.
  bool laeuftAb(DateTime jetzt) =>
      !jetzt.isBefore(ablauf.subtract(const Duration(minutes: 5)));

  /// Speicherform.
  Map<String, String> toJson() => {
    'access': accessToken,
    'refresh': refreshToken,
    'ablauf': ablauf.toUtc().toIso8601String(),
  };
}

/// Eine begonnene Anmeldung: Adresse für den Browser und PKCE-Geheimnis.
class FreesoundAnmeldung {
  /// Erstellt die Anmeldung.
  const FreesoundAnmeldung({
    required this.adresse,
    required this.verifier,
    required this.state,
  });

  /// Seite bei Freesound, auf der die Nutzerin zustimmt.
  final Uri adresse;

  /// PKCE-Code-Verifier; verlässt das Gerät erst beim Codetausch.
  final String verifier;

  /// Zufallswert gegen untergeschobene Rückmeldungen.
  final String state;
}

/// OAuth2 mit PKCE gegen Freesound (Autorisierungscode, öffentlicher Client).
class FreesoundOAuth {
  /// Erstellt den Ablauf; [httpClient], [zufall] und [uhr] für Tests.
  FreesoundOAuth({
    required this.clientId,
    this.redirectUri = kFreesoundRedirectUri,
    http.Client? httpClient,
    Random? zufall,
    DateTime Function()? uhr,
  }) : _http = httpClient ?? http.Client(),
       _zufall = zufall ?? Random.secure(),
       _uhr = uhr ?? DateTime.now;

  /// Kennung der App bei Freesound.
  final String clientId;

  /// Registrierte Rücksprungadresse.
  final String redirectUri;

  final http.Client _http;
  final Random _zufall;
  final DateTime Function() _uhr;

  static final Uri _token = Uri.https(
    'freesound.org',
    '/apiv2/oauth2/access_token/',
  );

  /// Beginnt eine Anmeldung.
  FreesoundAnmeldung starte() {
    final verifier = _zufallsText();
    final state = _zufallsText();
    final challenge = _base64Url(
      SHA256Digest().process(utf8.encoder.convert(verifier)),
    );
    final adresse = Uri.https('freesound.org', '/apiv2/oauth2/authorize/', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
    });
    return FreesoundAnmeldung(
      adresse: adresse,
      verifier: verifier,
      state: state,
    );
  }

  /// Tauscht die [eingabe] (Code oder ganze Rücksprungadresse) gegen einen
  /// Zugang. Wirft einen [FreesoundFehler].
  Future<FreesoundZugang> tausche(
    String eingabe,
    FreesoundAnmeldung anmeldung,
  ) {
    final code = leseCode(eingabe, erwarteterState: anmeldung.state);
    return _hole({
      'client_id': clientId,
      'grant_type': 'authorization_code',
      'code': code,
      'code_verifier': anmeldung.verifier,
      'redirect_uri': redirectUri,
    });
  }

  /// Erneuert den Zugang. Wirft einen [FreesoundFehler].
  Future<FreesoundZugang> erneuere(String refreshToken) => _hole({
    'client_id': clientId,
    'grant_type': 'refresh_token',
    'refresh_token': refreshToken,
  });

  /// Schließt die Verbindung.
  void close() => _http.close();

  Future<FreesoundZugang> _hole(Map<String, String> felder) async {
    final http.Response antwort;
    try {
      antwort = await _http
          .post(_token, body: felder)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const FreesoundFehler(
        FreesoundFehlerArt.netz,
        'Freesound antwortet nicht.',
      );
    } on http.ClientException {
      throw const FreesoundFehler(
        FreesoundFehlerArt.netz,
        'Freesound ist nicht erreichbar.',
      );
    }
    if (antwort.statusCode == 400 || antwort.statusCode == 401) {
      throw const FreesoundFehler(
        FreesoundFehlerArt.anmeldung,
        'Freesound hat die Anmeldung abgelehnt. Bitte neu anmelden.',
      );
    }
    final json = antwort.statusCode == 200 ? _json(antwort) : null;
    final access = json?['access_token'];
    final refresh = json?['refresh_token'];
    final dauer = json?['expires_in'];
    if (access is! String || refresh is! String) {
      throw FreesoundFehler(
        FreesoundFehlerArt.antwort,
        'Freesound meldet Status ${antwort.statusCode}.',
      );
    }
    return FreesoundZugang(
      accessToken: access,
      refreshToken: refresh,
      ablauf: _uhr().toUtc().add(
        Duration(seconds: dauer is num ? dauer.toInt() : 86400),
      ),
    );
  }

  String _zufallsText() =>
      _base64Url(List<int>.generate(32, (_) => _zufall.nextInt(256)));
}

/// Liest den Code aus einer eingefügten Adresse oder nimmt den Text selbst.
///
/// Trägt die Adresse einen anderen `state` als [erwarteterState] oder einen
/// `error`, wirft sie einen [FreesoundFehler].
String leseCode(String eingabe, {required String erwarteterState}) {
  final text = eingabe.trim();
  final uri = Uri.tryParse(text);
  final parameter = uri != null && uri.hasQuery
      ? uri.queryParameters
      : const <String, String>{};
  if (parameter.containsKey('error')) {
    throw const FreesoundFehler(
      FreesoundFehlerArt.anmeldung,
      'Die Anmeldung bei Freesound wurde abgebrochen.',
    );
  }
  final state = parameter['state'];
  if (state != null && state != erwarteterState) {
    throw const FreesoundFehler(
      FreesoundFehlerArt.anmeldung,
      'Der Code gehört zu einer anderen Anmeldung. Bitte neu starten.',
    );
  }
  final code = parameter['code'] ?? text;
  if (code.isEmpty || code.contains(RegExp(r'\s'))) {
    throw const FreesoundFehler(
      FreesoundFehlerArt.anmeldung,
      'Bitte den Code von Freesound einfügen.',
    );
  }
  return code;
}

Map<String, Object?>? _json(http.Response antwort) {
  try {
    final wert = jsonDecode(utf8.decode(antwort.bodyBytes));
    return wert is Map<String, Object?> ? wert : null;
  } on FormatException {
    return null;
  }
}

String _base64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
