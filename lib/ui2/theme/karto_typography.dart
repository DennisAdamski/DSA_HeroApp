import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

/// Titelschrift: Spectral, statisch, mit echter Kursive.
const String kSchriftTitel = 'Spectral';

/// Datenschrift: Inter Tight, variabel, mit Tabellenziffern.
const String kSchriftDaten = 'InterTight';

/// Setzt das Gewicht der variablen Datenschrift.
///
/// Noetig, weil Inter Tight bei Google Fonts nur variabel vorliegt. Die Datei
/// ist in `pubspec.yaml` genau einmal deklariert; ein zweiter Eintrag mit
/// `weight:` waere exakt der Fehler, den die bestehende Oberflaeche bei
/// Merriweather und Cinzel macht: registriert, aber ohne eigene Glyphen.
List<FontVariation> _gewicht(double wert) => <FontVariation>[
  FontVariation('wght', wert),
];

/// Ziffern gleicher Laufweite, damit Zahlen in Spalten untereinander stehen.
const List<FontFeature> _tabellenziffern = <FontFeature>[
  FontFeature.tabularFigures(),
];

/// Baut die Schriftrollen der neuen Oberflaeche.
///
/// Neun Rollen statt fuenfzehn rollenloser Material-Schubladen. Der Grund ist
/// erfahrungsgestuetzt: in der bestehenden Oberflaeche entfallen 251 von 635
/// Zugriffen auf `bodySmall` und nur drei auf die Display-Ebene. Wer "klein
/// und leise" braucht, landet bei einer rollenlosen Skala zwangslaeufig immer
/// an derselben Stelle.
///
/// Die Rollen liegen auf `TextTheme`-Slots, damit Material-Interna wie
/// `ListTile` und `AlertDialog` weiter funktionieren. Welcher Slot welche
/// Rolle traegt, steht in [KartoRollen].
TextTheme buildKartoTextTheme(KartoTheme t) {
  final titel = TextStyle(fontFamily: kSchriftTitel, color: t.schrift);
  final daten = TextStyle(fontFamily: kSchriftDaten, color: t.schrift);

  return TextTheme(
    // titelGross: Heldenname, Modustitel.
    displaySmall: titel.copyWith(
      fontSize: 34,
      fontWeight: FontWeight.w600,
      height: 1.15,
      letterSpacing: -0.2,
    ),
    // titel: Bereichsueberschrift.
    headlineMedium: titel.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    // wertGross: LeP, AsP, AU im Spielen-Modus.
    headlineSmall: daten.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      height: 1.1,
      fontVariations: _gewicht(600),
      fontFeatures: _tabellenziffern,
    ),
    // abschnitt: Abschnittsueberschrift.
    titleMedium: titel.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
    // wert: Zahl in Tabelle und Zeile.
    titleSmall: daten.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.3,
      fontVariations: _gewicht(500),
      fontFeatures: _tabellenziffern,
    ),
    // fliess: Lesetext.
    bodyMedium: daten.copyWith(
      fontSize: 15,
      height: 1.45,
      fontVariations: _gewicht(400),
    ),
    // legende: Helfertext, Regelzitat, Herkunft. Echte Kursive.
    bodySmall: titel.copyWith(
      fontSize: 15,
      height: 1.5,
      fontStyle: FontStyle.italic,
      color: t.schriftLeise,
    ),
    // etikett: Feldbeschriftung, Spaltenkopf.
    labelMedium: daten.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.3,
      letterSpacing: 0.2,
      fontVariations: _gewicht(500),
      color: t.schriftLeise,
    ),
    // marke: Chip, Statuswort.
    labelSmall: daten.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: 0.6,
      fontVariations: _gewicht(600),
    ),
    // Restliche Slots abgeleitet, damit Material nichts vermisst.
    displayLarge: titel.copyWith(fontSize: 48, fontWeight: FontWeight.w600),
    displayMedium: titel.copyWith(fontSize: 40, fontWeight: FontWeight.w600),
    headlineLarge: titel.copyWith(fontSize: 28, fontWeight: FontWeight.w600),
    titleLarge: titel.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
    bodyLarge: daten.copyWith(
      fontSize: 17,
      height: 1.45,
      fontVariations: _gewicht(400),
    ),
    labelLarge: daten.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      fontVariations: _gewicht(500),
    ),
  );
}

/// Die neun Schriftrollen unter ihren Namen.
///
/// Bereichs-Code waehlt **nie** eine Groesse; er waehlt ein Primitiv, und das
/// Primitiv waehlt hier. Diese Zugriffe sind deshalb vor allem fuer die
/// Primitive und das Token-Blatt gedacht.
extension KartoRollen on TextTheme {
  /// Heldenname, Modustitel.
  TextStyle get titelGross => displaySmall!;

  /// Bereichsueberschrift.
  TextStyle get titel => headlineMedium!;

  /// Abschnittsueberschrift.
  TextStyle get abschnitt => titleMedium!;

  /// Helfertext, Regelzitat, Herkunft.
  TextStyle get legende => bodySmall!;

  /// Lesetext.
  TextStyle get fliess => bodyMedium!;

  /// Feldbeschriftung, Spaltenkopf.
  TextStyle get etikett => labelMedium!;

  /// Zahl in Tabelle und Zeile.
  TextStyle get wert => titleSmall!;

  /// Grosse Zahl, etwa Lebensenergie im Spielen-Modus.
  TextStyle get wertGross => headlineSmall!;

  /// Marke, Chip, Statuswort.
  TextStyle get marke => labelSmall!;
}
