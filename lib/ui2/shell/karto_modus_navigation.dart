import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_bewegung.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_arbeitsbereich.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_ornamente.dart';

/// Zeigt die drei Aufgabenbereiche eines Helden und meldet eine Auswahl.
///
/// Das Widget besitzt bewusst keinen Providerzugriff. Der umgebende Workspace
/// entscheidet, ob und wann ein angeforderter Bereichswechsel stattfinden darf,
/// und liefert [kopf], [fuss] und [vorgemerkt] als fertige Werte.
///
/// In der breiten Anordnung zeichnet die Navigation **keinen** eigenen Grund:
/// Verlauf und Hoehenlinien liegen darunter (`KartoNavigationsgrund`).
class KartoModusNavigation extends StatelessWidget {
  /// Erstellt die Navigation fuer breite oder kompakte Anordnungen.
  const KartoModusNavigation({
    super.key,
    required this.bereich,
    required this.onAuswahl,
    required this.kompakt,
    this.kopf,
    this.fuss,
    this.vorgemerkt = 0,
  });

  /// Der aktuell hervorgehobene Aufgabenbereich.
  final KartoArbeitsbereich bereich;

  /// Meldet den vom Benutzer angeforderten Aufgabenbereich.
  final ValueChanged<KartoArbeitsbereich> onAuswahl;

  /// Ordnet die Ziele horizontal mit kurzen sichtbaren Beschriftungen an.
  final bool kompakt;

  /// Identitaetsbereich ueber den Zielen. Nur in der breiten Anordnung.
  ///
  /// Ohne ihn stuenden drei Eintraege am oberen Rand einer sonst leeren
  /// dunklen Flaeche — der auffaelligste Gestaltungsfehler der Vorversion.
  final Widget? kopf;

  /// Globale Aktionen unter den Zielen. Nur in der breiten Anordnung.
  final Widget? fuss;

  /// Anzahl vorgemerkter Steigerungen der offenen Runde.
  ///
  /// Steht als Marke an "Entwicklung planen", damit eine offene Planung auch
  /// aus den anderen Bereichen sichtbar bleibt. `0` blendet sie aus.
  final int vorgemerkt;

  /// Rendert drei erreichbare Ziele mit den semantischen Navigationsfarben.
  @override
  Widget build(BuildContext context) {
    final token = KartoTheme.of(context);
    final ziele = <Widget>[
      _Navigationsziel(
        wert: KartoArbeitsbereich.spielen,
        icon: Icons.casino_outlined,
        vollstaendigerName: 'Spielen',
        kurzerName: 'Spielen',
        unterzeile: 'Alles für den Spielabend',
        ausgewaehlt: bereich == KartoArbeitsbereich.spielen,
        kompakt: kompakt,
        onAuswahl: onAuswahl,
      ),
      _Navigationsziel(
        wert: KartoArbeitsbereich.verwalten,
        icon: Icons.person_outline,
        vollstaendigerName: 'Held verwalten',
        kurzerName: 'Verwalten',
        unterzeile: 'Der vollständige Bogen',
        ausgewaehlt: bereich == KartoArbeitsbereich.verwalten,
        kompakt: kompakt,
        onAuswahl: onAuswahl,
      ),
      _Navigationsziel(
        wert: KartoArbeitsbereich.entwickeln,
        icon: Icons.eco_outlined,
        vollstaendigerName: 'Entwicklung planen',
        kurzerName: 'Planen',
        unterzeile: 'Neue Möglichkeiten',
        ausgewaehlt: bereich == KartoArbeitsbereich.entwickeln,
        kompakt: kompakt,
        onAuswahl: onAuswahl,
        marke: vorgemerkt,
      ),
    ];

    if (kompakt) {
      return Material(
        color: token.navigation,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final ziel in ziele) Expanded(child: ziel)],
        ),
      );
    }

    final trenner = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Abstand.block),
      child: Divider(
        color: token.navigationMuted.withValues(alpha: 0.35),
        thickness: Strich.hoehenlinie,
        height: Abstand.bahn,
      ),
    );

    // Transparent, damit Verlauf und Hoehenlinien des Grundes durchscheinen;
    // die Ziele brauchen das Material nur fuer ihre Tintenwirkung.
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kopf != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Abstand.block,
                Abstand.rand,
                Abstand.block,
                0,
              ),
              child: kopf,
            ),
            // Identitaet und Ziele trennt ein Schmuckstrich statt einer
            // Linie: beide gehoeren zu demselben Helden.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Abstand.bahn,
                vertical: Abstand.block,
              ),
              child: KartoZierlinie(
                farbe: token.messingNavigation.withValues(alpha: 0.7),
              ),
            ),
          ] else
            const SizedBox(height: Abstand.weit),
          ...ziele,
          if (fuss != null) ...[
            trenner,
            Padding(
              padding: const EdgeInsets.only(bottom: Abstand.weit),
              child: fuss,
            ),
          ],
        ],
      ),
    );
  }
}

class _Navigationsziel extends StatefulWidget {
  const _Navigationsziel({
    required this.wert,
    required this.icon,
    required this.vollstaendigerName,
    required this.kurzerName,
    required this.unterzeile,
    required this.ausgewaehlt,
    required this.kompakt,
    required this.onAuswahl,
    this.marke = 0,
  });

  final KartoArbeitsbereich wert;
  final IconData icon;
  final String vollstaendigerName;
  final String kurzerName;
  final String unterzeile;
  final bool ausgewaehlt;
  final bool kompakt;
  final ValueChanged<KartoArbeitsbereich> onAuswahl;
  final int marke;

