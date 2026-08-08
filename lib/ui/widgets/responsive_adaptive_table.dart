import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/adaptive_table_columns.dart';

/// Tabelle, die sich auf zu schmalen Bildschirmen automatisch in eine
/// Karten-Liste umschaltet.
///
/// Solange `constraints.maxWidth` die Mindestbreite aller Spalten
/// ([adaptiveTableMinWidth]) deckt, wird die klassische Tabelle gerendert.
/// Andernfalls werden die [items] als mehrzeilige Karten dargestellt, die
/// jeweils durch [cardBuilder] gebaut werden.
///
/// Mit [ansicht] laesst sich diese Automatik ueberstimmen. Bei
/// [TabellenAnsicht.tabelle] bleibt die Tabelle auch auf schmalen Geraeten
/// bestehen und wird horizontal scrollbar. Das Widget bleibt bewusst
/// Riverpod-frei; den Wert liefert der Aufrufer.
class ResponsiveAdaptiveTable<T> extends StatelessWidget {
  const ResponsiveAdaptiveTable({
    super.key,
    required this.columnSpecs,
    required this.headerRow,
    required this.items,
    required this.tableRowBuilder,
    required this.cardBuilder,
    this.tableVerticalAlignment = TableCellVerticalAlignment.middle,
    this.cardSpacing = 8,
    this.ansicht = TabellenAnsicht.automatisch,
  });

  final List<AdaptiveTableColumnSpec> columnSpecs;
  final TableRow headerRow;
  final List<T> items;
  final TableRow Function(T item) tableRowBuilder;
  final Widget Function(BuildContext context, T item) cardBuilder;
  final TableCellVerticalAlignment tableVerticalAlignment;
  final double cardSpacing;

  /// Erzwingt Tabelle oder Karten; Standard ist die Breiten-Automatik.
  final TabellenAnsicht ansicht;

  @override
  Widget build(BuildContext context) {
    if (ansicht == TabellenAnsicht.karten) {
      return _buildCardList(context);
    }
    final minWidth = adaptiveTableMinWidth(columnSpecs);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final isTooNarrow = available.isFinite && available < minWidth;
        final useCards =
            isTooNarrow && ansicht == TabellenAnsicht.automatisch;
        if (useCards) {
          return _buildCardList(context);
        }
        return _buildTable(context, available);
      },
    );
  }

  Widget _buildTable(BuildContext context, double availableWidth) {
    final layout = resolveAdaptiveTableLayout(
      columnSpecs,
      availableWidth: availableWidth,
    );
    final rows = <TableRow>[headerRow, ...items.map(tableRowBuilder)];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: layout.tableWidth,
        child: Table(
          defaultVerticalAlignment: tableVerticalAlignment,
          columnWidths: layout.toColumnWidthMap(),
          children: rows,
        ),
      ),
    );
  }

  Widget _buildCardList(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(SizedBox(height: cardSpacing));
      }
      children.add(cardBuilder(context, items[i]));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
