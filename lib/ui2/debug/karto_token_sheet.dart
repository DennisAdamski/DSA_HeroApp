import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Zeigt alle Token der neuen Oberflaeche auf einer Seite.
///
/// Zweck ist die Sichtpruefung: Farben, Linienstaerken und Schriftrollen
/// nebeneinander, in der gerade aktiven Helligkeit. Zwei Abschnitte sind dabei
/// besonders wichtig, weil sie Fehler zeigen, die sonst erst im Betrieb
/// auffallen: die Gewichtsprobe deckt einen nur behaupteten Fettschnitt auf,
/// die Ziffernprobe fehlende Tabellenziffern.
///
/// Die Seite gehoert nicht zur Anwendung. Sie ist nur im Debugmodus
/// erreichbar und faellt nicht ins Gewicht, weil sie nichts laedt.
class KartoTokenSheet extends StatelessWidget {
  /// Erstellt das Token-Blatt.
  const KartoTokenSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final t = KartoTheme.of(context);
    final s = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Token-Blatt')),
      body: ListView(
        padding: const EdgeInsets.all(Abstand.bahn),
        children: [
          _Abschnitt(
            titel: 'Flächen',
            erklaerung:
                'Drei Ebenen, mehr gibt es nicht. Tiefe entsteht durch '
                'Linien, nicht durch Schatten.',
            child: Wrap(
              spacing: Abstand.weit,
              runSpacing: Abstand.weit,
              children: [
                _Feld('blatt', t.blatt, t),
                _Feld('feld', t.feld, t),
                _Feld('senke', t.senke, t),
              ],
            ),
          ),
          _Abschnitt(
            titel: 'Linien',
            erklaerung:
                'Die Linienstärke trägt die Hierarchie, so wie eine Karte '
                'Küste von Höhenlinie unterscheidet. Jede Stärke gehört fest '
                'zu einer Farbe.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Linie('kueste', t.kueste, Strich.kueste, s),
                _Linie('grat', t.grat, Strich.grat, s),
                _Linie('hoehenlinie', t.hoehenlinie, Strich.hoehenlinie, s),
              ],
            ),
          ),
          _Abschnitt(
            titel: 'Schrift und Signale',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Farbzeile('schrift', t.schrift, s),
                _Farbzeile('schriftLeise', t.schriftLeise, s),
                _Farbzeile('schriftStumm', t.schriftStumm, s),
                const SizedBox(height: Abstand.weit),
                _Farbzeile('meer · Interaktion', t.meer, s),
                _Farbzeile('siegel · Nachdruck', t.siegel, s),
                _Farbzeile('wachs · Warnung', t.wachs, s),
                _Farbzeile('moos · Bestätigung', t.moos, s),
                const SizedBox(height: Abstand.weit),
                _Farbzeile('lebensenergie', t.lebensenergie, s),
                _Farbzeile('astralenergie', t.astralenergie, s),
                _Farbzeile('ausdauer', t.ausdauer, s),
              ],
            ),
          ),
          _Abschnitt(
            titel: 'Navigation',
            erklaerung:
                'Die Navigation bleibt dunkel und verwendet eigene '
                'Textrollen fuer aktive und ruhige Ziele.',
            child: Container(
              color: t.navigation,
              padding: const EdgeInsets.all(Abstand.block),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'navigationText',
                    style: s.fliess.copyWith(color: t.navigationText),
                  ),
                  const SizedBox(height: Abstand.knapp),
                  Text(
                    'navigationMuted',
                    style: s.fliess.copyWith(color: t.navigationMuted),
                  ),
                ],
              ),
            ),
          ),
          _Abschnitt(
            titel: 'Die neun Schriftrollen',
            erklaerung:
                'Bereichs-Code wählt nie eine Größe, sondern ein Baustein, '
                'und der Baustein wählt hier.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alrik Feuerstein', style: s.titelGross),
                Text('Talente', style: s.titel),
                Text('Körperliche Talente', style: s.abschnitt),
                Text(
                  'Erschwernis durch Behinderung, siehe Seite 42.',
                  style: s.legende,
                ),
                Text(
                  'Fließtext trägt die Erklärungen und bleibt bei etwa '
                  'siebzig Zeichen je Zeile gut lesbar.',
                  style: s.fliess,
                ),
                const SizedBox(height: Abstand.normal),
                Text('Talentwert', style: s.etikett),
                Text('12', style: s.wert),
                const SizedBox(height: Abstand.normal),
                Text('Lebensenergie', style: s.etikett),
                Text('32', style: s.wertGross),
                const SizedBox(height: Abstand.normal),
                Text('Meisterentscheid', style: s.marke),
              ],
            ),
          ),
          _Abschnitt(
            titel: 'Gewichtsprobe',
            erklaerung:
                'Die drei Zeilen je Familie müssen sichtbar verschieden '
                'laufen. Sehen zwei gleich aus, zeigen sie auf dieselbe '
                'Schriftdatei und der Fettschnitt ist nur behauptet.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Spectral', style: s.etikett),
                for (final g in <FontWeight>[
                  FontWeight.w400,
                  FontWeight.w500,
                  FontWeight.w600,
                ])
                  Text(
                    'Handgemenge und Hiebwaffen ${g.value}',
                    style: TextStyle(
                      fontFamily: kSchriftTitel,
                      fontSize: 20,
                      fontWeight: g,
                      color: t.schrift,
                    ),
                  ),
                const SizedBox(height: Abstand.weit),
                Text('Inter Tight', style: s.etikett),
                for (final g in <double>[400, 500, 600])
                  Text(
                    'Handgemenge und Hiebwaffen ${g.toInt()}',
                    style: TextStyle(
                      fontFamily: kSchriftDaten,
                      fontSize: 20,
                      fontVariations: <FontVariation>[FontVariation('wght', g)],
                      color: t.schrift,
                    ),
                  ),
              ],
            ),
          ),
          _Abschnitt(
            titel: 'Ziffernprobe',
            erklaerung:
                'Alle vier Zeilen müssen exakt gleich breit enden. Tun sie '
                'das nicht, fehlen die Tabellenziffern und Zahlen stehen in '
                'Spalten nicht untereinander.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final zeile in <String>[
                  '1111111111',
                  '0000000000',
                  '8888888888',
                  '1234567890',
                ])
                  Text(zeile, style: s.wert),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Abschnitt extends StatelessWidget {
  const _Abschnitt({required this.titel, required this.child, this.erklaerung});

  final String titel;
  final String? erklaerung;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = KartoTheme.of(context);
    final s = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Abstand.bahn),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: t.kueste, width: Strich.kueste),
              ),
            ),
            padding: const EdgeInsets.only(top: Abstand.normal),
            width: double.infinity,
            child: Text(titel, style: s.abschnitt),
          ),
          if (erklaerung != null) ...[
            const SizedBox(height: Abstand.eng),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Breite.lesespalte),
              child: Text(erklaerung!, style: s.legende),
            ),
          ],
          const SizedBox(height: Abstand.block),
          child,
        ],
      ),
    );
  }
}

