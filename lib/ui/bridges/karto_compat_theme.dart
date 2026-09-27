import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_feinschliff.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Ergänzt ein Kartograph-Theme um die Rollen der Bestandsoberfläche.
///
/// Die Brücke verändert keine Material-Komponenten und von der Typografie nur
/// einen Slot: `bodySmall` trägt im Bestandsbaum die aufrechte Datenschrift
/// statt der kursiven Legende (`buildKartoBestandsTextTheme`). Die Bestands-
/// widgets greifen für kleine Texte fast immer zu diesem Slot; ohne die
/// Umlegung stünde jede ihrer Beschriftungen in kursiver Serife.
///
/// Der Stil entsteht per `copyWith` auf dem Kartograph-Slot, trägt also
/// dasselbe `inherit`. Überblendet wird dieser verschachtelte Baum ohnehin
/// nie: `Theme` animiert nicht, nur das `AnimatedTheme` der `MaterialApp`.
///
/// Der Kartograph-Feinschliff (Dialogtitel, Tabellen, Aufklappgruppen, Blatt,
/// `KartoRahmen`) wird hier erneut angewendet: aufgelegte Seiten sehen nur das
/// Wurzeltheme, nicht den verschachtelten Feinschliff der `KartoShell`.
ThemeData buildKartoCompatTheme(ThemeData ausgang) {
  final base = buildKartoFeinschliff(ausgang);
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
  return base.copyWith(
    extensions: extensions,
    textTheme: buildKartoBestandsTextTheme(karto, base.textTheme),
  );
}
