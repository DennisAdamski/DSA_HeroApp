/// Linienstaerken der neuen Oberflaeche.
///
/// In dieser Bildsprache traegt die Linienstaerke die Hierarchie, so wie eine
/// Karte Kueste von Hoehenlinie unterscheidet. Jede Staerke gehoert fest zu
/// einem Farbtoken gleichen Namens in `KartoTheme`. Durchgesetzt wird die
/// Paarung dadurch, dass das Linien-Primitiv keinen freien Breitenparameter
/// anbietet, sondern nur diese Stufen kennt.
abstract final class Strich {
  /// Zeilentrenner in Tabellen. Gehoert zu `KartoTheme.hoehenlinie`.
  ///
  /// Bewusst 0.5 und nicht 0: `0` bedeutet in Flutter "so duenn wie moeglich"
  /// und rendert je nach Geraetepixelverhaeltnis unterschiedlich.
  static const double hoehenlinie = 0.5;

  /// Trenner zwischen Bloecken. Gehoert zu `KartoTheme.grat`.
  static const double grat = 1;

  /// Grenze eines Bereichs. Gehoert zu `KartoTheme.kueste`.
  static const double kueste = 1.5;

  /// Auswahl und Tastaturfokus. Gehoert zu `KartoTheme.meer`.
  static const double ufer = 2.5;
}

/// Die drei Hierarchiestufen einer Linie.
///
/// Mehr Stufen gibt es nicht. Wer eine vierte braucht, braucht in Wahrheit
/// eine andere Gliederung.
enum StrichGewicht {
  /// Zeilentrenner, die schwaechste Linie.
  hoehenlinie,

  /// Blocktrenner.
  grat,

  /// Bereichsgrenze, die staerkste Linie.
  kueste,
}
