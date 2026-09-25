import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

/// Die drei Flaechenstufen der neuen Oberflaeche.
///
/// Sie tragen die Tiefe, so wie [StrichGewicht] die Gliederung traegt. Weil
/// Liegendes in Kartograph keinen Schatten wirft, ist der Flaechenunterschied
/// das einzige Mittel, eine Ebene von der darunterliegenden zu unterscheiden;
/// Schatten bleiben dem Schwebenden vorbehalten (`KartoTiefe`).
///
/// Die Reihenfolge ist in **beiden** Paletten dieselbe: [senke] liegt zurueck,
/// [blatt] ist der Grund, [feld] tritt hervor. Hell wird `feld` dazu heller und
/// `senke` dunkler, dunkel genau umgekehrt — die Rolle bleibt gleich, nur der
/// Zahlenwert dreht.
enum KartoFlaechenstufe {
  /// Zurueckgesetzt: Kontextspalten, Leisten, Tabellenkoepfe.
  senke,

  /// Der Grund der Seite. Nichts liegt dahinter.
  blatt,

  /// Hervortretend: Abschnitte, Karten, Dialoge.
  feld;

  /// Liefert die Farbe dieser Stufe aus den aktiven Token.
  Color farbe(KartoTheme token) => switch (this) {
    KartoFlaechenstufe.senke => token.senke,
    KartoFlaechenstufe.blatt => token.blatt,
    KartoFlaechenstufe.feld => token.feld,
  };
}

/// Gefuellte Flaeche mit gepaarter Kante.
///
/// Ersetzt die frueher an jeder Stelle einzeln aufgebaute [BoxDecoration]. Der
/// Grund ist derselbe, aus dem [Strich] existiert: die Paarung aus Linienstaerke
/// und Farbtoken laesst sich nur durchsetzen, wenn das Primitiv keine freien
/// Parameter dafuer anbietet. [kante] waehlt deshalb ein [StrichGewicht] und
/// nicht Farbe und Breite.
class KartoFlaeche extends StatelessWidget {
  /// Erstellt eine Flaeche der angegebenen Stufe.
  const KartoFlaeche({
    super.key,
    required this.child,
    this.stufe = KartoFlaechenstufe.feld,
    this.kante = StrichGewicht.hoehenlinie,
    this.innen,
    this.klein = false,
    this.toenung,
  });

  /// Inhalt der Flaeche.
  final Widget child;

  /// Ebene der Flaeche innerhalb der dreistufigen Hierarchie.
  final KartoFlaechenstufe stufe;

  /// Staerke der umlaufenden Kante. `null` laesst sie weg.
  ///
  /// Mit Fuellung genuegt die schwaechste Linie: die Flaeche trennt bereits,
  /// die Kante schaerft nur noch. [StrichGewicht.kueste] bleibt echten
  /// Bereichsgrenzen vorbehalten.
  final StrichGewicht? kante;

  /// Innenabstand. `null` laesst den Inhalt die Flaeche selbst fuellen.
  final EdgeInsetsGeometry? innen;

  /// Nutzt den Radius kleiner Bedienelemente statt des Flaechenradius.
  final bool klein;

  /// Halbtransparente Farbe, die ueber die Stufe gelegt wird.
  ///
  /// Die Stufe bleibt massgeblich; die Toenung faerbt nur leicht ein, etwa
  /// astral fuer laufende Zauber. Deckend darf sie nicht sein, sonst waere es
  /// eine vierte Flaechenstufe.
  final Color? toenung;

  BorderSide? _kante(KartoTheme token) => switch (kante) {
    null => null,
    StrichGewicht.hoehenlinie => BorderSide(
      color: token.hoehenlinie,
      width: Strich.hoehenlinie,
    ),
    StrichGewicht.grat => BorderSide(color: token.grat, width: Strich.grat),
    StrichGewicht.kueste => BorderSide(
      color: token.kueste,
      width: Strich.kueste,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final token = KartoTheme.of(context);
    final seite = _kante(token);
    final inhalt = innen == null
        ? child
        : Padding(padding: innen!, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: toenung == null
            ? stufe.farbe(token)
            : Color.alphaBlend(toenung!, stufe.farbe(token)),
        border: seite == null ? null : Border.fromBorderSide(seite),
        borderRadius: BorderRadius.circular(
          klein ? kKartoRadiusKlein : kKartoRadius,
        ),
      ),
      child: inhalt,
    );
  }
}
