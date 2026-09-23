import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Kopfzeile einer Arbeitsflaeche: Kontextzeile, Titel, eine Aktion.
///
/// Optional folgen dem Titel eine leise [unterzeile] und eine kurze
/// [beschreibung] — die Spielansicht setzt dort Datum und Zusammenfassung des
/// laufenden Abenteuers, das dann selbst den Titel traegt.
///
/// Der Titel ist die einzige Stelle, an der [KartoRollen.titelGross] vorkommt.
/// Ohne ihn beginnt jede Ansicht bei der Abschnittsgroesse, und es entsteht
/// keine Hierarchie — genau das war der Zustand vor dieser Ueberarbeitung.
///
/// Getrennt wird **nur durch Weissraum**, nicht durch eine Linie. Eine Regel
/// unter jeder Ueberschrift ergaebe zusammen mit den Abschnittskanten ein
/// Liniengitter, und die Ruhe der Flaeche ist hier mehr wert als die Kante.
class KartoSeitenkopf extends StatelessWidget {
  /// Erstellt die Kopfzeile einer Arbeitsflaeche.
  const KartoSeitenkopf({
    super.key,
    required this.titel,
    this.kontext,
    this.aktion,
    this.unterzeile,
    this.beschreibung,
    this.kompakt = false,
  });

  /// Name der Arbeitsflaeche, etwa `Am Spieltisch`.
  ///
  /// Darf die Beschriftungen der Bereichsnavigation nicht wiederholen: beide
  /// stuenden sonst gleichzeitig im Baum, und die Navigationspruefungen
  /// erwarten ihre Beschriftung genau einmal.
  final String titel;

  /// Ruhige Zeile ueber dem Titel, etwa der Name der Ansicht, wenn das
  /// laufende Abenteuer den Titel traegt.
  ///
  /// Steht **nur** hier und nie ueber einem Abschnitt — sonst entsteht wieder
  /// eine Zweitzeile pro Kasten.
  final String? kontext;

  /// Einzelne Aktion rechts neben dem Titel.
  final Widget? aktion;

  /// Leise Zeile direkt unter dem Titel, etwa das aventurische Datum.
  final String? unterzeile;

  /// Kurzer Fliesstext unter dem Titel, auf wenige Zeilen gekuerzt.
  ///
  /// Der Kopf ist keine Leseflaeche: laengere Texte gehoeren in ihre
  /// Fachansicht, hier dienen sie nur als Gedaechtnisstuetze.
  final String? beschreibung;

  /// Verkleinert den Titel fuer schmale Fenster.
  final bool kompakt;

  @override
  Widget build(BuildContext context) {
    final token = KartoTheme.of(context);
    final texte = Theme.of(context).textTheme;
    final kontextzeile = kontext?.trim() ?? '';
    final datumszeile = unterzeile?.trim() ?? '';
    final text = beschreibung?.trim() ?? '';
    final titelStil = kompakt ? texte.titel : texte.titelGross;

    final ueberschrift = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (kontextzeile.isNotEmpty) ...[
          Text(
            kontextzeile,
            style: texte.etikett.copyWith(color: token.schriftLeise),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Abstand.knapp),
        ],
        Text(titel, style: titelStil),
        if (datumszeile.isNotEmpty) ...[
          const SizedBox(height: Abstand.eng),
          Text(
            datumszeile,
            style: texte.etikett.copyWith(color: token.schriftLeise),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (text.isNotEmpty) ...[
          const SizedBox(height: Abstand.normal),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Breite.lesespalte),
            child: Text(
              text,
              style: texte.fliess.copyWith(color: token.schrift),
              // Schmale Fenster brauchen die Hoehe fuer die erste Aktion.
              maxLines: kompakt ? 2 : 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );

    return Padding(
      // Schmale Fenster geben ihre Hoehe nicht so freigiebig her.
      padding: EdgeInsets.only(bottom: kompakt ? Abstand.block : Abstand.bahn),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (aktion == null) return ueberschrift;
          // Wrap statt Row: eine ausgeschriebene Aktion passt neben einem
          // langen Titel auf Tabletbreiten sonst nicht mehr in die Zeile.
          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Abstand.weit,
            runSpacing: Abstand.weit,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: ueberschrift,
              ),
              aktion!,
            ],
          );
        },
      ),
    );
  }
}
