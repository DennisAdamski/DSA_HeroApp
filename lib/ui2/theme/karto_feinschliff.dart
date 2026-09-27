import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_rahmen.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Komponenten-Themes mit Textstilen, die das Wurzeltheme nicht tragen darf.
///
/// `buildKartoTheme` setzt bewusst keine Textstile an Komponenten: die
/// `MaterialApp` blendet beim Oberflaechenwechsel zwischen Codex- und
/// Kartograph-Theme ueber, und ein Stil, der dort auf `null` trifft, bricht
/// das Ueberblenden. Genau diese Stile braucht die Oberflaeche aber — sonst
/// steht jeder Dialogtitel in `headlineSmall`, und das ist bei Kartograph die
/// grosse Zahlenschrift.
///
/// Deshalb liegen sie hier und werden nur in **verschachtelten** `Theme`s
/// angewendet, die nie ueberblendet werden: in `KartoShell` fuer den Neubau und
/// in `buildKartoCompatTheme` fuer den Bestandsbaum samt aufgelegter Seiten.
/// Jeder Stil entsteht per `copyWith` aus einem Kartograph-Slot, traegt also
/// dasselbe `inherit`. Die Funktion ist idempotent.
ThemeData buildKartoFeinschliff(ThemeData basis) {
  final t =
      basis.extension<KartoTheme>() ??
      (basis.brightness == Brightness.dark ? kartoDunkel : kartoHell);
  final s = basis.textTheme;

  return basis.copyWith(
    dialogTheme: basis.dialogTheme.copyWith(
      titleTextStyle: s.titel,
      // Kartusche: Kueste rundum, Messing oben.
      shape: KartoRahmen(
        side: BorderSide(color: t.kueste, width: Strich.kueste),
        akzent: t.messing,
      ),
    ),
    bottomSheetTheme: basis.bottomSheetTheme.copyWith(
      // Materials 28er Rundung waere die einzige ihrer Art in der Oberflaeche.
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(kKartoRadius),
        ),
        side: BorderSide(color: t.kueste, width: Strich.kueste),
      ),
      dragHandleColor: t.grat,
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll<Color>(t.senke),
      headingTextStyle: s.etikett,
      dataTextStyle: s.fliess.copyWith(
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
      // Zeilen ordnen, nicht zerschneiden: die schwaechste Linie.
      dividerThickness: Strich.hoehenlinie,
      headingRowHeight: 36,
      horizontalMargin: Abstand.weit,
      columnSpacing: Abstand.bahn,
    ),
    // Verschachtelte Reiter (Kampf, Magie, Chroniken ...) als ruhige zweite
    // Ebene: eine senke-Pille statt des Meer-Unterstrichs, den der
    // Verwaltungskopf fuer die oberste Ebene ausdruecklich setzt.
    tabBarTheme: basis.tabBarTheme.copyWith(
      indicator: BoxDecoration(
        color: t.senke,
        borderRadius: BorderRadius.circular(kKartoRadiusKlein),
        border: Border.all(color: t.hoehenlinie, width: Strich.hoehenlinie),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: s.etikett.copyWith(color: t.schrift),
      unselectedLabelStyle: s.etikett,
      labelPadding: const EdgeInsets.symmetric(horizontal: Abstand.weit),
      splashBorderRadius: BorderRadius.circular(kKartoRadiusKlein),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      // Aufgeklappt kein Rahmen: die Gruppe gehoert zu ihrer Flaeche.
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: t.messing,
      collapsedIconColor: t.schriftLeise,
      textColor: t.schrift,
      collapsedTextColor: t.schrift,
    ),
  );
}
