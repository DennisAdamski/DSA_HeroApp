import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_ortsdetails.dart';

/// Kennung der App gegenüber Avesmaps, so mit dem Betreiber abgesprochen
/// (Issue 7 im Avesmaps-Repository).
///
/// Im Web setzt der Browser seinen eigenen User-Agent; ein eigener Kopf würde
/// dort eine CORS-Vorabanfrage auslösen. Der Aufrufer übergibt die Kennung
/// deshalb nur außerhalb des Webs.
const String kAvesmapsKennung =
    'DSA_HeroApp/1.0 (+https://github.com/DennisAdamski/DSA_HeroApp)';

/// Fehlerarten beim Abruf von Avesmaps.
enum AvesmapsFehlerArt {
  /// Server nicht erreichbar oder Zeitüberschreitung.
  netz,

  /// Zu viele Anfragen von dieser Adresse (429).
  gedrosselt,

  /// Der Dienst ist gerade nicht bedienbar (503).
  nichtVerfuegbar,

  /// Den angefragten Ort gibt es nicht (404).
  unbekannt,

  /// Unerwarteter Status oder unlesbare Antwort.
  antwort,
}

/// Fehler beim Abruf von Avesmaps.
class AvesmapsFehler implements Exception {
  /// Erstellt den Fehler.
  const AvesmapsFehler(this.art, this.meldung, {this.wartezeit});

  /// Art des Fehlers.
  final AvesmapsFehlerArt art;

  /// Meldung für Protokoll und Anzeige.
  final String meldung;

  /// Vom Server genannte Wartezeit (`Retry-After`), sofern lesbar.
  final Duration? wartezeit;

  @override
  String toString() => meldung;
}

/// Ergebnis der Ortssuche.
class AvesmapsSuchergebnis {
  /// Erstellt das Ergebnis.
  const AvesmapsSuchergebnis({
    this.treffer = const <AvesmapsOrt>[],
    this.gekuerzt = false,
  });

  /// Passende Orte, die besten zuerst.
  final List<AvesmapsOrt> treffer;

  /// Ob es mehr Treffer gab, als die Antwort enthält.
  final bool gekuerzt;
}

/// Liest das Ortsverzeichnis und die Ortssuche der Entwickler-API v1 von
/// Avesmaps (`https://avesmaps.de/api/v1`).
///
/// Die Schnittstelle braucht keinen Schlüssel. Felder kommen dort nur dazu;
/// der Client liest deshalb tolerant und übergeht Unbekanntes. Er wiederholt
/// keine Anfrage von sich aus: Wann erneut gefragt wird, entscheidet der
/// Aufrufer (siehe `AvesmapsOrteRepository`).
class AvesmapsClient {
  /// Erstellt den Client; [httpClient] ersetzt in Tests das Netz.
  AvesmapsClient({
    http.Client? httpClient,
    Uri? basis,
    this.kennung,
    this.timeout = const Duration(seconds: 20),
  }) : _httpClient = httpClient ?? http.Client(),
       _basis = basis ?? Uri.https('avesmaps.de', '/api/v1');

  final http.Client _httpClient;
  final Uri _basis;

  /// Wert für den Kopf `User-Agent`, oder `null` (Web).
  final String? kennung;

  /// Höchstdauer einer Anfrage.
  final Duration timeout;

  /// Höchstzahl der Treffer einer Suche laut Schnittstelle.
  static const int sucheLimitMax = 20;

  /// Mindestlänge einer Suchanfrage; darunter antwortet die Schnittstelle
  /// leer.
  static const int sucheMinLaenge = 2;

  /// Lädt alle sichtbaren Orte. Wirft einen [AvesmapsFehler].
  Future<List<AvesmapsOrt>> ladeOrte() async {
    final antwort = await _hole(_weg('orte'));
    final orte = antwort['orte'];
    if (orte is! List) {
      throw const AvesmapsFehler(
        AvesmapsFehlerArt.antwort,
        'Avesmaps hat keine Ortsliste geliefert.',
      );
    }
    return leseAvesmapsOrte(orte);
  }

