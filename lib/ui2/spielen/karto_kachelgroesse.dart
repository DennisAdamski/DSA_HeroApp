/// Größenstufe einer Kachel der Spielansicht (SPIEL-07).
///
/// Sie richtet sich nach der **tatsächlichen Breite der Kachel**, nicht nach
/// der des Fensters: Dieselbe Kachel ist als „schmal“ im Raster kompakt und
/// als „Ganze Breite“ weit. Kachelinhalte zeigen mit der Stufe mehr
/// Information oder ordnen sich um, statt nur zu strecken. Rein darstellend:
/// die Stufe ändert nie, welche Werte gelten.
enum KartoKachelGroesse {
  /// Eine schmale Rastereinheit: nur das Wichtigste.
  kompakt,

  /// Eine breitere Einheit oder zwei Einheiten: die gewohnte Darstellung.
  normal,

  /// Viel Platz: zusätzliche Angaben und nebeneinander statt untereinander.
  weit;

  /// Kachelbreite, ab der eine Kachel nicht mehr [kompakt] ist.
  static const double normalAb = 420;

  /// Kachelbreite, ab der eine Kachel [weit] ist.
  static const double weitAb = 700;

  /// Stufe für die verfügbare Kachelbreite [breite].
  ///
  /// Eine unbeschränkte oder unendliche Breite gilt als [normal], damit
  /// Kacheln außerhalb des Rasters ihre gewohnte Darstellung behalten.
  static KartoKachelGroesse fuerBreite(double breite) {
    if (!breite.isFinite) return normal;
    if (breite >= weitAb) return weit;
    if (breite >= normalAb) return normal;
    return kompakt;
  }

  /// Ob die Kachel mindestens [normal] groß ist.
  bool get mindestensNormal => this != kompakt;

  /// Ob die Kachel [weit] ist.
  bool get istWeit => this == weit;
}
