import 'package:flutter/widgets.dart';

/// Abstandsskala der neuen Oberflaeche.
///
/// Die Werte sind keine Erfindung, sondern die Kodifizierung dessen, was im
/// Bestand ohnehin gilt: 12, 8 und 16 stellen dort zusammen die Mehrheit aller
/// Abstaende. Neu ist nur, dass sie Namen tragen und dass Bereichs-Code sie
/// benutzen muss statt Zahlenliteralen.
///
/// Die Skala gehoert bewusst **nicht** ins Theme. Abstaende wechseln nie mit
/// der Helligkeit; als `ThemeExtension` gefuehrt endeten sie bei Aufrufen wie
/// `context.theme.spacing12`.
abstract final class Abstand {
  /// Innerhalb einer Zeile, etwa zwischen Wert und Einheit.
  static const double haar = 2;

  /// Innenabstand einer Tabellenzelle.
  static const double eng = 4;

  /// Innenraum von Marken und Chips.
  static const double knapp = 6;

  /// Etikett zu Wert.
  static const double normal = 8;

  /// Feld zu Feld.
  static const double weit = 12;

  /// Innenraum eines Abschnitts.
  static const double block = 16;

  /// Abschnitt zu Abschnitt.
  static const double bahn = 24;

  /// Seitenrand auf breiten Flaechen.
  static const double rand = 32;

  /// Innenabstand eines Abschnitts.
  static const EdgeInsets blockInnen = EdgeInsets.all(block);

  /// Innenabstand einer Tabellenzeile.
  static const EdgeInsets zeile = EdgeInsets.symmetric(
    horizontal: normal,
    vertical: eng,
  );

  /// Senkrechter Zwischenraum in Hoehe eines Schrittes.
  static const SizedBox luecke = SizedBox(height: weit);

  /// Waagerechter Zwischenraum in Hoehe eines Schrittes.
  static const SizedBox spalt = SizedBox(width: normal);
}

/// Breitenklassen fuer Dialoge und begrenzte Textbloecke.
///
/// Uebernommen aus `lib/ui/config/ui_spacing.dart`: die Werte haben sich
/// bewaehrt, es fehlten nur die Rollennamen.
abstract final class Breite {
  /// Einfache Formulare, Picker, Bestaetigungen.
  static const double klein = 420;

  /// Detailansichten und mittlere Formulare.
  static const double mittel = 560;

  /// Komplexe Editoren mit mehreren Feldern.
  static const double gross = 760;

  /// Voll-Detailansichten, etwa Zauberdetails.
  static const double sehrGross = 920;

  /// Obergrenze fuer gut lesbaren Fliesstext.
  ///
  /// Entspricht ungefaehr 70 Zeichen in der Fliesstextrolle.
  static const double lesespalte = 620;
}
