import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kontext_rules.dart';

/// Aktuelle Distanzklasse als direkt wählbare Chipreihe.
///
/// Ausgeschriebene Namen ersetzen die Einzelbuchstaben; die Reihe bricht auf
/// schmalen Fenstern um, statt ein Auswahlmenü zu öffnen.
class GefechtDkWahl extends StatelessWidget {
  /// [wert] `null` bedeutet unbekannt; dann ist keine Klasse markiert.
  const GefechtDkWahl({super.key, required this.wert, required this.onChanged});

  /// Gewählte Distanzklasse (H, N, S, P) oder `null`.
  final String? wert;

  /// Meldet die neu gewählte Distanzklasse.
  final ValueChanged<String> onChanged;

  /// Reihenfolge der Distanzklassen von nah nach fern.
  static const klassen = ['H', 'N', 'S', 'P'];

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Aktuelle Distanzklasse', style: texte.labelMedium),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final dk in klassen)
                ChoiceChip(
                  key: ValueKey('gefecht-dk-$dk'),
                  label: Text(gefechtsDistanzname(dk)),
                  selected: wert == dk,
                  onSelected: (_) => onChanged(dk),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
