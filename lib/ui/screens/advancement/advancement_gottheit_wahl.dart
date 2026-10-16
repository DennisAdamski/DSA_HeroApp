import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/karma_gottheit_rules.dart';

/// Auswahl der Gottheit im Karmabereich der Steigerungsplanung.
///
/// Die Gottheit legt fest, welche gottheitsgebundenen karmalen
/// Sonderfertigkeiten (Pfade der Erleuchteten, Ausgleichssegen) erscheinen.
/// Gespeichert wird über [onChanged], das die offene Runde erhält.
class AdvancementGottheitWahl extends StatelessWidget {
  /// Zeigt die aktuelle Gottheit; leer heißt „nicht festgelegt“.
  const AdvancementGottheitWahl({
    super.key,
    required this.gottheit,
    required this.onChanged,
  });

  /// Gespeicherte Gottheit des Helden.
  final String gottheit;

  /// Speichert eine neue Gottheit; `null` sperrt die Auswahl.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final aktuell = gottheit.trim();
    final werte = <String>[
      '',
      ...kGottheitVorschlaege,
      if (aktuell.isNotEmpty && !kGottheitVorschlaege.contains(aktuell))
        aktuell,
    ];
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          // Der Schlüssel baut das Feld neu, wenn die Gottheit gespeichert
          // wurde; `initialValue` gilt sonst nur beim ersten Aufbau.
          key: ValueKey('advancement-gottheit-wert-$aktuell'),
          constraints: const BoxConstraints(maxWidth: 360),
          child: DropdownButtonFormField<String>(
            key: const ValueKey('advancement-gottheit'),
            initialValue: aktuell,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Gottheit',
              isDense: true,
            ),
            items: [
              for (final wert in werte)
                DropdownMenuItem(
                  value: wert,
                  child: Text(wert.isEmpty ? 'Nicht festgelegt' : wert),
                ),
            ],
            onChanged: onChanged == null
                ? null
                : (wert) {
                    if (wert != null && wert != aktuell) onChanged!(wert);
                  },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          aktuell.isEmpty
              ? 'Ohne Gottheit erscheinen alle karmalen Sonderfertigkeiten; '
                    'gottheitsgebundene bleiben dann zu prüfen.'
              : 'Es erscheinen allgemeine und zu $aktuell passende karmale '
                    'Sonderfertigkeiten.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
