import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Filtergruppen fuer das Wuerfelprotokoll.
///
/// Fasst die feingranularen [ProbeType]-Werte zu spielrelevanten Gruppen
/// zusammen, damit die Chip-Leiste kompakt bleibt.
enum DiceLogFilter {
  /// Alle Eintraege ohne Einschraenkung.
  all('Alle'),

  /// Eigenschaftsproben (1W20).
  attribute('Eigenschaft'),

  /// Talentproben (3W20).
  talent('Talent'),

  /// Zauberproben (3W20).
  spell('Zauber'),

  /// Kampfbezogene Wuerfe (AT, PA, Ausweichen, INI, Schaden).
  combat('Kampf');

  const DiceLogFilter(this.label);

  /// Anzeigename des Filters auf dem Chip.
  final String label;

  /// Prueft, ob ein Protokolleintrag zur Filtergruppe gehoert.
  bool matches(DiceLogEntry entry) {
    switch (this) {
      case DiceLogFilter.all:
        return true;
      case DiceLogFilter.attribute:
        return entry.type == ProbeType.attribute;
      case DiceLogFilter.talent:
        return entry.type == ProbeType.talent;
      case DiceLogFilter.spell:
        return entry.type == ProbeType.spell;
      case DiceLogFilter.combat:
        return entry.type == ProbeType.combatAttack ||
            entry.type == ProbeType.combatParry ||
            entry.type == ProbeType.dodge ||
            entry.type == ProbeType.initiative ||
            entry.type == ProbeType.damage;
    }
  }
}

/// Liste der zuletzt protokollierten Wuerfelproben mit Filter-Chips.
///
/// Erwartet die Eintraege in chronologischer Reihenfolge (aelteste zuerst,
/// neueste am Ende der Liste – wie sie der `HeroState.diceLog` haelt).
/// Die Anzeige dreht das intern um, damit der neueste Eintrag oben steht.
class InspectorDiceLogSection extends StatefulWidget {
  /// Erzeugt die Protokoll-Sektion fuer die uebergebenen Eintraege.
  const InspectorDiceLogSection({super.key, required this.entries});

  /// Protokolleintraege in chronologischer Reihenfolge.
  final List<DiceLogEntry> entries;

  @override
  State<InspectorDiceLogSection> createState() =>
      _InspectorDiceLogSectionState();
}

class _InspectorDiceLogSectionState extends State<InspectorDiceLogSection> {
  DiceLogFilter _filter = DiceLogFilter.all;

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
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

    final filtered = widget.entries
        .where(_filter.matches)
        .toList(growable: false);
    final reversed = filtered.reversed.toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilterChips(),
        const SizedBox(height: 8),
        if (reversed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Keine Würfe in dieser Kategorie.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        for (final entry in reversed) ...[
          _DiceLogEntryRow(entry: entry),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  /// Baut die Chip-Leiste zur Auswahl der Filtergruppe.
  Widget _buildFilterChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final filter in DiceLogFilter.values)
          ChoiceChip(
            key: ValueKey('dice-log-filter-${filter.name}'),
            label: Text(filter.label),
            visualDensity: VisualDensity.compact,
            selected: _filter == filter,
            onSelected: (_) => setState(() => _filter = filter),
          ),
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
