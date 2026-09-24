import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Schnellaktionen des Spielbereichs.
///
/// Die Probensuche steht bewusst als gefüllte Schaltfläche vorn: sie öffnet
/// die **vorhandene** vollständige Suche nach Eigenschaften, Kampfwerten,
/// Talenten und Zaubern. Ein nachgezeichnetes Suchfeld gibt es hier nicht,
/// weil es die echte Suche nur vortäuschen würde.
class KartoSpielaktionen extends StatelessWidget {
  /// Erstellt die Schnellaktionen.
  const KartoSpielaktionen({
    super.key,
    required this.onProbeSuchen,
    required this.onRast,
    this.kuerzelHinweis,
  });

  /// Öffnet die vorhandene Probensuche.
  final VoidCallback onProbeSuchen;

  /// Öffnet die vorhandene Rastbedienung.
  final VoidCallback onRast;

  /// Tastaturkürzel, das dieselbe Suche öffnet, etwa `Strg K`.
  final String? kuerzelHinweis;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;

    return Wrap(
      spacing: Abstand.weit,
      runSpacing: Abstand.normal,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          key: const ValueKey<String>('karto-spiel-probe'),
          onPressed: onProbeSuchen,
          icon: const Icon(Icons.search),
          label: const Text('Probe suchen'),
        ),
        OutlinedButton.icon(
          key: const ValueKey<String>('karto-spiel-rast'),
          onPressed: onRast,
          icon: const Icon(Icons.hotel_outlined),
          label: const Text('Rast'),
        ),
        if (kuerzelHinweis != null)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: karto.hoehenlinie,
                width: Strich.hoehenlinie,
              ),
              borderRadius: BorderRadius.circular(kKartoRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Abstand.knapp,
                vertical: Abstand.haar,
              ),
              child: Text(
                kuerzelHinweis!,
                style: texte.marke.copyWith(color: karto.schriftLeise),
              ),
            ),
          ),
      ],
    );
  }
}
