import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';

/// Eine [Herleitung] des Gefechts als Überschrift, sichtbare Schritte mit
/// Rechenweg, Quelle und Bedingung und Ergebniszeile.
///
/// Gegenstück zu `HerleitungsSchritte` des Bestands (`lib/ui/`), das UI2 nicht
/// importieren darf. Es rechnet nichts: das Ergebnis ist [Herleitung.wert].
class GefechtHerleitungSchritte extends StatelessWidget {
  /// Zeigt [herleitung] unter ihrer eigenen Bezeichnung.
  const GefechtHerleitungSchritte({super.key, required this.herleitung});

  /// Anzuzeigende Herleitung.
  final Herleitung herleitung;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leise = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
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
          for (final schritt in herleitung.sichtbareSchritte) ...[
            _Zeile(
              bezeichnung: schritt.bezeichnung,
              wert: schritt.betrag,
              vorzeichen: schritt.art != HerleitungsArt.grundwert,
            ),
            if ([?schritt.formel, ?schritt.quelle, ?schritt.bedingung]
                case final details when details.isNotEmpty)
              Text(
                details.join(' · '),
                style: leise?.copyWith(fontStyle: FontStyle.italic),
              ),
          ],
          const Divider(height: 12),
          _Zeile(
            bezeichnung: herleitung.bezeichnung,
            wert: herleitung.wert,
            fett: true,
            vorzeichen: false,
          ),
        ],
      ),
    );
  }
}

class _Zeile extends StatelessWidget {
  const _Zeile({
    required this.bezeichnung,
    required this.wert,
    this.fett = false,
    this.vorzeichen = true,
  });

  final String bezeichnung;
  final int wert;
  final bool fett, vorzeichen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stil = theme.textTheme.bodySmall?.copyWith(
      fontWeight: fett ? FontWeight.bold : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(bezeichnung, style: stil)),
          Text('${vorzeichen && wert >= 0 ? '+' : ''}$wert', style: stil),
        ],
      ),
    );
  }
}
