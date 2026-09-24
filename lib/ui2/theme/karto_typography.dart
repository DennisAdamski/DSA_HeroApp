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

/// Baut die Schriftrollen der neuen Oberflaeche auf [basis] auf.
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
///
/// **[basis] ist nicht optional und darf nicht durch frisch gebaute
/// `TextStyle` ersetzt werden.** Materials Stile tragen `inherit: false`, ein
/// mit dem Konstruktor erzeugter `TextStyle` dagegen `true`. `TextStyle.lerp`
/// wirft, sobald zwei Stile darin nicht uebereinstimmen — und genau das tut
/// `MaterialApp`, wenn die Oberflaeche umgeschaltet wird und beide Themes
/// ineinander ueberblendet werden. Der Fehler zeigt sich nur beim Uebergang,
/// nie beim Bau eines einzelnen Themes. Gepinnt in
/// `test/ui2/theme/karto_theme_uebergang_test.dart`.
TextTheme buildKartoTextTheme(KartoTheme t, TextTheme basis) {
  TextStyle titel(
    TextStyle? slot, {
    required double groesse,
    FontWeight gewicht = FontWeight.w600,
    double hoehe = 1.2,
    double? laufweite,
    FontStyle? neigung,
    Color? farbe,
  }) {
    return slot!.copyWith(
      fontFamily: kSchriftTitel,
      fontSize: groesse,
      fontWeight: gewicht,
      height: hoehe,
      letterSpacing: laufweite,
      fontStyle: neigung,
      color: farbe ?? t.schrift,
      // Spectral ist statisch; eine Achse gibt es hier nicht zu setzen.
      fontVariations: const <FontVariation>[],
    );
  }

  TextStyle daten(
    TextStyle? slot, {
    required double groesse,
    required double gewicht,
    double hoehe = 1.3,
    double? laufweite,
    bool tabellenziffern = false,
    Color? farbe,
  }) {
    return slot!.copyWith(
      fontFamily: kSchriftDaten,
      fontSize: groesse,
      fontWeight: FontWeight.values[(gewicht ~/ 100) - 1],
      height: hoehe,
      letterSpacing: laufweite,
      color: farbe ?? t.schrift,
      fontVariations: _gewicht(gewicht),
      fontFeatures: tabellenziffern ? _tabellenziffern : const <FontFeature>[],
    );
  }

  return basis.copyWith(
    // titelGross: Heldenname, Modustitel.
    displaySmall: titel(
      basis.displaySmall,
      groesse: 34,
      hoehe: 1.15,
      laufweite: -0.2,
    ),
    // titel: Bereichsueberschrift.
    headlineMedium: titel(basis.headlineMedium, groesse: 24),
    // wertGross: LeP, AsP, AU im Spielen-Modus.
    headlineSmall: daten(
      basis.headlineSmall,
      groesse: 28,
      gewicht: 600,
      hoehe: 1.1,
      tabellenziffern: true,
    ),
    // abschnitt: Abschnittsueberschrift.
    titleMedium: titel(basis.titleMedium, groesse: 18, hoehe: 1.25),
    // wert: Zahl in Tabelle und Zeile.
    titleSmall: daten(
      basis.titleSmall,
      groesse: 15,
      gewicht: 500,
      tabellenziffern: true,
    ),
    // fliess: Lesetext.
    bodyMedium: daten(basis.bodyMedium, groesse: 15, gewicht: 400, hoehe: 1.45),
    // legende: Helfertext, Regelzitat, Herkunft. Echte Kursive.
    bodySmall: titel(
      basis.bodySmall,
      groesse: 15,
      gewicht: FontWeight.w400,
      hoehe: 1.5,
      neigung: FontStyle.italic,
      farbe: t.schriftLeise,
    ),
    // etikett: Feldbeschriftung, Spaltenkopf.
    labelMedium: daten(
      basis.labelMedium,
      groesse: 13,
      gewicht: 500,
      laufweite: 0.2,
      farbe: t.schriftLeise,
    ),
    // marke: Chip, Statuswort.
    labelSmall: daten(
      basis.labelSmall,
      groesse: 11,
      gewicht: 600,
      hoehe: 1.2,
      laufweite: 0.6,
    ),
    // Restliche Slots abgeleitet, damit Material nichts vermisst.
    displayLarge: titel(basis.displayLarge, groesse: 48),
    displayMedium: titel(basis.displayMedium, groesse: 40),
    headlineLarge: titel(basis.headlineLarge, groesse: 28),
    titleLarge: titel(basis.titleLarge, groesse: 20),
    bodyLarge: daten(basis.bodyLarge, groesse: 17, gewicht: 400, hoehe: 1.45),
    labelLarge: daten(basis.labelLarge, groesse: 15, gewicht: 500),
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
