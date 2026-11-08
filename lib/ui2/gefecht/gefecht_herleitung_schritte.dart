import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/ui_shared/herleitung_anzeige.dart';

/// Eine [Herleitung] des Gefechts als Überschrift, sichtbare Schritte mit
/// Rechenweg, Quelle und Bedingung und Ergebniszeile.
///
/// Setzt die gemeinsamen Bausteine `HerleitungsSchritte` und `HerleitungsZeile`
/// aus `lib/ui_shared/` zusammen. Es rechnet nichts: das Ergebnis ist
/// [Herleitung.wert].
class GefechtHerleitungSchritte extends StatelessWidget {
  /// Zeigt [herleitung] unter ihrer eigenen Bezeichnung.
  const GefechtHerleitungSchritte({super.key, required this.herleitung});

  /// Anzuzeigende Herleitung.
  final Herleitung herleitung;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        key: ValueKey('gefecht-herleitung-${herleitung.bezeichnung}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            herleitung.bezeichnung,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          HerleitungsSchritte(herleitung: herleitung, bezeichnungBreite: null),
          const Divider(height: 12),
          HerleitungsZeile(
            bezeichnung: herleitung.bezeichnung,
            wert: herleitung.wert,
            fett: true,
            vorzeichen: false,
            bezeichnungBreite: null,
          ),
        ],
      ),
    );
  }
}
