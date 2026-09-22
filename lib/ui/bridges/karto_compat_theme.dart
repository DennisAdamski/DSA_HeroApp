import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

/// Ergänzt ein Kartograph-Theme um die Rollen der Bestandsoberfläche.
///
/// Die Brücke verändert weder Material-Komponenten noch Typografie. Dadurch
/// bleiben Bestandswidgets im neuen Rahmen lesbar, ohne dort ein zweites
/// Designsystem oder nicht interpolierbare Textstile einzuführen.
ThemeData buildKartoCompatTheme(ThemeData base) {
  final karto =
      base.extension<KartoTheme>() ??
      (base.brightness == Brightness.dark ? kartoDunkel : kartoHell);
  final codex = CodexTheme(
    parchment: karto.blatt,
    parchmentStrong: karto.senke,
    panel: karto.feld,
    panelRaised: karto.senke,
    ink: karto.schrift,
    inkMuted: karto.schriftLeise,
    brass: karto.meer,
    brassMuted: karto.hoehenlinie,
    rule: karto.hoehenlinie,
    accent: karto.meer,
    success: karto.moos,
    warning: karto.wachs,
    danger: karto.siegel,
    heroGradient: LinearGradient(colors: <Color>[karto.blatt, karto.blatt]),
    heroGradientSoft: LinearGradient(colors: <Color>[karto.senke, karto.senke]),
    sectionRadius: kKartoRadius,
    panelRadius: kKartoRadius,
    showDecoration: false,
  );
  final extensions = <ThemeExtension>[];
  for (final extension in base.extensions.values) {
    if (extension is! CodexTheme) {
      // Flutter exposes the map through the F-bounded ThemeExtension type;
      // the raw list preserves heterogeneous extension implementations.
      extensions.add(extension as dynamic);
    }
  }
  extensions.add(codex);
  return base.copyWith(extensions: extensions);
}
