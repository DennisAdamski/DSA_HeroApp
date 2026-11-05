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

  /// Eine breite Einheit (große Fenster): die gewohnte Darstellung.
  normal,

  /// Viel Platz: zusätzliche Angaben und nebeneinander statt untereinander.
  ///
  /// Jede mittlere (zwei Einheiten, mindestens 616 dp) und jede volle Kachel
  /// ist weit; eine schmale erst in sehr großen Fenstern, in denen eine
  /// Rastereinheit selbst 600 dp erreicht.
  weit;

  /// Kachelbreite, ab der eine Kachel nicht mehr [kompakt] ist.
  static const double normalAb = 420;

  /// Kachelbreite, ab der eine Kachel [weit] ist.
  static const double weitAb = 600;

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
}

/// Spaltenzahl für [anzahl] gleich breite Elemente bei Platz für [platz]
/// Spalten, ohne eine fast leere letzte Reihe.
///
/// Gewählt wird die größte Zahl bis [platz], die [anzahl] gleichmäßig teilt
/// (4 Elemente bei Platz für 3 ergeben 2×2 statt 3+1); teilt keine, gilt
/// [platz] (3 Elemente bei Platz für 2 ergeben 2+1).
int kartoAusgewogeneSpalten(int platz, int anzahl) {
  for (var spalten = platz; spalten >= 2; spalten--) {
    if (anzahl % spalten == 0) return spalten;
  }
  return platz;
}
