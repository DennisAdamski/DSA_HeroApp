/// Breitenschwellen beider Oberflächen aus einer Quelle.
///
/// Bestand (`lib/ui/config/app_layout.dart`) und Kartograph
/// (`lib/ui2/foundation/karto_breakpoints.dart`) laufen nebeneinander und sollen
/// an denselben Stellen umbrechen; ein Wechsel der Oberfläche darf das Layout
/// nicht zusätzlich verschieben.
library;

/// Untergrenze für Tablet-Layouts (hochkant).
const double kSchwelleTablet = 744;

/// Untergrenze für breite Layouts (Tablet quer, kleine Desktopfenster).
const double kSchwelleBreit = 1024;

/// Untergrenze für sehr breite Layouts (Platz für drei Spalten).
const double kSchwelleSehrBreit = 1366;

/// Name der Layoutklasse zu einer Breite für Diagnosen: `compact`,
/// `tabletPortrait`, `tabletLandscape` oder `desktopWide`.
String layoutKlassenName(double breite) {
  if (breite >= kSchwelleSehrBreit) return 'desktopWide';
  if (breite >= kSchwelleBreit) return 'tabletLandscape';
  if (breite >= kSchwelleTablet) return 'tabletPortrait';
  return 'compact';
}
