import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_client.dart';
import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_routen_speicher.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_route.dart';

/// Hält Reisewege von Avesmaps lokal vor und fragt nur auf Wunsch nach.
///
/// [gemerkt] liest ohne Netz. [hole] fragt nur für Wege, die nicht frisch
/// gemerkt sind, und nach einer Drossel (`429`/`503`) bis zur genannten
/// Wartezeit gar nicht. Es wiederholt nichts von sich aus.
class AvesmapsRoutenRepository {
  /// Erstellt das Repository; [jetzt] ersetzt in Tests die Uhr.
  AvesmapsRoutenRepository({
    required this._client,
    required this._speicher,
    DateTime Function()? jetzt,
    this.gueltigkeit = const Duration(days: 30),
    this.gueltigkeitOhneWeg = const Duration(days: 1),
    this.pauseNachFehler = const Duration(minutes: 1),
  }) : _jetzt = jetzt ?? DateTime.now;

  final AvesmapsClient? _client;
  final AvesmapsRoutenSpeicher _speicher;
  final DateTime Function() _jetzt;

  /// Wie lange ein gefundener Weg gilt.
  final Duration gueltigkeit;

  /// Wie lange eine Antwort ohne Weg gilt.
  final Duration gueltigkeitOhneWeg;

  /// Wartezeit nach einer Drossel, wenn der Server keine eigene nennt.
  final Duration pauseNachFehler;

  DateTime? _gesperrtBis;

  /// Ob überhaupt nachgefragt werden kann (Abruf eingeschaltet).
  bool get kannHolen => _client != null;

  /// Alle frischen gemerkten Wege; abgelaufene werden dabei entfernt.
  Future<Map<String, AvesmapsRoute>> gemerkt() async {
    final Map<String, GemerkteAvesmapsRoute> alle;
    try {
      alle = await _speicher.alle();
    } on Object {
      return const <String, AvesmapsRoute>{};
    }
    final jetzt = _jetzt().toUtc();
    final frisch = <String, AvesmapsRoute>{};
    final alt = <String>[];
    for (final MapEntry(key: schluessel, value: eintrag) in alle.entries) {
      if (_istFrisch(eintrag, jetzt)) {
        frisch[schluessel] = eintrag.route;
      } else {
        alt.add(schluessel);
      }
    }
    if (alt.isNotEmpty) {
      try {
        await _speicher.entferne(alt);
      } on Object {
        // Ein alter Eintrag stört nicht; er wird nur nicht mehr gezeigt.
      }
    }
    return frisch;
  }

  /// Holt den Weg der [anfrage] bei Avesmaps und merkt ihn.
  ///
  /// Wirft einen [AvesmapsFehler], etwa nach einer Drossel; bis zu deren
  /// Ende fragt es nicht erneut, sondern wirft sofort.
  Future<AvesmapsRoute> hole(AvesmapsRoutenAnfrage anfrage) async {
    final client = _client;
    if (client == null) {
      throw const AvesmapsFehler(
        AvesmapsFehlerArt.netz,
        'Reisewege lassen sich hier nicht abrufen.',
      );
    }
    final jetzt = _jetzt().toUtc();
    final sperre = _gesperrtBis;
    if (sperre != null && jetzt.isBefore(sperre)) {
      throw AvesmapsFehler(
        AvesmapsFehlerArt.gedrosselt,
        'Avesmaps nimmt gerade keine weiteren Anfragen an.',
        wartezeit: sperre.difference(jetzt),
      );
    }
    final AvesmapsRoute route;
    try {
      route = await client.route(anfrage);
    } on AvesmapsFehler catch (fehler) {
      if (fehler.art == AvesmapsFehlerArt.gedrosselt ||
          fehler.art == AvesmapsFehlerArt.nichtVerfuegbar) {
        _gesperrtBis = jetzt.add(fehler.wartezeit ?? pauseNachFehler);
      }
      rethrow;
    }
    _gesperrtBis = null;
    try {
      await _speicher.merke(
        anfrage.schluessel,
        GemerkteAvesmapsRoute(route: route, abgerufen: jetzt),
      );
    } on Object {
      // Lässt sich der Weg nicht ablegen, gilt er für diese Sitzung.
    }
    return route;
  }

  bool _istFrisch(GemerkteAvesmapsRoute eintrag, DateTime jetzt) {
    final dauer = eintrag.route.gefunden ? gueltigkeit : gueltigkeitOhneWeg;
    return jetzt.difference(eintrag.abgerufen) < dauer;
  }
}
