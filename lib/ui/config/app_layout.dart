import 'package:flutter/material.dart';

/// Gemeinsame Layoutklassen fuer kompakte, Tablet- und breite Arbeitsflaechen.
enum AppLayoutClass {
  /// Schmale Smartphones und enge Fenster.
  compact,

  /// Tablet-Portrait mit Fokusinhalt und optionalem Detail-Sheet.
  tabletPortrait,

  /// Tablet-Landscape mit persistenter Arbeitsnavigation.
  tabletLandscape,

  /// Sehr breite Fenster mit grosszuegigem Drei-Spalten-Layout.
  desktopWide,
}

/// Untergrenze fuer Tablet-Portrait-Layouts.
const double kTabletPortraitBreakpoint = 744;

/// Untergrenze fuer Tablet-Landscape-Layouts.
const double kTabletLandscapeBreakpoint = 1024;

/// Untergrenze fuer sehr breite Desktop-/iPad-Pro-Layouts.
const double kDesktopWideBreakpoint = 1366;

/// Ermittelt die app-weite Layoutklasse anhand der verfuegbaren Breite.
AppLayoutClass appLayoutForWidth(double width) {
  if (width >= kDesktopWideBreakpoint) {
    return AppLayoutClass.desktopWide;
  }
  if (width >= kTabletLandscapeBreakpoint) {
    return AppLayoutClass.tabletLandscape;
  }
  if (width >= kTabletPortraitBreakpoint) {
    return AppLayoutClass.tabletPortrait;
  }
  return AppLayoutClass.compact;
}

/// Liefert die aktuelle Layoutklasse aus dem Build-Kontext.
AppLayoutClass appLayoutOf(BuildContext context) {
  return appLayoutForWidth(MediaQuery.sizeOf(context).width);
}

/// Komfortfunktionen fuer Layout-spezifische Darstellung.
extension AppLayoutClassX on AppLayoutClass {
  /// Kennzeichnet alle Tablet- und breiteren Layouts.
  bool get isTablet =>
      this == AppLayoutClass.tabletPortrait ||
      this == AppLayoutClass.tabletLandscape ||
      this == AppLayoutClass.desktopWide;

  /// Kennzeichnet Layouts mit dauerhafter Detailspalte.
  bool get hasPersistentDetailPane =>
      this == AppLayoutClass.tabletLandscape ||
      this == AppLayoutClass.desktopWide;

  /// Liefert grosszuegigere Standardabstaende fuer breite Layouts.
  double get contentPadding {
    return switch (this) {
      AppLayoutClass.compact => 16,
      AppLayoutClass.tabletPortrait => 20,
      AppLayoutClass.tabletLandscape => 24,
      AppLayoutClass.desktopWide => 28,
    };
  }
}
