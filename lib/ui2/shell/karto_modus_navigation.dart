import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_arbeitsbereich.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

/// Zeigt die drei Aufgabenbereiche eines Helden und meldet eine Auswahl.
///
/// Das Widget besitzt bewusst keinen Providerzugriff. Der umgebende Workspace
/// entscheidet, ob und wann ein angeforderter Bereichswechsel stattfinden darf.
class KartoModusNavigation extends StatelessWidget {
  /// Erstellt die Navigation fuer breite oder kompakte Anordnungen.
  const KartoModusNavigation({
    super.key,
    required this.bereich,
    required this.onAuswahl,
    required this.kompakt,
  });

  /// Der aktuell hervorgehobene Aufgabenbereich.
  final KartoArbeitsbereich bereich;

  /// Meldet den vom Benutzer angeforderten Aufgabenbereich.
  final ValueChanged<KartoArbeitsbereich> onAuswahl;

  /// Ordnet die Ziele horizontal mit kurzen sichtbaren Beschriftungen an.
  final bool kompakt;

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
        ausgewaehlt: bereich == KartoArbeitsbereich.spielen,
        kompakt: kompakt,
        onAuswahl: onAuswahl,
      ),
      _Navigationsziel(
        wert: KartoArbeitsbereich.verwalten,
        icon: Icons.assignment_ind_outlined,
        vollstaendigerName: 'Held verwalten',
        kurzerName: 'Verwalten',
        ausgewaehlt: bereich == KartoArbeitsbereich.verwalten,
        kompakt: kompakt,
        onAuswahl: onAuswahl,
      ),
      _Navigationsziel(
        wert: KartoArbeitsbereich.entwickeln,
        icon: Icons.account_tree_outlined,
        vollstaendigerName: 'Entwicklung planen',
        kurzerName: 'Planen',
        ausgewaehlt: bereich == KartoArbeitsbereich.entwickeln,
        kompakt: kompakt,
        onAuswahl: onAuswahl,
      ),
    ];

    return Material(
      color: token.navigation,
      child: kompakt
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final ziel in ziele) Expanded(child: ziel)],
            )
          : SizedBox(
              width: 232,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: ziele,
              ),
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
    required this.ausgewaehlt,
    required this.kompakt,
    required this.onAuswahl,
  });

  final KartoArbeitsbereich wert;
  final IconData icon;
  final String vollstaendigerName;
  final String kurzerName;
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
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
                child: Text(
                  vollstaendigerName,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: farbe,
                    fontWeight: ausgewaehlt ? FontWeight.w600 : FontWeight.w500,
                  ),
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
              vertical: Abstand.normal,
            ),
            decoration: BoxDecoration(
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
