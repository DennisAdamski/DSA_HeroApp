import 'package:flutter/material.dart';

/// Farbtoken der neuen Oberflaeche.
///
/// Die Namen benennen die **Aufgabe**, nicht die Farbe. Das ist der
/// Unterschied zur bestehenden Oberflaeche, deren Tokens (`parchment`,
/// `brass`) die Optik im Namen tragen und deshalb bei jeder Umgestaltung
/// falsch heissen.
///
/// Bewusst **nicht** enthalten sind Radien und Verlaeufe. Kartograph zeichnet
/// Linien statt Wannen; ein einziger, helligkeitsunabhaengiger Radius genuegt
/// und steht als [kKartoRadius] daneben.
@immutable
class KartoTheme extends ThemeExtension<KartoTheme> {
  /// Erstellt einen Satz Kartograph-Token.
  const KartoTheme({
    required this.blatt,
    required this.feld,
    required this.senke,
    required this.kueste,
    required this.grat,
    required this.hoehenlinie,
    required this.schrift,
    required this.schriftLeise,
    required this.schriftStumm,
    required this.schriftAufSignal,
    required this.navigation,
    required this.navigationText,
    required this.navigationMuted,
    required this.meer,
    required this.siegel,
    required this.wachs,
    required this.moos,
    required this.lebensenergie,
    required this.astralenergie,
    required this.ausdauer,
    required this.raster,
    required this.schleier,
  });

  /// Grund der Seite.
  final Color blatt;

  /// Flaeche von Eingaben und hervorgehobenen Zeilen.
  final Color feld;

  /// Flaeche von Randspalten und Leisten.
  final Color senke;

  /// Staerkste Linie: Grenze eines Bereichs.
  final Color kueste;

  /// Mittlere Linie: Trenner zwischen Bloecken.
  final Color grat;

  /// Schwaechste Linie: Trenner zwischen Zeilen.
  final Color hoehenlinie;

  /// Haupttext.
  final Color schrift;

  /// Zweitzeile, Helfertext, Herkunftsangabe.
  final Color schriftLeise;

  /// Inaktiver Text und Platzhalter.
  final Color schriftStumm;

  /// Text auf [meer] oder [siegel].
  final Color schriftAufSignal;

  /// Dunkler Grund der globalen Bereichsnavigation.
  final Color navigation;

  /// Hervorgehobener Text und Symbole auf [navigation].
  final Color navigationText;

  /// Ruhiger Text und Symbole auf [navigation].
  final Color navigationMuted;

  /// Interaktion und Auswahl.
  final Color meer;

  /// Nachdruck und Zerstoerendes.
  final Color siegel;

  /// Warnung.
  final Color wachs;

  /// Bestaetigung.
  final Color moos;

  /// Lebensenergie.
  ///
  /// Die drei Ressourcenfarben sind die einzigen Farben, die in der
  /// Spielansicht fuer sich stehen: jede bedeutet genau eine Ressource. Alles
  /// uebrige dort bleibt einfarbig, damit sie auffallen.
  final Color lebensenergie;

  /// Astralenergie.
  final Color astralenergie;

  /// Ausdauer.
  final Color ausdauer;

  /// Hilfslinien und Gitter.
  final Color raster;

  /// Abdunklung hinter Overlays.
  final Color schleier;

  /// Liefert die aktiven Token aus dem Build-Kontext.
  ///
  /// Faellt auf die helle Palette zurueck, damit ein Primitiv auch ausserhalb
  /// eines Kartograph-Themes noch rendert statt zu werfen.
  static KartoTheme of(BuildContext context) {
    return Theme.of(context).extension<KartoTheme>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? kartoDunkel
            : kartoHell);
  }

  @override
  KartoTheme copyWith({
    Color? blatt,
    Color? feld,
    Color? senke,
    Color? kueste,
    Color? grat,
    Color? hoehenlinie,
    Color? schrift,
    Color? schriftLeise,
    Color? schriftStumm,
    Color? schriftAufSignal,
    Color? navigation,
    Color? navigationText,
    Color? navigationMuted,
    Color? meer,
    Color? siegel,
    Color? wachs,
    Color? moos,
    Color? lebensenergie,
    Color? astralenergie,
    Color? ausdauer,
    Color? raster,
    Color? schleier,
  }) {
    return KartoTheme(
      blatt: blatt ?? this.blatt,
      feld: feld ?? this.feld,
      senke: senke ?? this.senke,
      kueste: kueste ?? this.kueste,
      grat: grat ?? this.grat,
      hoehenlinie: hoehenlinie ?? this.hoehenlinie,
      schrift: schrift ?? this.schrift,
      schriftLeise: schriftLeise ?? this.schriftLeise,
      schriftStumm: schriftStumm ?? this.schriftStumm,
      schriftAufSignal: schriftAufSignal ?? this.schriftAufSignal,
      navigation: navigation ?? this.navigation,
      navigationText: navigationText ?? this.navigationText,
      navigationMuted: navigationMuted ?? this.navigationMuted,
      meer: meer ?? this.meer,
      siegel: siegel ?? this.siegel,
      wachs: wachs ?? this.wachs,
      moos: moos ?? this.moos,
      lebensenergie: lebensenergie ?? this.lebensenergie,
      astralenergie: astralenergie ?? this.astralenergie,
      ausdauer: ausdauer ?? this.ausdauer,
      raster: raster ?? this.raster,
      schleier: schleier ?? this.schleier,
    );
  }

  @override
  KartoTheme lerp(covariant ThemeExtension<KartoTheme>? other, double t) {
    if (other is! KartoTheme) return this;
    Color m(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return KartoTheme(
      blatt: m(blatt, other.blatt),
      feld: m(feld, other.feld),
      senke: m(senke, other.senke),
      kueste: m(kueste, other.kueste),
      grat: m(grat, other.grat),
      hoehenlinie: m(hoehenlinie, other.hoehenlinie),
      schrift: m(schrift, other.schrift),
      schriftLeise: m(schriftLeise, other.schriftLeise),
      schriftStumm: m(schriftStumm, other.schriftStumm),
      schriftAufSignal: m(schriftAufSignal, other.schriftAufSignal),
      navigation: m(navigation, other.navigation),
      navigationText: m(navigationText, other.navigationText),
      navigationMuted: m(navigationMuted, other.navigationMuted),
      meer: m(meer, other.meer),
      siegel: m(siegel, other.siegel),
      wachs: m(wachs, other.wachs),
      moos: m(moos, other.moos),
      lebensenergie: m(lebensenergie, other.lebensenergie),
      astralenergie: m(astralenergie, other.astralenergie),
      ausdauer: m(ausdauer, other.ausdauer),
      raster: m(raster, other.raster),
      schleier: m(schleier, other.schleier),
    );
  }
}