  /// Sucht Orte, deren Name zu [anfrage] passt. Wirft einen [AvesmapsFehler].
  ///
  /// Eine Anfrage unter [sucheMinLaenge] Zeichen liefert ohne Netzzugriff ein
  /// leeres Ergebnis.
  Future<AvesmapsSuchergebnis> suche(String anfrage, {int limit = 10}) async {
    final frage = anfrage.trim();
    if (frage.length < sucheMinLaenge) return const AvesmapsSuchergebnis();
    final antwort = await _hole(
      _weg('suche', <String, String>{
        'q': frage,
        'limit': '${limit.clamp(1, sucheLimitMax)}',
      }),
    );
    return AvesmapsSuchergebnis(
      treffer: leseAvesmapsOrte(antwort['treffer']),
      gekuerzt: antwort['gekuerzt'] == true,
    );
  }

  /// Lädt die Details des Orts [id] (Wiki-Artikel, Gebiete).
  ///
  /// Liefert `null`, wenn es den Ort nicht (mehr) gibt oder die Kennung keine
  /// UUID ist; wirft sonst einen [AvesmapsFehler].
  Future<AvesmapsOrtsdetails?> ladeOrt(String id) async {
    final kennung = id.trim();
    if (!_uuid.hasMatch(kennung)) return null;
    final Map<String, dynamic> antwort;
    try {
      antwort = await _hole(_weg('orte/$kennung'));
    } on AvesmapsFehler catch (fehler) {
      if (fehler.art == AvesmapsFehlerArt.unbekannt) return null;
      rethrow;
    }
    final details = AvesmapsOrtsdetails.ausJson(antwort);
    if (details == null) {
      throw const AvesmapsFehler(
        AvesmapsFehlerArt.antwort,
        'Avesmaps hat keine lesbaren Ortsdetails geliefert.',
      );
    }
    return details;
  }

  // Form der Ortskennung laut Schnittstelle; andere Werte beantwortet sie mit
  // 400, die Anfrage entfällt deshalb.
  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  /// Gibt den HTTP-Client frei.
  void close() => _httpClient.close();

  Uri _weg(String name, [Map<String, String>? parameter]) =>
      _basis.replace(path: '${_basis.path}/$name', queryParameters: parameter);

  Future<Map<String, dynamic>> _hole(Uri adresse) async {
    final http.Response antwort;
    try {
      antwort = await _httpClient
          .get(
            adresse,
            headers: <String, String>{
              'Accept': 'application/json',
              'User-Agent': ?kennung,
            },
          )
          .timeout(timeout);
    } on Object catch (fehler) {
      throw AvesmapsFehler(
        AvesmapsFehlerArt.netz,
        'Avesmaps ist nicht erreichbar: $fehler',
      );
    }
    switch (antwort.statusCode) {
      case 200:
        break;
      case 404:
        throw const AvesmapsFehler(
          AvesmapsFehlerArt.unbekannt,
          'Diesen Ort gibt es bei Avesmaps nicht.',
        );
      case 429:
        throw AvesmapsFehler(
          AvesmapsFehlerArt.gedrosselt,
          'Avesmaps nimmt gerade keine weiteren Anfragen an.',
          wartezeit: _wartezeit(antwort),
        );
      case 503:
        throw AvesmapsFehler(
          AvesmapsFehlerArt.nichtVerfuegbar,
          'Avesmaps ist gerade nicht verfügbar.',
          wartezeit: _wartezeit(antwort),
        );
      default:
        throw AvesmapsFehler(
          AvesmapsFehlerArt.antwort,
          'Unerwartete Antwort von Avesmaps (${antwort.statusCode}).',
        );
    }
    try {
      final gelesen = jsonDecode(utf8.decode(antwort.bodyBytes));
      if (gelesen is Map<String, dynamic>) return gelesen;
    } on FormatException {
      // Fällt unten in denselben Fehler wie ein falscher Wurzeltyp.
    }
    throw const AvesmapsFehler(
      AvesmapsFehlerArt.antwort,
      'Die Antwort von Avesmaps ist nicht lesbar.',
    );
  }

  // `Retry-After` in Sekunden; die Datumsform wertet der Client nicht aus.
  Duration? _wartezeit(http.Response antwort) {
    final sekunden = int.tryParse(antwort.headers['retry-after']?.trim() ?? '');
    if (sekunden == null || sekunden < 0) return null;
    return Duration(seconds: sekunden);
  }
}
