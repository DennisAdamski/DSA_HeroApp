import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_tiefe.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Baut das Theme der neuen Oberflaeche.
///
/// Der Leitgedanke steckt in den Komponenten-Themes: **Liegendes ist flach,
/// Schwebendes wirft Schatten.** Tiefe liegender Flaechen entsteht aus der
/// **Flaeche**, Gliederung aus der **Linie**, und beide sind dreistufig
/// (`senke`/`blatt`/`feld`, `hoehenlinie`/`grat`/`kueste`). Karten, Chips und
/// Knoepfe tragen deshalb `elevation: 0`. Dialoge, Blaetter, Menues und
/// Snackbar schweben ueber dem Papier und bekommen die Stufe
/// [KartoTiefe.schwebend]; ihr Schatten nimmt die warme Farbe aus
/// `KartoTheme.schatten`. `surfaceTintColor` bleibt durchgehend transparent.
///
/// Die Flaechen sind so verteilt: Seitengrund `blatt`, erhobene Flaechen wie
/// Karten und Dialoge `feld`, eingelassene wie Eingabefelder und schwebende wie
/// Tooltip und Snackbar `senke`. Ein Eingabefeld auf `feld` waere innerhalb
/// eines Abschnitts unsichtbar, weil der Abschnitt dieselbe Farbe traegt.
ThemeData buildKartoTheme({
  required Brightness brightness,
  required bool centerAppBarTitle,
}) {
  final t = brightness == Brightness.dark ? kartoDunkel : kartoHell;
  final radius = BorderRadius.circular(kKartoRadius);
  final radiusKlein = BorderRadius.circular(kKartoRadiusKlein);
  const durchsichtig = Color(0x00000000);

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: t.meer,
    onPrimary: t.schriftAufSignal,
    secondary: t.siegel,
    onSecondary: t.schriftAufSignal,
    tertiary: t.moos,
    onTertiary: t.schriftAufSignal,
    error: t.siegel,
    onError: t.schriftAufSignal,
    surface: t.blatt,
    onSurface: t.schrift,
    onSurfaceVariant: t.schriftLeise,
    surfaceContainerHighest: t.feld,
    surfaceContainerHigh: t.feld,
    surfaceContainer: t.senke,
    outline: t.grat,
    outlineVariant: t.hoehenlinie,
    shadow: t.schatten,
    scrim: t.schleier,
    inverseSurface: t.schrift,
    onInverseSurface: t.blatt,
  );

  // Erst die Material-Grundlage bauen, dann die Schriftrollen darauf.
  // Nicht abkuerzen: Materials Stile tragen `inherit: false`, ein frisch
  // gebauter `TextStyle` dagegen `true`. `TextStyle.lerp` wirft, sobald beides
  // aufeinandertrifft — und genau das passiert, wenn `MaterialApp` beim
  // Umschalten der Oberflaeche zwischen den Themes ueberblendet.
  final basis = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: t.blatt,
    canvasColor: t.blatt,
    extensions: <ThemeExtension<dynamic>>[t],
    // Nur Komponenten mit Elevation werfen Schatten; liegende stehen unten
    // ausdruecklich auf 0.
    shadowColor: t.schatten,
  );
  final textTheme = buildKartoTextTheme(t, basis.textTheme);

  // Bewusst ohne eigene Textstile an Knoepfen, Kacheln und Dialogen: das
  // bestehende Theme setzt dort keine, und beim Ueberblenden zwischen beiden
  // Oberflaechen traefe ein gesetzter Stil auf null. TextStyle.lerp wirft
  // dann. Material loest diese Stile ohnehin aus der Schriftskala auf.
  return basis.copyWith(
    textTheme: textTheme,

    appBarTheme: AppBarTheme(
      centerTitle: centerAppBarTitle,
      backgroundColor: t.blatt,
      foregroundColor: t.schrift,
      surfaceTintColor: durchsichtig,
      scrolledUnderElevation: 0,
      elevation: 0,
      titleTextStyle: textTheme.titel,
      iconTheme: IconThemeData(color: t.schrift),
      actionsIconTheme: IconThemeData(color: t.schrift),
      // Die Kopfzeile grenzt sich mit der staerksten Linie ab.
      shape: Border(
        bottom: BorderSide(color: t.kueste, width: Strich.kueste),
      ),
    ),

    // Eine Karte ist eine erhobene Flaeche. Mit Fuellung genuegt die
    // schwaechste Kante; der frueher noetige `grat` war nur deshalb noetig,
    // weil die Karte denselben Grund wie die Seite trug.
    cardTheme: CardThemeData(
      color: t.feld,
      surfaceTintColor: durchsichtig,
      shadowColor: durchsichtig,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: t.hoehenlinie, width: Strich.hoehenlinie),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: t.hoehenlinie,
      thickness: Strich.hoehenlinie,
      space: Strich.hoehenlinie,
    ),

    // Unterlinie statt Kasten: ein Feld ist eine beschriebene Zeile, kein
    // eigener Behaelter. Die Fuellung ist `senke`, nicht `feld` — ein Feld ist
    // in seine Flaeche eingelassen, und auf `feld` waere es innerhalb eines
    // Abschnitts farbgleich und damit unsichtbar.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.senke,
      isDense: true,
      labelStyle: textTheme.etikett,
      helperStyle: textTheme.legende,
      hintStyle: textTheme.fliess.copyWith(color: t.schriftStumm),
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: t.grat, width: Strich.grat),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: t.grat, width: Strich.grat),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: t.meer, width: Strich.ufer),
      ),
      errorBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: t.siegel, width: Strich.grat),
      ),
      focusedErrorBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: t.siegel, width: Strich.ufer),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: t.feld,
      selectedColor: t.meer.withValues(alpha: 0.14),
      side: BorderSide(color: t.grat, width: Strich.grat),
      shape: RoundedRectangleBorder(borderRadius: radiusKlein),
      labelStyle: textTheme.marke,
      secondaryLabelStyle: textTheme.marke,
      showCheckmark: false,
      elevation: 0,
      pressElevation: 0,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.meer,
        foregroundColor: t.schriftAufSignal,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radiusKlein),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),

    // Material 3 hebt ElevatedButton um 1 an. Ein Knopf liegt aber auf dem
    // Papier; angehoben wird bei Kartograph nur, was schwebt.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radiusKlein),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.schrift,
        side: BorderSide(color: t.grat, width: Strich.grat),
        shape: RoundedRectangleBorder(borderRadius: radiusKlein),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.meer,
        shape: RoundedRectangleBorder(borderRadius: radiusKlein),
      ),
    ),

    listTileTheme: ListTileThemeData(
      iconColor: t.schriftLeise,
      textColor: t.schrift,
      shape: RoundedRectangleBorder(borderRadius: radiusKlein),
    ),

    tabBarTheme: TabBarThemeData(
      dividerColor: t.hoehenlinie,
      labelColor: t.schrift,
      unselectedLabelColor: t.schriftLeise,
      labelStyle: textTheme.etikett.copyWith(color: t.schrift),
      unselectedLabelStyle: textTheme.etikett,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: t.meer, width: Strich.ufer),
      ),
    ),

    // Schwebendes bekommt `senke`: auf `feld` waere ein Tooltip ueber einem
    // Abschnitt farbgleich mit ihm.
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: t.senke,
        borderRadius: radiusKlein,
        border: Border.all(color: t.grat, width: Strich.grat),
        boxShadow: KartoTiefe.schwebend.schatten(t),
      ),
      textStyle: textTheme.fliess,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.senke,
      contentTextStyle: textTheme.fliess,
      elevation: KartoTiefe.schwebend.elevation,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: t.grat, width: Strich.grat),
      ),
    ),

    // Ein Dialog ist die am staerksten erhobene Flaeche und grenzt sich mit der
    // staerksten Linie ab.
    dialogTheme: DialogThemeData(
      backgroundColor: t.feld,
      surfaceTintColor: durchsichtig,
      elevation: KartoTiefe.schwebend.elevation,
      shadowColor: t.schatten,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: t.kueste, width: Strich.kueste),
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.feld,
      surfaceTintColor: durchsichtig,
      elevation: KartoTiefe.schwebend.elevation,
      modalElevation: KartoTiefe.schwebend.elevation,
      shadowColor: t.schatten,
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: t.feld,
      surfaceTintColor: durchsichtig,
      elevation: KartoTiefe.schwebend.elevation,
      shadowColor: t.schatten,
      shape: RoundedRectangleBorder(
        borderRadius: radiusKlein,
        side: BorderSide(color: t.hoehenlinie, width: Strich.hoehenlinie),
      ),
    ),

    // Die Rinne ist `raster` (Gitter), nicht `hoehenlinie` (Linie): sie ist
    // eine Flaeche und muss auch auf `feld` noch als leerer Rest lesbar sein.
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: t.meer,
      linearTrackColor: t.raster,
      circularTrackColor: t.raster,
    ),

    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll<Color>(t.grat),
      thickness: const WidgetStatePropertyAll<double>(6),
      radius: const Radius.circular(kKartoRadiusKlein),
    ),
  );
}
