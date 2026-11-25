import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fehlerarten beim Abruf von Freesound.
enum FreesoundFehlerArt {
  /// Nicht angemeldet, Zugang abgelaufen oder widerrufen (401/403).
  anmeldung,

  /// Tages- oder Minutenlimit des Schlüssels erreicht (429).
  gedrosselt,

  /// Server nicht erreichbar oder Zeitüberschreitung.
  netz,

  /// Unerwarteter Status oder unlesbare Antwort.
  antwort,
}

/// Fehler beim Abruf von Freesound.
class FreesoundFehler implements Exception {
  /// Erstellt den Fehler.
  const FreesoundFehler(this.art, this.meldung);

  /// Art des Fehlers.
  final FreesoundFehlerArt art;

  /// Meldung für die Anzeige.
  final String meldung;

  @override
  String toString() => meldung;
}

/// Ein Klang aus der Freesound-Suche mit allem, was die Namensnennung braucht.
class FreesoundKlang {
  /// Erstellt den Klang.
  const FreesoundKlang({
    required this.id,
    required this.name,
    required this.urheber,
    required this.lizenz,
    required this.vorschauUrl,
    required this.seite,
    this.dauer = 0,
  });

  /// Kennung bei Freesound.
  final int id;

  /// Titel des Klangs.
  final String name;

  /// Freesound-Nutzername der Urheberin oder des Urhebers.
  final String urheber;

  /// Lizenz-URL oder -Name, wie Freesound ihn liefert.
  final String lizenz;

  /// Vorschau (MP3, etwa 128 kbit/s); braucht keinen Schlüssel.
  final String vorschauUrl;

  /// Seite des Klangs bei Freesound (Rücklink der Namensnennung).
  final String seite;

  /// Länge in Sekunden.
  final double dauer;

  /// Kurzname der Lizenz für die Anzeige („CC0“, „CC BY“, „CC BY-NC“).
  String get lizenzKurz {
    final l = lizenz.toLowerCase();
    if (l.contains('zero') || l.contains('cc0') || l.contains('/0/')) {
      return 'CC0';
    }
    if (l.contains('sampling')) return 'Sampling+';
    if (l.contains('by-nc') || l.contains('noncommercial')) return 'CC BY-NC';
    if (l.contains('/by/') || l.contains('attribution')) return 'CC BY';
    return lizenz;
  }

  @override
  bool operator ==(Object other) => other is FreesoundKlang && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Liest die Textsuche der Freesound-API v2 (`https://freesound.org/apiv2`).
///
/// Jede Nutzerin meldet sich mit ihrem eigenen Freesound-Konto an (OAuth2,
/// siehe `FreesoundOAuth`); die App liefert keinen Schlüssel aus. Vorschauen
/// liegen auf dem CDN und brauchen keine Anmeldung, die Suche schon.
class FreesoundClient {
  /// Erstellt den Client; [httpClient] ersetzt in Tests das Netz.
  FreesoundClient({
    required this.token,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 20),
  }) : _httpClient = httpClient ?? http.Client();

  /// Liefert das Bearer-Token; mit `erneuern: true` ein frisch erneuertes.
  ///
  /// Wirft einen [FreesoundFehler], wenn niemand angemeldet ist.
  final Future<String> Function({bool erneuern}) token;

  /// Höchstdauer einer Anfrage.
  final Duration timeout;

  final http.Client _httpClient;

  static const String _felder =
      'id,name,username,license,duration,previews,url';

  /// Sucht Klänge zu [anfrage], deren Länge zwischen [mindestSekunden] und
  /// [hoechstSekunden] liegt (0 heißt ohne Grenze).
  ///
  /// Wirft einen [FreesoundFehler].
  Future<List<FreesoundKlang>> suche(
    String anfrage, {
    double mindestSekunden = 0,
    double hoechstSekunden = 0,
    int anzahl = 15,
  }) async {
    final text = anfrage.trim();
    if (text.isEmpty) return const <FreesoundKlang>[];
    final von = mindestSekunden > 0 ? '$mindestSekunden' : '*';
    final bis = hoechstSekunden > 0 ? '$hoechstSekunden' : '*';
    final uri = Uri.https('freesound.org', '/apiv2/search/', <String, String>{
      'query': text,
      if (von != '*' || bis != '*') 'filter': 'duration:[$von TO $bis]',
      'sort': 'rating_desc',
      'fields': _felder,
      'page_size': '$anzahl',
    });
    var antwort = await _hole(uri, await token());
    // Abgelaufenes oder widerrufenes Token: einmal erneuern und wiederholen.
    if (antwort.statusCode == 401) {
      antwort = await _hole(uri, await token(erneuern: true));
    }
    switch (antwort.statusCode) {
      case 200:
        break;
      case 401 || 403:
        throw const FreesoundFehler(
          FreesoundFehlerArt.anmeldung,
          'Freesound hat die Anmeldung abgelehnt. Bitte neu anmelden.',
        );
      case 429:
        throw const FreesoundFehler(
          FreesoundFehlerArt.gedrosselt,
          'Das Freesound-Limit ist für heute erreicht.',
        );
      default:
        throw FreesoundFehler(
          FreesoundFehlerArt.antwort,
          'Freesound meldet Status ${antwort.statusCode}.',
        );
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(antwort.bodyBytes));
    } on FormatException {
      throw const FreesoundFehler(
        FreesoundFehlerArt.antwort,
        'Freesound hat keine lesbare Antwort geliefert.',
      );
    }
    final ergebnisse = json is Map ? json['results'] : null;
    if (ergebnisse is! List) return const <FreesoundKlang>[];
    return [for (final e in ergebnisse) ?_lies(e)];
  }

  Future<http.Response> _hole(Uri uri, String bearer) async {
    try {
      return await _httpClient
          .get(uri, headers: {'Authorization': 'Bearer $bearer'})
          .timeout(timeout);
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
  }

  /// Schließt die Verbindung.
  void close() => _httpClient.close();
}

FreesoundKlang? _lies(Object? e) {
  if (e is! Map) return null;
  final id = e['id'];
  final vorschauen = e['previews'];
  final vorschau = vorschauen is Map
      ? (vorschauen['preview-hq-mp3'] ?? vorschauen['preview-lq-mp3'])
      : null;
  if (id is! int || vorschau is! String || vorschau.isEmpty) return null;
  final dauer = e['duration'];
  return FreesoundKlang(
    id: id,
    name: '${e['name'] ?? ''}',
    urheber: '${e['username'] ?? ''}',
    lizenz: '${e['license'] ?? ''}',
    vorschauUrl: vorschau,
    seite: '${e['url'] ?? 'https://freesound.org/s/$id/'}',
    dauer: dauer is num ? dauer.toDouble() : 0,
  );
}
