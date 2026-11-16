import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_client.dart';
import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_orte_speicher.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';

/// Hält das Ortsverzeichnis von Avesmaps lokal vor und frischt es höchstens
/// einmal täglich auf.
///
/// So ist es mit Avesmaps abgesprochen: die Liste einmal am Tag abrufen und
/// lokal speichern. Ein ETag gibt es nicht, deshalb gilt allein das Alter.
/// Das Repository fragt nur, wenn [ladeOrte] gerufen wird (also auf eine
/// Nutzeraktion hin), und nach einem Fehlschlag nicht sofort wieder.
class AvesmapsOrteRepository {
  /// Erstellt das Repository; [jetzt] ersetzt in Tests die Uhr.
  AvesmapsOrteRepository({
    required this._client,
    required this._speicher,
    DateTime Function()? jetzt,
    this.gueltigkeit = const Duration(hours: 24),
    this.pauseNachFehler = const Duration(minutes: 15),
  }) : _jetzt = jetzt ?? DateTime.now;

  final AvesmapsClient _client;
  final AvesmapsOrteSpeicher _speicher;
  final DateTime Function() _jetzt;

  /// Wie lange eine abgerufene Liste als frisch gilt.
  final Duration gueltigkeit;

  /// Wartezeit nach einem Fehlschlag, wenn der Server keine eigene nennt.
  final Duration pauseNachFehler;

  DateTime? _naechsterVersuch;

  // Zuletzt geladene Liste dieser Sitzung, falls die Ablage versagt.
  AvesmapsOrtsliste? _zuletzt;
  Future<AvesmapsOrtsliste?>? _laufend;

  /// Liefert das Ortsverzeichnis oder `null`, wenn es weder lokal vorliegt
  /// noch abrufbar ist.
  ///
  /// Eine lokale Liste, die jünger als [gueltigkeit] ist, kommt ohne
  /// Netzzugriff zurück. Sonst wird neu geladen; scheitert das, bleibt die
  /// ältere Liste gültig. Gleichzeitige Aufrufe teilen sich einen Abruf.
  Future<AvesmapsOrtsliste?> ladeOrte() {
    return _laufend ??= _lade().whenComplete(() => _laufend = null);
  }

  Future<AvesmapsOrtsliste?> _lade() async {
    final jetzt = _jetzt().toUtc();
    final lokal = await _ladeLokal() ?? _zuletzt;
    if (lokal != null && jetzt.difference(lokal.abgerufen) < gueltigkeit) {
      return lokal;
    }
    final sperre = _naechsterVersuch;
    if (sperre != null && jetzt.isBefore(sperre)) return lokal;
    try {
      final orte = await _client.ladeOrte();
      // Eine leere Antwort ersetzt keine brauchbare Liste.
      if (orte.isEmpty) {
        _naechsterVersuch = jetzt.add(pauseNachFehler);
        return lokal;
      }
      final frisch = AvesmapsOrtsliste(orte: orte, abgerufen: jetzt);
      _zuletzt = frisch;
      _naechsterVersuch = null;
      try {
        await _speicher.merke(frisch);
      } on Object {
        // Lässt sich die Liste nicht ablegen, gilt sie für diese Sitzung.
      }
      return frisch;
    } on AvesmapsFehler catch (fehler) {
      _naechsterVersuch = jetzt.add(fehler.wartezeit ?? pauseNachFehler);
      return lokal;
    }
  }

  // Ein unlesbarer Zwischenspeicher zählt wie ein leerer.
  Future<AvesmapsOrtsliste?> _ladeLokal() async {
    try {
      return await _speicher.lade();
    } on Object {
      return null;
    }
  }
}
