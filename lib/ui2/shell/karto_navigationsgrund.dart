import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_ornamente.dart';

/// Grund der breiten Bereichsnavigation: Verlauf und Hoehenlinien.
///
/// Einer der beiden Verlaeufe, die Kartograph kennt. Er laeuft von
/// `navigation` nach unten leicht dunkler aus, damit die Leiste auf hohen
/// Fenstern nicht als gleichfoermiger Block steht; im unteren Teil liegen
/// Hoehenlinien als Wasserzeichen. Beides ist rein darstellend.
class KartoNavigationsgrund extends StatelessWidget {
  /// Legt [child] auf den Navigationsgrund.
  const KartoNavigationsgrund({super.key, required this.child});

  /// Inhalt der Leiste.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final token = KartoTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            token.navigation,
            Color.lerp(token.navigation, const Color(0xFF000000), 0.3)!,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.55,
              widthFactor: 1,
              child: KartoHoehenlinien(
                farbe: token.navigationText.withValues(alpha: 0.06),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Markenzeile oben in der breiten Navigation.
///
/// Nennt die Anwendung, nicht das Spiel: als inoffizielles Fanprojekt steht
/// hier kein fremder Markenname, der wie ein offizielles Produkt wirkte.
class KartoMarkenzeile extends StatelessWidget {
  /// Erstellt die Markenzeile.
  const KartoMarkenzeile({super.key});

  @override
  Widget build(BuildContext context) {
    final token = KartoTheme.of(context);
    final texte = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        KartoKompassrose(groesse: 22, farbe: token.messingNavigation),
        const SizedBox(width: Abstand.normal),
        Flexible(
          child: Text(
            'HELDENVERWALTUNG',
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: texte.marke.copyWith(
              color: token.navigationMuted,
              letterSpacing: 1.8,
            ),
          ),
        ),
      ],
    );
  }
}