/// Einziger Eckenradius der neuen Oberflaeche.
///
/// Kartograph gliedert mit Linien, nicht mit abgerundeten Kaesten. Der Radius
/// nimmt Kanten nur die Haerte und wechselt nie mit der Helligkeit, gehoert
/// also nicht ins Theme.
const double kKartoRadius = 2;

/// Helle Palette: Karte.
const KartoTheme kartoHell = KartoTheme(
  blatt: Color(0xFFF2EDE1),
  feld: Color(0xFFFAF7EF),
  senke: Color(0xFFE8E1D2),
  kueste: Color(0xFF2A3138),
  grat: Color(0xFF6E6355),
  hoehenlinie: Color(0xFFC9C0AE),
  schrift: Color(0xFF101820),
  schriftLeise: Color(0xFF4A4F55),
  schriftStumm: Color(0xFF8C857A),
  schriftAufSignal: Color(0xFFF2EDE1),
  navigation: Color(0xFF162C30),
  navigationText: Color(0xFFF2EDE1),
  navigationMuted: Color(0xFFBFC6BD),
  meer: Color(0xFF1F4E5F),
  siegel: Color(0xFFA6501E),
  // Dunkler als der Entwurfswert 0xFF8A6A16: der lag mit 4,33:1 unter der
  // Lesbarkeitsschwelle fuer Text. Siehe karto_contrast_test.dart.
  wachs: Color(0xFF7E6013),
  moos: Color(0xFF2F5D43),
  // Farbtoene aus dem klickbaren Entwurf, leicht abgedunkelt: dessen Werte
  // tragen als Balkenfuellung, lagen als Text aber unter 4,5:1.
  lebensenergie: Color(0xFF93493E),
  astralenergie: Color(0xFF53638F),
  ausdauer: Color(0xFF546E5A),
  raster: Color(0xFFDCD4C3),
  schleier: Color(0x73101820),
);

/// Dunkle Palette: Tiefdruck.
///
/// Die Signalfarben sind gegenueber der hellen Palette **angehoben**, nicht
/// gespiegelt: `#1F4E5F` auf `#101820` laege unter 3:1 und waere als
/// interaktive Farbe unbrauchbar.
const KartoTheme kartoDunkel = KartoTheme(
  blatt: Color(0xFF101820),
  feld: Color(0xFF16202A),
  senke: Color(0xFF0B1116),
  kueste: Color(0xFFD8D0BE),
  grat: Color(0xFF8A8172),
  hoehenlinie: Color(0xFF2B3640),
  schrift: Color(0xFFF2EDE1),
  schriftLeise: Color(0xFFB3AC9E),
  schriftStumm: Color(0xFF6E6355),
  schriftAufSignal: Color(0xFF101820),
  navigation: Color(0xFF0B1116),
  navigationText: Color(0xFFF2EDE1),
  navigationMuted: Color(0xFFB3AC9E),
  meer: Color(0xFF4E9AAF),
  siegel: Color(0xFFD97E43),
  wachs: Color(0xFFC9A44C),
  moos: Color(0xFF6BA383),
  lebensenergie: Color(0xFFC97F72),
  astralenergie: Color(0xFF8B9FD0),
  ausdauer: Color(0xFF87AC8F),
  raster: Color(0xFF1C262F),
  schleier: Color(0x9E000000),
);

/// Kurzzugriff auf die aktiven Kartograph-Token.
extension KartoThemeX on BuildContext {
  /// Liefert die aktiven Kartograph-Token.
  KartoTheme get karto => KartoTheme.of(this);
}
