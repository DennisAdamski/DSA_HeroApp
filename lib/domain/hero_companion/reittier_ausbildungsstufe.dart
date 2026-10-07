/// Ausbildungsstufen und Ausbildungsarten von Reit- und Zugtieren.
///
/// Grundlage ist die Zoo-Botanica Aventurica S. 34 f.: Ein Pferd durchläuft
/// die Stufen in fester Reihenfolge. Die ländliche Ausbildung endet bei
/// „erprobt“, „geschult“ erreicht nur eine fundierte Ausbildung.
library;

/// Fähigkeitsstufe eines Reittiers, in Ausbildungsreihenfolge.
enum ReittierAusbildungsstufe {
  ungearbeitet,
  unerfahren,
  erprobt,
  geschult;

  /// Anzeigename der Stufe.
  String get label => switch (this) {
    ReittierAusbildungsstufe.ungearbeitet => 'ungearbeitet',
    ReittierAusbildungsstufe.unerfahren => 'unerfahren',
    ReittierAusbildungsstufe.erprobt => 'erprobt',
    ReittierAusbildungsstufe.geschult => 'geschult',
  };
}

/// Art der Ausbildung: ländlich (Arbeit ersetzt Schulung) oder fundiert.
enum ReittierAusbildungsart {
  laendlich,
  fundiert;

  /// Anzeigename der Ausbildungsart.
  String get label => switch (this) {
    ReittierAusbildungsart.laendlich => 'ländlich',
    ReittierAusbildungsart.fundiert => 'fundiert',
  };
}
