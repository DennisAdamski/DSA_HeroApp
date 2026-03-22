import 'package:flutter/material.dart';

/// Dekorativer Container fuer dichte Datentabellen im Codex-Stil.
class CodexDataTable extends StatelessWidget {
  /// Erstellt einen Codex-Rahmen fuer eine bestehende Tabelle.
  const CodexDataTable({super.key, required this.header, required this.table});

  /// Kurze Tabellenueberschrift.
  final String header;

  /// Tabelleninhalt.
  final Widget table;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(header, style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            table,
          ],
        ),
      ),
    );
  }
}
