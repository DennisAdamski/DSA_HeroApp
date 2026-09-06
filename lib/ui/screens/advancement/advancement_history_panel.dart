import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Zeigt AP-Vorschau, bearbeitbare Sitzung und unveränderliche frühere Historie.
class AdvancementHistoryPanel extends ConsumerWidget {
  /// Erstellt die Sitzungsübersicht für Seitenleiste oder mobiles Detailpanel.
  const AdvancementHistoryPanel({super.key, required this.heroId});

  /// Held der aktuell geplanten Runde.
  final String heroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(advancementSessionProvider(heroId));
    if (session == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final codex = context.codexTheme;
    final oldEntries = session.base.advancementHistory.reversed;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: codex.heroGradientSoft),
      child: ListView(
        key: const ValueKey('advancement-history'),
        padding: const EdgeInsets.all(14),
        children: [
          Text('Steigerungsmodus', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'Erst beim Übernehmen werden Werte, AP und Sondererfahrungen gespeichert.',
          ),
          const SizedBox(height: 16),
          _ApRow(label: 'Frei zu Beginn', value: session.base.apAvailable),
          _ApRow(label: 'Reserviert', value: session.apReserved),
          _ApRow(
            label: 'Danach verfügbar',
            value: session.preview.apAvailable,
            emphasized: true,
          ),
          const Divider(height: 28),
          Text('Laufende Runde', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          if (session.entries.isEmpty)
            const Text('Noch keine Steigerungen geplant.'),
          if (session.errors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Einige Einträge sind nach einer Änderung nicht mehr gültig. '
                'Bitte entferne sie und plane sie bei Bedarf erneut. '
                'Sie reservieren keine AP; Übernehmen ist solange gesperrt.',
                style: TextStyle(color: codex.danger),
              ),
            ),
          for (final entry in session.entries.reversed)
            _HistoryEntry(
              entry: entry,
              error: session.errors[entry.id],
              removable: true,
              onRemove: session.isSaving
                  ? null
                  : () {
                      ref
                          .read(advancementSessionProvider(heroId).notifier)
                          .remove(entry.id);
                    },
            ),
          const Divider(height: 28),
          Text('Bereits übernommen', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text('Frühere Runden sind abgeschlossen und nicht löschbar.'),
          const SizedBox(height: 8),
          if (oldEntries.isEmpty)
            const Text('Noch keine übernommene Steigerungshistorie vorhanden.'),
          for (final entry in oldEntries)
            _HistoryEntry(entry: entry, removable: false),
        ],
      ),
    );
  }
}

/// Hält AP-Beschriftung und Zahl auch in der schmalen Seitenleiste lesbar.
class _ApRow extends StatelessWidget {
  const _ApRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final int value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized ? Theme.of(context).textTheme.titleSmall : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 8),
          Text('$value AP', style: style),
        ],
      ),
    );
  }
}

/// Markiert verbindliche Einträge mit Schloss und laufende mit Entfernen-Aktion.
class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({
    required this.entry,
    required this.removable,
    this.error,
    this.onRemove,
  });

  final HeroAdvancementEntry entry;
  final bool removable;
  final String? error;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localDate = entry.createdAt.toLocal();
    final dateLabel = MaterialLocalizations.of(context)
        .formatShortDate(localDate);
    final timeLabel = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(localDate),
      alwaysUse24HourFormat: true,
    );
    final previous = entry.fromValue;
    final next = entry.toValue;
    final change = next == null
        ? 'Erwerb'
        : previous == null || previous < 0
        ? 'Aktivierung → $next'
        : '$previous → $next';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(entry.label, style: theme.textTheme.titleSmall),
                ),
                if (removable)
                  IconButton(
                    key: ValueKey('advancement-remove-${entry.id}'),
                    tooltip: 'Geplante Steigerung entfernen',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, size: 18),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Tooltip(
                      message: 'Bereits übernommen',
                      child: Icon(Icons.lock_outline, size: 18),
                    ),
                  ),
              ],
            ),
            Text('$change · ${entry.apCost} AP'),
            if (entry.seSpent > 0) Text('${entry.seSpent} Sondererfahrung(en)'),
            if (entry.options['meisterentscheid'] == 'true')
              const Text('Mit Meisterentscheid'),
            Text('$dateLabel · $timeLabel', style: theme.textTheme.bodySmall),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  error!,
                  style: TextStyle(color: context.codexTheme.danger),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