class _Feld extends StatelessWidget {
  const _Feld(this.name, this.farbe, this.t);

  final String name;
  final Color farbe;
  final KartoTheme t;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 140,
          height: 64,
          decoration: BoxDecoration(
            color: farbe,
            border: Border.all(color: t.grat, width: Strich.grat),
          ),
        ),
        const SizedBox(height: Abstand.eng),
        Text(name, style: Theme.of(context).textTheme.etikett),
      ],
    );
  }
}

class _Linie extends StatelessWidget {
  const _Linie(this.name, this.farbe, this.staerke, this.s);

  final String name;
  final Color farbe;
  final double staerke;
  final TextTheme s;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Abstand.block),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$name · ${staerke}px', style: s.etikett),
          const SizedBox(height: Abstand.eng),
          Container(height: staerke, width: 320, color: farbe),
        ],
      ),
    );
  }
}

class _Farbzeile extends StatelessWidget {
  const _Farbzeile(this.name, this.farbe, this.s);

  final String name;
  final Color farbe;
  final TextTheme s;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Abstand.knapp),
      child: Row(
        children: [
          Container(width: 20, height: 20, color: farbe),
          const SizedBox(width: Abstand.weit),
          Text(name, style: s.fliess.copyWith(color: farbe)),
        ],
      ),
    );
  }
}
