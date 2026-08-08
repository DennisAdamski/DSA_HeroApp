import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/sync_object_diff.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/sync_conflict_field_labels.dart';

/// Maximale Anzahl direkt gerenderter Diff-Zeilen pro Konflikt.
const int _maxVisibleRows = 50;

/// Platzhalter fuer ein Feld, das auf einer Seite gar nicht existiert.
///
/// Bewusst anders als das `—` aus [formatSyncDiffValue], damit ein fehlendes
/// Feld nicht wie ein gesetzter `null`-Wert aussieht.
const String _absentValue = '(nicht vorhanden)';

/// Stellt einen Sync-Konflikt als Vergleichstabelle `Feld | Online | Lokal` dar.
///
/// Die Zusammenfassung (Name, Zeitstempel, AP) bildet die stets sichtbaren
/// ersten Zeilen; die einzelnen Feldunterschiede lassen sich darunter
/// ein- und ausklappen. Beides liegt in derselben [Table], damit die Spalten
/// ueber alle Zeilen hinweg buendig bleiben.
class SyncConflictComparisonTable extends StatefulWidget {
  /// Erstellt die Vergleichstabelle fuer [conflict].
  const SyncConflictComparisonTable({
    super.key,
    required this.conflict,
    this.diff,
  });

  /// Offener Konflikt mit den Zusammenfassungswerten beider Seiten.
  final SyncConflict conflict;

  /// Feld-Diff des Konflikts oder `null`, wenn keine Volldaten vorliegen.
  final SyncObjectDiff? diff;

  @override
  State<SyncConflictComparisonTable> createState() =>
      _SyncConflictComparisonTableState();
}

class _SyncConflictComparisonTableState
    extends State<SyncConflictComparisonTable> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diff = widget.diff;
    final visibleEntries = diff == null
        ? const <SyncDiffEntry>[]
        : diff.entries.take(_maxVisibleRows).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Table(
          columnWidths: const <int, TableColumnWidth>{
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(3),
            2: FlexColumnWidth(3),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          children: [
            _headerRow(theme),
            ..._summaryRows(theme),
            if (_expanded)
              for (final entry in visibleEntries) _diffRow(theme, entry),
          ],
        ),
        ..._footerWidgets(theme, diff, visibleEntries.length),
      ],
    );
  }

  TableRow _headerRow(ThemeData theme) {
    final style = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      children: [
        _cell(Text('Feld', style: style)),
        _cell(Text('Online', style: style)),
        _cell(Text('Lokal', style: style)),
      ],
    );
  }

  /// Immer sichtbare Kopfzeilen mit den Eckdaten beider Versionen.
  List<TableRow> _summaryRows(ThemeData theme) {
    final conflict = widget.conflict;
    return [
      _valueRow(theme, 'Name', conflict.remoteSummary, conflict.localSummary),
      _valueRow(
        theme,
        'Gespeichert',
        _formatTimestamp(conflict.remoteUpdatedAt),
        _formatTimestamp(conflict.localUpdatedAt),
      ),
      if (conflict.remoteApTotal != null || conflict.localApTotal != null)
        _valueRow(
          theme,
          'AP gesamt',
          _formatCount(conflict.remoteApTotal),
          _formatCount(conflict.localApTotal),
        ),
      if (conflict.remoteApAvailable != null ||
          conflict.localApAvailable != null)
        _valueRow(
          theme,
          'AP frei',
          _formatCount(conflict.remoteApAvailable),
          _formatCount(conflict.localApAvailable),
        ),
    ];
  }

  TableRow _diffRow(ThemeData theme, SyncDiffEntry entry) {
    final String online;
    final String lokal;
    switch (entry.kind) {
      case SyncDiffKind.changed:
        online = formatSyncDiffValue(entry.remoteValue);
        lokal = formatSyncDiffValue(entry.localValue);
      case SyncDiffKind.onlyLocal:
        online = _absentValue;
        lokal = formatSyncDiffValue(entry.localValue);
      case SyncDiffKind.onlyRemote:
        online = formatSyncDiffValue(entry.remoteValue);
        lokal = _absentValue;
    }
    return _valueRow(theme, labelForSyncDiffPath(entry.path), online, lokal);
  }

  TableRow _valueRow(
    ThemeData theme,
    String label,
    String online,
    String lokal,
  ) {
    final labelStyle = theme.textTheme.bodySmall;
    final valueStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return TableRow(
      children: [
        _cell(Text(label, style: labelStyle)),
        _cell(Text(online, style: valueStyle)),
        _cell(Text(lokal, style: valueStyle)),
      ],
    );
  }

  /// Umschalter und Hinweiszeilen unterhalb der Tabelle.
  List<Widget> _footerWidgets(
    ThemeData theme,
    SyncObjectDiff? diff,
    int visibleCount,
  ) {
    if (diff == null) {
      return const <Widget>[];
    }
    if (diff.remoteMissing) {
      return [
        _note(
          theme,
          'Die Online-Version wurde gelöscht – kein Feldvergleich möglich.',
          isError: true,
        ),
      ];
    }
    if (diff.localMissing) {
      return [
        _note(
          theme,
          'Keine lokale Version vorhanden – kein Feldvergleich möglich.',
          isError: true,
        ),
      ];
    }
    if (diff.entries.isEmpty) {
      return [_note(theme, 'Beide Versionen sind inhaltlich identisch.')];
    }

    final hiddenCount = diff.entries.length - visibleCount;
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _expanded = !_expanded),
          icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
          label: Text(
            _expanded
                ? 'Unterschiede ausblenden'
                : 'Unterschiede anzeigen (${diff.entries.length})',
          ),
        ),
      ),
      if (_expanded && (hiddenCount > 0 || diff.truncated))
        _note(
          theme,
          diff.truncated
              ? '… weitere Unterschiede nicht erfasst'
              : '… und $hiddenCount weitere Unterschiede',
        ),
    ];
  }

  Widget _note(ThemeData theme, String text, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isError ? theme.colorScheme.error : null,
          ),
        ),
      ),
    );
  }

  Widget _cell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: child,
    );
  }

  static String _formatCount(int? value) => value == null ? '—' : '$value';

  static String _formatTimestamp(DateTime? value) {
    if (value == null) {
      return 'Unbekannt';
    }
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
