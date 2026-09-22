import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:flutter/material.dart';

/// Zeigt die drei bereits berechneten AP-Werte einer Steigerungsrunde.
///
/// Die Darstellung liest Basis, Reservierung und Vorschau direkt aus der
/// Sitzung. Sie führt deshalb bewusst keine eigene Kostenrechnung aus.
class KartoApUebersicht extends StatelessWidget {
  /// Bindet die Anzeige an den unveränderten Zustand derselben Sitzung.
  const KartoApUebersicht({super.key, required this.session});

  /// Enthält die vom Regel-Replay berechneten AP-Werte.
  final AdvancementSession session;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    return Semantics(
      container: true,
      label: 'Abenteuerpunkte der geplanten Entwicklung',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: karto.feld,
          border: Border.all(
            color: karto.hoehenlinie,
            width: Strich.hoehenlinie,
          ),
          borderRadius: BorderRadius.circular(kKartoRadius),
        ),
        child: Padding(
          padding: Abstand.blockInnen,
          child: Wrap(
            spacing: Abstand.bahn,
            runSpacing: Abstand.normal,
            children: [
              _ApWert(label: 'Frei zu Beginn', value: session.base.apAvailable),
              _ApWert(label: 'Reserviert', value: session.apReserved),
              _ApWert(
                label: 'Danach verfügbar',
                value: session.preview.apAvailable,
                emphasized: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApWert extends StatelessWidget {
  const _ApWert({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final int value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final zahlfarbe = emphasized ? karto.meer : karto.schrift;
    // Eine Textzeile aus drei Spans statt eines Satzes: Beschriftung und
    // Einheit bleiben leise, die Zahl traegt das Gewicht. Der zusammengesetzte
    // Klartext ist unveraendert, die Zeile also weiterhin als Ganzes
    // auffindbar und vorlesbar.
    return Text.rich(
      TextSpan(
        style: texte.etikett.copyWith(color: karto.schriftLeise),
        children: <InlineSpan>[
          TextSpan(text: '$label: '),
          TextSpan(
            text: '$value',
            style: texte.wertGross.copyWith(color: zahlfarbe),
          ),
          const TextSpan(text: ' AP'),
        ],
      ),
    );
  }
}
