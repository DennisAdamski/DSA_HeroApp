import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Abschnittsrahmen der Spielansicht: Überschrift, optionale Aktion, Inhalt.
///
/// Kartograph gliedert mit Linien statt mit Kästen, deshalb trägt der Rahmen
/// nur eine [Strich.grat]-Umrandung und keine Füllung oder Erhöhung.
/// Listenaktionen stehen laut Projektrichtlinie im Abschnittskopf.
class KartoAbschnitt extends StatelessWidget {
  /// Erstellt einen benannten Abschnitt.
  const KartoAbschnitt({
    super.key,
    required this.titel,
    required this.child,
    this.hinweis,
    this.aktion,
  });

  /// Überschrift des Abschnitts.
  final String titel;

  /// Inhalt unterhalb der Überschrift.
  final Widget child;

  /// Ruhige Zweitzeile neben der Überschrift.
  final String? hinweis;

  /// Aktion im Abschnittskopf, etwa `Effekte verwalten`.
  final Widget? aktion;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: karto.grat, width: Strich.grat),
        borderRadius: BorderRadius.circular(kKartoRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Abstand.block),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(titel, style: texte.abschnitt),
                      if (hinweis != null)
                        Text(
                          hinweis!,
                          style: texte.legende.copyWith(
                            color: karto.schriftLeise,
                          ),
                        ),
                    ],
                  ),
                ),
                if (aktion != null) ...[
                  const SizedBox(width: Abstand.normal),
                  aktion!,
                ],
              ],
            ),
            const SizedBox(height: Abstand.weit),
            child,
          ],
        ),
      ),
    );
  }
}
