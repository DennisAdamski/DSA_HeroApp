import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';

/// Abschnittsrahmen der Spielansicht: Überschrift, optionale Aktion, Inhalt.
///
/// Der Abschnitt ist eine **gefüllte** Fläche. Vorher trug er nur einen Rahmen
/// auf dem Seitengrund; dadurch entstand keine Tiefe, und sechs Abschnitte
/// untereinander sahen aus wie sechs gleiche Formularkästen. Die Fläche trennt
/// jetzt, die Kante schärft nur noch.
///
/// Listenaktionen stehen laut Projektrichtlinie im Abschnittskopf.
class KartoAbschnitt extends StatelessWidget {
  /// Erstellt einen benannten Abschnitt.
  const KartoAbschnitt({
    super.key,
    required this.titel,
    required this.child,
    this.hinweis,
    this.aktion,
    this.stufe = KartoFlaechenstufe.feld,
  });

  /// Überschrift des Abschnitts.
  final String titel;

  /// Inhalt unterhalb der Überschrift.
  final Widget child;

  /// Ruhige Zweitzeile unter der Überschrift.
  ///
  /// Sparsam einsetzen. Eine Zeile unter **jeder** Überschrift ergibt sechs
  /// Erklärungen pro Ansicht, von denen die meisten das Offensichtliche sagen.
  /// Der Seitenkopf trägt die Einordnung der Ansicht, nicht der Abschnitt.
  final String? hinweis;

  /// Aktion im Abschnittskopf, etwa `Effekte verwalten`.
  final Widget? aktion;

  /// Flächenstufe; die Kontextspalte sitzt bewusst zurückgesetzt.
  final KartoFlaechenstufe stufe;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final zweitzeile = hinweis?.trim() ?? '';

    return KartoFlaeche(
      stufe: stufe,
      innen: const EdgeInsets.all(Abstand.block),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final kopf = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(titel, style: texte.abschnitt),
                  if (zweitzeile.isNotEmpty) ...[
                    const SizedBox(height: Abstand.eng),
                    // Etikett statt der kursiven Legende: kursiv gesetzte
                    // Serife in Fliesstextgroesse liest sich als zweite
                    // Ueberschrift, nicht als Beiwerk.
                    Text(
                      zweitzeile,
                      style: texte.etikett.copyWith(color: karto.schriftLeise),
                    ),
                  ],
                ],
              );
              if (aktion == null) return kopf;
              // Wrap statt Row: in einer schmalen Seitenspalte passt eine
              // ausgeschriebene Kopfaktion sonst nicht mehr neben den Titel
              // und laeuft um Bruchteile eines Pixels ueber.
              return Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Abstand.normal,
                runSpacing: Abstand.normal,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: kopf,
                  ),
                  aktion!,
                ],
              );
            },
          ),
          const SizedBox(height: Abstand.weit),
          child,
        ],
      ),
    );
  }
}