  @override
  State<_Navigationsziel> createState() => _NavigationszielState();
}

class _NavigationszielState extends State<_Navigationsziel> {
  bool _fokussiert = false;
  bool _schwebt = false;

  @override
  Widget build(BuildContext context) {
    final wert = widget.wert;
    final icon = widget.icon;
    final vollstaendigerName = widget.vollstaendigerName;
    final kurzerName = widget.kurzerName;
    final ausgewaehlt = widget.ausgewaehlt;
    final kompakt = widget.kompakt;
    final onAuswahl = widget.onAuswahl;
    final token = KartoTheme.of(context);
    final texte = Theme.of(context).textTheme;
    final farbe = ausgewaehlt ? token.navigationText : token.navigationMuted;
    // Das Symbol traegt den Messingakzent; der Text bleibt hell, damit die
    // Beschriftung ihren Kontrast behaelt.
    final symbolFarbe = ausgewaehlt
        ? token.messingNavigation
        : token.navigationMuted;
    final radius = BorderRadius.circular(kompakt ? 0 : kKartoRadius);
    // Der Fokusrahmen liegt im Vordergrund, damit er die Auswahlkante nicht
    // verdeckt; der Schluessel macht beide Zustaende im Test unterscheidbar.
    final fokusRahmen = _fokussiert
        ? BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: token.navigationText, width: 3),
          )
        : null;
    final zielSchluessel = ValueKey(
      _fokussiert ? 'karto-fokus-${wert.name}' : 'karto-ziel-${wert.name}',
    );
    final marke = widget.marke > 0;
    final markenSchluessel = ValueKey<String>('karto-marke-${wert.name}');
    Widget symbol = Icon(icon, color: symbolFarbe);
    // Kompakt sitzt die Marke am Symbol, breit am Zeilenende: dort verdeckte
    // sie das Symbol, und der Platz ist ohnehin frei.
    if (marke && kompakt) {
      symbol = Badge(
        key: markenSchluessel,
        label: Text('${widget.marke}'),
        backgroundColor: token.messingNavigation,
        textColor: token.navigation,
        child: symbol,
      );
    }
    final inhalt = kompakt
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              symbol,
              const SizedBox(height: Abstand.knapp),
              Text(
                kurzerName,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: texte.labelMedium?.copyWith(
                  color: farbe,
                  fontWeight: ausgewaehlt ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          )
        : Row(
            children: [
              symbol,
              const SizedBox(width: Abstand.weit),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      vollstaendigerName,
                      style: texte.labelLarge?.copyWith(
                        color: farbe,
                        fontWeight: ausgewaehlt
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: Abstand.haar),
                    Text(
                      widget.unterzeile,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: texte.marke.copyWith(
                        color: token.navigationMuted,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              if (marke) ...[
                const SizedBox(width: Abstand.normal),
                DecoratedBox(
                  key: markenSchluessel,
                  decoration: BoxDecoration(
                    color: token.messingNavigation,
                    borderRadius: BorderRadius.circular(kKartoRadiusKlein),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Abstand.knapp,
                      vertical: Abstand.haar,
                    ),
                    child: Text(
                      '${widget.marke}',
                      style: texte.marke.copyWith(color: token.navigation),
                    ),
                  ),
                ),
              ],
            ],
          );

    // Auswahl traegt drei Signale: hellerer Grund, Messingsymbol und die
    // Kante. Die Kante allein war auf einer grossen dunklen Flaeche zu leise.
    final grund = token.navigationText.withValues(
      alpha: ausgewaehlt
          ? 0.09
          : _schwebt
          ? 0.05
          : 0,
    );
    final kante = BorderSide(
      color: token.messingNavigation.withValues(alpha: ausgewaehlt ? 1 : 0),
      width: 3,
    );

    return Tooltip(
      message: vollstaendigerName,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: ausgewaehlt,
        focusable: true,
        focused: _fokussiert,
        onTap: () => onAuswahl(wert),
        label: vollstaendigerName,
        value: marke ? '${widget.marke} vorgemerkt' : null,
        excludeSemantics: true,
        child: Padding(
          // Breit liegt die Auswahl als eingerueckte, abgerundete Flaeche in
          // der Leiste; kompakt fuellt jedes Ziel seinen Anteil der Leiste.
          padding: kompakt
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(
                  horizontal: Abstand.weit,
                  vertical: Abstand.haar,
                ),
          child: ClipRRect(
            borderRadius: radius,
            child: InkWell(
              onTap: () => onAuswahl(wert),
              onHover: (value) => setState(() => _schwebt = value),
              onFocusChange: (value) => setState(() => _fokussiert = value),
              child: AnimatedContainer(
                key: zielSchluessel,
                duration: kartoDauer(context, Bewegung.kurz),
                curve: Bewegung.kurve,
                foregroundDecoration: fokusRahmen,
                constraints: const BoxConstraints(minHeight: 56),
                padding: EdgeInsets.symmetric(
                  horizontal: kompakt ? Abstand.knapp : Abstand.weit,
                  vertical: Abstand.weit,
                ),
                // Keine Rundung an dieser Dekoration: eine einseitige Kante
                // vertraegt keinen Radius. Gerundet wird per ClipRRect.
                decoration: BoxDecoration(
                  color: grund,
                  border: Border(
                    left: kompakt ? BorderSide.none : kante,
                    top: kompakt ? kante : BorderSide.none,
                  ),
                ),
                child: inhalt,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
