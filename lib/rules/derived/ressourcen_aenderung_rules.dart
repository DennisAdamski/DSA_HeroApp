// Änderungen an Ressourcenwerten (LeP, AuP, AsP, KaP), bezogen auf den
// gespeicherten Wert (ARCH-05).
//
// Die Oberfläche beschreibt, **was** der Knopf tut („−1“, „auf Maximum“),
// nicht, welcher Wert herauskommt. Angewendet wird die Änderung erst auf den
// frisch geladenen Zustand. So zählt jeder Klick, auch wenn die Anzeige den
// vorigen noch nicht zeigt.

/// Eine Änderung an einem Ressourcenwert.
sealed class RessourcenAenderung {
  const RessourcenAenderung();

  /// Verschiebt den gespeicherten Wert um [schritt].
  ///
  /// [untergrenze] und [obergrenze] begrenzen nur in Schrittrichtung und
  /// verschieben nie entgegen: Ein −1 hebt einen Wert unter der Untergrenze
  /// nicht an, ein +1 senkt einen Wert über der Obergrenze nicht ab.
  const factory RessourcenAenderung.schritt(
    int schritt, {
    int? untergrenze,
    int? obergrenze,
  }) = RessourcenSchritt;

  /// Setzt den Wert unabhängig vom gespeicherten Stand auf [wert].
  const factory RessourcenAenderung.setzen(int wert) = RessourcenSetzen;

  /// Liefert den neuen Wert ausgehend vom gespeicherten Wert [gespeichert].
  int wendeAn(int gespeichert);
}

/// Relative Änderung, siehe [RessourcenAenderung.schritt].
final class RessourcenSchritt extends RessourcenAenderung {
  /// Erstellt einen Schritt um [schritt].
  const RessourcenSchritt(this.schritt, {this.untergrenze, this.obergrenze});

  /// Betrag der Änderung, negativ für Verbrauch.
  final int schritt;

  /// Wert, unter den ein negativer Schritt nicht führt.
  final int? untergrenze;

  /// Wert, über den ein positiver Schritt nicht führt.
  final int? obergrenze;

  @override
  int wendeAn(int gespeichert) {
    final roh = gespeichert + schritt;
    final unten = untergrenze;
    if (schritt < 0 && unten != null && roh < unten) {
      return gespeichert < unten ? gespeichert : unten;
    }
    final oben = obergrenze;
    if (schritt > 0 && oben != null && roh > oben) {
      return gespeichert > oben ? gespeichert : oben;
    }
    return roh;
  }
}

/// Absolute Änderung, siehe [RessourcenAenderung.setzen].
final class RessourcenSetzen extends RessourcenAenderung {
  /// Erstellt eine Änderung auf [wert].
  const RessourcenSetzen(this.wert);

  /// Zielwert.
  final int wert;

  @override
  int wendeAn(int gespeichert) => wert;
}
