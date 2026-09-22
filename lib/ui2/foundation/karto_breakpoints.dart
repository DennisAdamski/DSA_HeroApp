import 'package:flutter/widgets.dart';

/// Breitenklassen der neuen Oberflaeche.
///
/// Die Schwellen sind absichtlich dieselben wie in
/// `lib/ui/config/app_layout.dart`. Waehrend beide Oberflaechen nebeneinander
/// laufen, sollen sie an denselben Stellen umbrechen; ein Wechsel der
/// Oberflaeche darf das Layout nicht zusaetzlich verschieben.
enum KartoBreite {
  /// Handy und schmale Fenster.
  schmal,

  /// Tablet hochkant.
  tablet,

  /// Tablet quer und kleinere Desktopfenster.
  breit,

  /// Grosse Desktopfenster, Platz fuer drei Spalten.
  sehrBreit,
}

/// Untergrenze fuer Tablet-Layouts.
const double kSchwelleTablet = 744;

/// Untergrenze fuer breite Layouts.
const double kSchwelleBreit = 1024;

/// Untergrenze fuer sehr breite Layouts.
const double kSchwelleSehrBreit = 1366;

/// Ermittelt die Breitenklasse aus einer verfuegbaren Breite.
KartoBreite kartoBreiteFuer(double breite) {
  if (breite >= kSchwelleSehrBreit) return KartoBreite.sehrBreit;
  if (breite >= kSchwelleBreit) return KartoBreite.breit;
  if (breite >= kSchwelleTablet) return KartoBreite.tablet;
  return KartoBreite.schmal;
}

/// Liefert die Breitenklasse des umgebenden Fensters.
///
/// Innerhalb eines Panels ist stattdessen ein `LayoutBuilder` richtig: dort
/// zaehlt die Breite des Panels, nicht die des Fensters.
KartoBreite kartoBreiteVon(BuildContext context) =>
    kartoBreiteFuer(MediaQuery.sizeOf(context).width);

/// Komfortzugriffe auf die Breitenklasse.
extension KartoBreiteX on KartoBreite {
  /// Ob neben dem Inhalt dauerhaft eine Detailspalte Platz hat.
  bool get hatDetailspalte =>
      this == KartoBreite.breit || this == KartoBreite.sehrBreit;

  /// Ob drei Spalten nebeneinander passen.
  bool get hatDreiSpalten => this == KartoBreite.sehrBreit;

  /// Seitenrand des Inhalts.
  ///
  /// Bewusst grosszuegiger als der Innenraum eines Abschnitts. Eine Arbeits-
  /// flaeche wirkt ruhig, wenn sie aussen Luft hat und innen dicht steht; bei
  /// gleich grossen Abstaenden verschwimmen Seite und Abschnitt ineinander.
  double get seitenrand => switch (this) {
    KartoBreite.schmal => 20,
    KartoBreite.tablet => 28,
    KartoBreite.breit => 36,
    KartoBreite.sehrBreit => 44,
  };
}
