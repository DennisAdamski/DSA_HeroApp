import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Baut das Theme der neuen Oberflaeche.
///
/// Der Leitgedanke steckt in den Komponenten-Themes: keine Schatten, keine
/// Fuellkaesten, keine Verlaeufe. Flaechen werden durch Linien gegliedert, und
/// die Linienstaerke traegt die Hierarchie. Deshalb ist `elevation` durchgehend
/// 0, `surfaceTintColor` durchgehend transparent, und Eingaben bekommen eine
/// Unterlinie statt eines Rahmens.
ThemeData buildKartoTheme({
  required Brightness brightness,
  required bool centerAppBarTitle,
}) {
  final t = brightness == Brightness.dark ? kartoDunkel : kartoHell;
  final radius = BorderRadius.circular(kKartoRadius);
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
    shadow: durchsichtig,
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
    // Kartograph kennt keine Schatten. Was hier durchrutscht, faellt sofort
    // auf, weil sonst nichts in der Oberflaeche schwebt.
    shadowColor: durchsichtig,
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

    cardTheme: CardThemeData(
      color: t.blatt,
      surfaceTintColor: durchsichtig,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: t.grat, width: Strich.grat),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: t.hoehenlinie,
      thickness: Strich.hoehenlinie,
      space: Strich.hoehenlinie,
    ),

    // Unterlinie statt Kasten: ein Feld ist eine beschriebene Zeile, kein
    // eigener Behaelter.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.feld,
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
      shape: RoundedRectangleBorder(borderRadius: radius),
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
        shape: RoundedRectangleBorder(borderRadius: radius),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.schrift,
        side: BorderSide(color: t.grat, width: Strich.grat),
        shape: RoundedRectangleBorder(borderRadius: radius),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.meer,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),

    listTileTheme: ListTileThemeData(
      iconColor: t.schriftLeise,
      textColor: t.schrift,
      shape: RoundedRectangleBorder(borderRadius: radius),
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

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: t.senke,
        borderRadius: radius,
        border: Border.all(color: t.grat, width: Strich.grat),
      ),
      textStyle: textTheme.fliess,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.senke,
      contentTextStyle: textTheme.fliess,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: t.grat, width: Strich.grat),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: t.blatt,
      surfaceTintColor: durchsichtig,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: t.kueste, width: Strich.kueste),
      ),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: t.meer,
      linearTrackColor: t.hoehenlinie,
      circularTrackColor: t.hoehenlinie,
    ),

    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll<Color>(t.grat),
      thickness: const WidgetStatePropertyAll<double>(6),
      radius: const Radius.circular(kKartoRadius),
    ),
  );
}
