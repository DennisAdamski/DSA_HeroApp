/// Bestätigte Standardpositionen; ungewöhnliche Wechsel bleiben manuell.
enum Ziehposition { guertel, ruecken, schildRuecken }

/// Dauer und Markenart werden gemeinsam aus derselben Ziehregel abgeleitet.
class GefechtsZiehplan {
  /// Eine freie Ziehhandlung benötigt weiterhin genau eine freie Marke.
  const GefechtsZiehplan(this.dauer, {this.freieMarke = false});
  final int dauer;
  final bool freieMarke;
}

/// WdS 55: Gürtel/Arm/Brust 1, Rücken 2, Schild 5 Aktionen; Schnellziehen 0/1/3.
GefechtsZiehplan gefechtsZiehplan(
  Ziehposition position, {
  required bool schnellziehen,
}) => switch (position) {
  Ziehposition.guertel => GefechtsZiehplan(1, freieMarke: schnellziehen),
  Ziehposition.ruecken => GefechtsZiehplan(schnellziehen ? 1 : 2),
  Ziehposition.schildRuecken => GefechtsZiehplan(schnellziehen ? 3 : 5),
};
