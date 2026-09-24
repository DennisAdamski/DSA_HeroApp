import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_arbeitsbereich.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Zeigt die drei Aufgabenbereiche eines Helden und meldet eine Auswahl.
///
/// Das Widget besitzt bewusst keinen Providerzugriff. Der umgebende Workspace
/// entscheidet, ob und wann ein angeforderter Bereichswechsel stattfinden darf,
/// und liefert [kopf] und [fuss] als fertige Widgets.
class KartoModusNavigation extends StatelessWidget {
  /// Erstellt die Navigation fuer breite oder kompakte Anordnungen.
  const KartoModusNavigation({
    super.key,
    required this.bereich,
    required this.onAuswahl,
    required this.kompakt,
    this.kopf,
    this.fuss,
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
        icon: Icons.assignment_ind_outlined,
        vollstaendigerName: 'Held verwalten',
        kurzerName: 'Verwalten',
        unterzeile: 'Der vollständige Bogen',
        ausgewaehlt: bereich == KartoArbeitsbereich.verwalten,
        kompakt: kompakt,
        onAuswahl: onAuswahl,
      ),
      _Navigationsziel(
        wert: KartoArbeitsbereich.entwickeln,
        icon: Icons.account_tree_outlined,
        vollstaendigerName: 'Entwicklung planen',
        kurzerName: 'Planen',
        unterzeile: 'Neue Möglichkeiten',
        ausgewaehlt: bereich == KartoArbeitsbereich.entwickeln,
        kompakt: kompakt,
        onAuswahl: onAuswahl,
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

    return Material(
      color: token.navigation,
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
            trenner,
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
  });

  final KartoArbeitsbereich wert;
  final IconData icon;
  final String vollstaendigerName;
  final String kurzerName;
  final String unterzeile;
  final bool ausgewaehlt;
  final bool kompakt;
  final ValueChanged<KartoArbeitsbereich> onAuswahl;

  @override
  State<_Navigationsziel> createState() => _NavigationszielState();
}

class _NavigationszielState extends State<_Navigationsziel> {
  bool _fokussiert = false;

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
    // Der Fokusrahmen liegt im Vordergrund, damit er die Auswahlkante nicht
    // verdeckt; der Schluessel macht beide Zustaende im Test unterscheidbar.
    final fokusRahmen = _fokussiert
        ? BoxDecoration(
            border: Border.all(color: token.navigationText, width: 3),
          )
        : null;
    final zielSchluessel = ValueKey(
      _fokussiert ? 'karto-fokus-${wert.name}' : 'karto-ziel-${wert.name}',
    );
    final inhalt = kompakt
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: farbe),
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
              Icon(icon, color: farbe),
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
            ],
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
        excludeSemantics: true,
        child: InkWell(
          onTap: () => onAuswahl(wert),
          onFocusChange: (value) => setState(() => _fokussiert = value),
          child: Container(
            key: zielSchluessel,
            foregroundDecoration: fokusRahmen,
            constraints: const BoxConstraints(minHeight: 56),
            padding: EdgeInsets.symmetric(
              horizontal: kompakt ? Abstand.knapp : Abstand.block,
              vertical: Abstand.weit,
            ),
            decoration: BoxDecoration(
              // Auswahl traegt drei Signale: hellerer Grund, hellerer Text und
              // die Kante. Die Kante allein war auf einer grossen dunklen
              // Flaeche zu leise.
              color: ausgewaehlt
                  ? token.navigationText.withValues(alpha: 0.08)
                  : null,
              border: Border(
                left: kompakt
                    ? BorderSide.none
                    : BorderSide(
                        color: ausgewaehlt
                            ? token.navigationText
                            : Colors.transparent,
                        width: 3,
                      ),
                top: kompakt
                    ? BorderSide(
                        color: ausgewaehlt
                            ? token.navigationText
                            : Colors.transparent,
                        width: 3,
                      )
                    : BorderSide.none,
              ),
            ),
            child: inhalt,
          ),
        ),
      ),
    );
  }
}
