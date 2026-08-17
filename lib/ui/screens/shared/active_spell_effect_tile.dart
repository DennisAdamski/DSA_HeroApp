import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_duration_rules.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/list_tile_material.dart';

/// Karte eines laufend aktivierbaren Zaubereffekts inklusive Wirkungsdauer.
///
/// Rein darstellend: Alle Aenderungen laufen ueber die Callbacks, damit die
/// Persistenz beim aufrufenden Dialog bleibt.
class ActiveSpellEffectTile extends StatelessWidget {
  /// Erstellt die Karte fuer genau einen Effekt.
  const ActiveSpellEffectTile({
    super.key,
    required this.effect,
    required this.isActive,
    required this.onToggled,
    required this.onEditDuration,
    required this.onAdvanceDuration,
    required this.onResetDuration,
    this.duration,
    this.valueText = '',
    this.onEditValue,
  });

  /// Definition des Effekts (Label, Beschreibung, Standard-Zeiteinheit).
  final ActiveSpellEffectDefinition effect;

  /// Ob der Effekt aktuell laeuft.
  final bool isActive;

  /// Erfasste Wirkungsdauer oder `null`.
  final SpellDuration? duration;

  /// Zusammenfassung der Effektwerte, z. B. `Zusätzlicher RS: 3`.
  final String valueText;

  /// Schaltet den Effekt an oder aus.
  final ValueChanged<bool> onToggled;

  /// Oeffnet die Eingabe der Wirkungsdauer.
  final VoidCallback onEditDuration;

  /// Zieht eine Zeiteinheit von der Restlaufzeit ab.
  final VoidCallback onAdvanceDuration;

  /// Setzt die Restlaufzeit auf die volle Wirkungsdauer zurueck.
  final VoidCallback onResetDuration;

  /// Oeffnet die effektspezifische Werteingabe; `null`, wenn es keine gibt.
  final VoidCallback? onEditValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDuration = duration != null && duration!.amount > 0;
    final canCountDown = hasDuration && !duration!.isPermanent && duration!.remaining > 0;
    final durationText = describeSpellDuration(duration);
    final isExpired = duration?.isExpired ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTileMaterial(
            child: SwitchListTile(
              key: ValueKey<String>('active-spell-toggle-${effect.id}'),
              title: Text(effect.label),
              subtitle: Text(effect.description),
              value: isActive,
              onChanged: onToggled,
            ),
          ),
          if (isActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (valueText.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            valueText,
                            key: ValueKey<String>(
                              'active-spell-value-${effect.id}',
                            ),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        if (onEditValue != null)
                          IconButton(
                            key: ValueKey<String>(
                              'active-spell-edit-value-${effect.id}',
                            ),
                            tooltip: 'Werte anpassen',
                            visualDensity: VisualDensity.compact,
                            onPressed: onEditValue,
                            icon: const Icon(Icons.tune, size: 18),
                          ),
                      ],
                    ),
                  Row(
                    children: [
                      Icon(
                        Icons.timelapse_outlined,
                        size: 16,
                        color: isExpired
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: kDialogInlineSpacing),
                      Expanded(
                        child: Text(
                          durationText,
                          key: ValueKey<String>(
                            'active-spell-duration-${effect.id}',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isExpired
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      IconButton(
                        key: ValueKey<String>(
                          'active-spell-duration-advance-${effect.id}',
                        ),
                        tooltip: 'Eine Zeiteinheit abziehen',
                        visualDensity: VisualDensity.compact,
                        onPressed: canCountDown ? onAdvanceDuration : null,
                        icon: const Icon(Icons.exposure_minus_1, size: 18),
                      ),
                      IconButton(
                        key: ValueKey<String>(
                          'active-spell-duration-reset-${effect.id}',
                        ),
                        tooltip: 'Wirkungsdauer zurücksetzen',
                        visualDensity: VisualDensity.compact,
                        onPressed: hasDuration ? onResetDuration : null,
                        icon: const Icon(Icons.restart_alt, size: 18),
                      ),
                      IconButton(
                        key: ValueKey<String>(
                          'active-spell-duration-edit-${effect.id}',
                        ),
                        tooltip: 'Wirkungsdauer festlegen',
                        visualDensity: VisualDensity.compact,
                        onPressed: onEditDuration,
                        icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
