import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Liste der zuletzt protokollierten Wuerfelproben.
///
/// Erwartet die Eintraege in chronologischer Reihenfolge (aelteste zuerst,
/// neueste am Ende der Liste – wie sie der `HeroState.diceLog` haelt).
/// Die Anzeige dreht das intern um, damit der neueste Eintrag oben steht.
class InspectorDiceLogSection extends StatelessWidget {
  const InspectorDiceLogSection({super.key, required this.entries});

  final List<DiceLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Noch keine Würfe protokolliert.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final reversed = entries.reversed.toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in reversed) ...[
          _DiceLogEntryRow(entry: entry),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _DiceLogEntryRow extends StatelessWidget {
  const _DiceLogEntryRow({required this.entry});

  final DiceLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codex = context.codexTheme;
    final isSuccess = entry.success;
    final stripeColor = isSuccess ? codex.success : codex.danger;
    final outcomeLabel = entry.automaticOutcome == AutomaticOutcome.none
        ? (isSuccess ? 'GELUNGEN' : 'MISSLUNGEN')
        : (entry.automaticOutcome == AutomaticOutcome.success
              ? 'AUTO ✓'
              : 'AUTO ✗');
    final outcomeColor = isSuccess ? codex.success : codex.danger;
    final effectiveStripeColor = entry.isNeutral ? codex.brass : stripeColor;
    final effectiveOutcomeLabel = entry.isNeutral ? 'WURF' : outcomeLabel;
    final effectiveOutcomeColor = entry.isNeutral ? codex.brass : outcomeColor;
    final resultDetail = _buildResultDetail();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: codex.parchment,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: codex.brassMuted, width: 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: effectiveStripeColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.subtitle.isNotEmpty)
                      Text(
                        entry.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (resultDetail.isNotEmpty)
                      Text(
                        resultDetail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    effectiveOutcomeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: effectiveOutcomeColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    _formatTime(entry.timestamp.toLocal()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime ts) {
    final hh = ts.hour.toString().padLeft(2, '0');
    final mm = ts.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _buildResultDetail() {
    final parts = <String>[];
    if (entry.diceValues.isNotEmpty) {
      parts.add('Würfe: ${entry.diceValues.join(', ')}');
    }
    final target = entry.targetValue;
    if (target != null) {
      parts.add('Ziel: $target');
    }
    final total = entry.total;
    if (total != null) {
      parts.add('Gesamt: $total');
    }
    return parts.join(' | ');
  }
}
