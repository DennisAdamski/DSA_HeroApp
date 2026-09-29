import 'dart:async';

/// Führt je Schlüssel höchstens einen Lauf gleichzeitig aus und bündelt
/// Anstöße, die währenddessen eintreffen, zu genau einem Folgelauf.
///
/// Gedacht für Uploads, die immer den **neuesten** lokalen Stand übertragen:
/// Zehn schnelle Änderungen ergeben dann höchstens zwei Übertragungen statt
/// zehn, und zwei Übertragungen desselben Datensatzes laufen nie parallel.
/// Parallele Übertragungen stützten sich sonst auf dieselbe Basisrevision und
/// meldeten einen Konflikt mit sich selbst.
class GebuendelteLaeufe {
  /// Erstellt die Bündelung; [nachLauf] läuft, sobald für einen Schlüssel
  /// kein Lauf mehr aussteht (auch nach einem Fehler).
  GebuendelteLaeufe({this.nachLauf});

  /// Wird nach dem letzten Lauf eines Schlüssels aufgerufen.
  final Future<void> Function(String schluessel)? nachLauf;

  final Map<String, Future<void>> _laufend = <String, Future<void>>{};
  final Set<String> _erneut = <String>{};

  /// Ob für [schluessel] gerade ein Lauf aussteht.
  bool laeuft(String schluessel) => _laufend.containsKey(schluessel);

  /// Stößt [lauf] für [schluessel] an.
  ///
  /// Läuft bereits einer, wird genau ein Folgelauf vorgemerkt und die Zukunft
  /// des laufenden Durchgangs zurückgegeben: Sie endet erst, wenn auch der
  /// Folgelauf fertig ist. Der Folgelauf nutzt die Funktion des ersten
  /// Anstoßes. Wirft ein Lauf, endet der Durchgang mit diesem Fehler, ein
  /// vorgemerkter Folgelauf entfällt.
  Future<void> stosseAn(String schluessel, Future<void> Function() lauf) {
    final laufend = _laufend[schluessel];
    if (laufend != null) {
      _erneut.add(schluessel);
      return laufend;
    }
    final durchgang = _fuehreAus(schluessel, lauf);
    _laufend[schluessel] = durchgang;
    return durchgang;
  }

  /// Wartet, bis für keinen Schlüssel mehr ein Lauf aussteht.
  ///
  /// Fehler einzelner Läufe werden hier nicht weitergereicht; sie gehören
  /// dem, der den Lauf angestoßen hat.
  Future<void> warteAufAlle() async {
    while (_laufend.isNotEmpty) {
      final offen = _laufend.values.map(
        (lauf) => lauf.then<void>((_) {}, onError: (Object _) {}),
      );
      await Future.wait(offen);
    }
  }

  // Wiederholt den Lauf, solange während eines Durchgangs neue Anstöße kamen.
  Future<void> _fuehreAus(
    String schluessel,
    Future<void> Function() lauf,
  ) async {
    // Erst nach dem Eintrag in [_laufend] beginnen, auch wenn [lauf] sofort
    // fertig wäre.
    await Future<void>.value();
    try {
      do {
        _erneut.remove(schluessel);
        await lauf();
      } while (_erneut.contains(schluessel));
    } finally {
      _erneut.remove(schluessel);
      _laufend.remove(schluessel);
      final danach = nachLauf;
      if (danach != null) {
        await danach(schluessel);
      }
    }
  }
}
