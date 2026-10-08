import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/karto_variante.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';

/// Verdichtet Wertziele zu lesbaren Kacheln mit unmittelbar zugehörigen Aktionen.
class AdvancementValueTile extends StatelessWidget {
  /// Verwendet ausschließlich bereits aufgelöste Werte und Erwerbsprüfungen.
  const AdvancementValueTile({
    super.key,
    required this.option,
    required this.planned,
    required this.onPlan,
    this.specialization,
    this.specializations = const [],
    this.onSpecialize,
  });

  /// Regeloption für den numerischen Wert.
  final AdvancementOption option;

  /// Kennzeichnet Ziele mit vorgemerkten Änderungen.
  final bool planned;

  /// Öffnet den Steigerungsdialog.
  final VoidCallback? onPlan;

  /// Separate Erwerbsprüfung, damit ein erreichtes Maximum nicht den Erwerb sperrt.
  final AdvancementOption? specialization;

  /// Bereits gelernte oder in der Vorschau erworbene Spezialisierungen.
  final List<String> specializations;

  /// Öffnet den Spezialisierungserwerb.
  final VoidCallback? onSpecialize;

  /// Zeigt Wert, Grenzen und getrennt freigegebene Aktionen ohne Regelrechnung.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = option.unavailableReason == null ? onPlan : null;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(option.label, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(width: 8),
            Text(
              '${option.currentValue < 0 ? '–' : option.currentValue}',
              style: theme.textTheme.headlineSmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              'Maximum ${option.maxValue}',
              style: theme.textTheme.bodySmall,
            ),
            Text('SE ${option.seAvailable}', style: theme.textTheme.bodySmall),
            if (planned)
              Text(
                'Geplant',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
        if (option.complexityHint?.isNotEmpty == true)
          Text(option.complexityHint!, style: theme.textTheme.bodySmall),
        if (specializations.isNotEmpty)
          Text(
            'Spezialisierungen: ${specializations.join(', ')}',
            style: theme.textTheme.bodySmall,
          ),
        if (option.unavailableReason != null)
          Text(option.unavailableReason!, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton(
              key: ValueKey(
                'advancement-plan-${option.kind.name}-${option.targetId}',
              ),
              onPressed: enabled,
              child: Text(option.currentValue < 0 ? 'Aktivieren' : 'Steigern'),
            ),
            if (specialization != null)
              Tooltip(
                message:
                    specialization!.unavailableReason ??
                    specialization!.complexityHint ??
                    '',
                child: OutlinedButton(
                  key: ValueKey('advancement-specialize-${option.targetId}'),
                  onPressed: specialization!.unavailableReason == null
                      ? onSpecialize
                      : null,
                  child: const Text('+ Spezialisierung'),
                ),
              ),
          ],
        ),
        if (specialization?.unavailableReason != null)
          Text(
            specialization!.unavailableReason!,
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
    if (kartoVariante(context) != null) {
      return KartoFlaeche(innen: const EdgeInsets.all(12), child: content);
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(12), child: content),
    );
  }
}
