import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/adaptive_table_columns.dart';

/// Übergibt aktuelle Nutzerbreiten und Änderungsaktionen an Tabellen-Widgets.
@immutable
class TableColumnResizeBinding {
  /// Erzeugt eine Bindung für genau eine stabile Tabellen-ID.
  const TableColumnResizeBinding({
    required this.tableId,
    required this.widths,
    required this.updateWidth,
    required this.commitWidth,
    required this.resetWidths,
  });

  /// Stabile ID der gebundenen Tabelle.
  final String tableId;

  /// Aktuelle Inhaltsbreiten nach stabiler Spalten-ID.
  final Map<String, double> widths;

  /// Aktualisiert eine Breite ausschließlich im lokalen Drag-Zustand.
  final void Function(String columnId, double width) updateWidth;

  /// Persistiert die zuletzt lokal gesetzte Breite einer Spalte.
  final Future<void> Function(String columnId) commitWidth;

  /// Entfernt alle gespeicherten Breiten der gebundenen Tabelle.
  final Future<void> Function() resetWidths;
}

// Teilt den flüchtigen Drag-Zustand zwischen mehreren sichtbaren Instanzen
// desselben Tabellenprofils, etwa den allgemeinen Talentgruppen.
class _TableTransientWidths extends Notifier<Map<String, double>> {
  _TableTransientWidths(String tableId);

  @override
  Map<String, double> build() => const <String, double>{};

  void setWidth(String columnId, double width) {
    state = Map<String, double>.unmodifiable(<String, double>{
      ...state,
      columnId: width,
    });
  }

  void replace(Map<String, double> widths) {
    state = Map<String, double>.unmodifiable(widths);
  }

  void clear() {
    state = const <String, double>{};
  }
}

final _tableTransientWidthsProvider =
    NotifierProvider.family<_TableTransientWidths, Map<String, double>, String>(
      _TableTransientWidths.new,
    );

/// Umhüllt die verstellbaren Zellen einer Table-Kopfzeile mit Resize-Griffen.
List<Widget> buildResizableTableHeaderCells({
  required List<Widget> cells,
  required List<AdaptiveTableColumnSpec> specs,
  required List<double> resolvedWidths,
  required TableColumnResizeBinding resizeBinding,
}) {
  assert(cells.length == specs.length);
  assert(resolvedWidths.length == specs.length);
  return <Widget>[
    for (var i = 0; i < cells.length; i++)
      if (specs[i].resizable)
        ResizableTableHeaderCell(
          spec: specs[i],
          currentWidth: resolvedWidths[i],
          resizeBinding: resizeBinding,
          child: cells[i],
        )
      else
        cells[i],
  ];
}

/// Baut DataTable-Spalten und ergänzt Griffe an verstellbaren Kopfzellen.
List<DataColumn> buildResizableDataColumns({
  required AdaptiveDataTableLayout layout,
  required TableColumnResizeBinding resizeBinding,
}) {
  return <DataColumn>[
    for (var i = 0; i < layout.specs.length; i++)
      if (layout.specs[i].width.resizable)
        layout.specs[i].toDataColumn(
          resolvedWidth: layout.widthFor(i),
          labelOverride: ResizableTableHeaderCell(
            spec: layout.specs[i].width,
            currentWidth: layout.contentWidthFor(i),
            resizeBinding: resizeBinding,
            child: layout.specs[i].label,
          ),
        )
      else
        layout.specs[i].toDataColumn(resolvedWidth: layout.widthFor(i)),
  ];
}

/// Bindet eine Tabelle an dauerhaft gespeicherte lokale Spaltenbreiten.
class PersistedTableColumnLayout extends ConsumerStatefulWidget {
  /// Erzeugt einen persistierten Layout-Bereich für eine Tabelle.
  const PersistedTableColumnLayout({
    super.key,
    required this.tableId,
    required this.builder,
  });

  /// Stabile Tabellen-ID innerhalb der App-Einstellungen.
  final String tableId;

  /// Baut die eigentliche Tabelle mit ihrer Resize-Bindung.
  final Widget Function(BuildContext context, TableColumnResizeBinding binding)
  builder;

  @override
  ConsumerState<PersistedTableColumnLayout> createState() {
    return _PersistedTableColumnLayoutState();
  }
}

class _PersistedTableColumnLayoutState
    extends ConsumerState<PersistedTableColumnLayout> {
  void _updateWidth(String columnId, double width) {
    ref
        .read(_tableTransientWidthsProvider(widget.tableId).notifier)
        .setWidth(columnId, width);
  }

  Future<void> _commitWidth(String columnId) async {
    final width = ref.read(
      _tableTransientWidthsProvider(widget.tableId),
    )[columnId];
    if (width == null) {
      return;
    }
    try {
      await ref
          .read(settingsActionsProvider)
          .setTableColumnWidth(widget.tableId, columnId, width);
    } on Object {
      _showPersistenceError();
    }
  }

  Future<void> _resetWidths() async {
    final transientProvider = _tableTransientWidthsProvider(widget.tableId);
    final previousWidths = ref.read(transientProvider);
    ref.read(transientProvider.notifier).clear();
    try {
      await ref
          .read(settingsActionsProvider)
          .resetTableColumnWidths(widget.tableId);
    } on Object {
      ref.read(transientProvider.notifier).replace(previousWidths);
      _showPersistenceError();
    }
  }

  void _showPersistenceError() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Spaltenbreite konnte nicht gespeichert werden.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final persistedWidths = settings?.tableColumnWidths[widget.tableId];
    final transientWidths = ref.watch(
      _tableTransientWidthsProvider(widget.tableId),
    );
    final effectiveWidths = <String, double>{
      ...?persistedWidths,
      ...transientWidths,
    };
    final binding = TableColumnResizeBinding(
      tableId: widget.tableId,
      widths: Map<String, double>.unmodifiable(effectiveWidths),
      updateWidth: _updateWidth,
      commitWidth: _commitWidth,
      resetWidths: _resetWidths,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (effectiveWidths.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: ValueKey<String>('table-column-reset-${widget.tableId}'),
              onPressed: () => unawaited(_resetWidths()),
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Spalten zurücksetzen'),
            ),
          ),
        widget.builder(context, binding),
      ],
    );
  }
}

/// Tabellenkopf mit einem 24 Pixel breiten Maus- und Touch-Resize-Griff.
class ResizableTableHeaderCell extends StatefulWidget {
  /// Erzeugt einen Header-Griff für eine als verstellbar markierte Spalte.
  const ResizableTableHeaderCell({
    super.key,
    required this.spec,
    required this.currentWidth,
    required this.resizeBinding,
    required this.child,
  });

  /// Breitenregeln und stabile ID der Spalte.
  final AdaptiveTableColumnSpec spec;

  /// Aktuell sichtbare Inhaltsbreite der Spalte.
  final double currentWidth;

  /// Empfänger für lokale und persistente Breitenänderungen.
  final TableColumnResizeBinding resizeBinding;

  /// Sichtbarer Spaltentitel.
  final Widget child;

  @override
  State<ResizableTableHeaderCell> createState() {
    return _ResizableTableHeaderCellState();
  }
}

class _ResizableTableHeaderCellState extends State<ResizableTableHeaderCell> {
  static const double _handleWidth = 24;

  bool _hovering = false;
  bool _dragging = false;
  bool _didDrag = false;
  late double _dragWidth;

  @override
  void initState() {
    super.initState();
    _dragWidth = widget.currentWidth;
  }

  @override
  void didUpdateWidget(covariant ResizableTableHeaderCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging) {
      _dragWidth = widget.currentWidth;
    }
  }

  void _startDrag(DragStartDetails details) {
    setState(() {
      _dragging = true;
      _didDrag = false;
      _dragWidth = widget.currentWidth;
    });
  }

  void _updateDrag(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    final nextWidth = (_dragWidth + delta)
        .clamp(widget.spec.lowerBound, widget.spec.resizeUpperBound)
        .toDouble();
    setState(() {
      _didDrag = true;
      _dragWidth = nextWidth;
    });
    final columnId = widget.spec.columnId!;
    widget.resizeBinding.updateWidth(columnId, nextWidth);
  }

  void _endDrag(DragEndDetails details) {
    final columnId = widget.spec.columnId!;
    final shouldCommit = _didDrag;
    setState(() {
      _dragging = false;
      _didDrag = false;
    });
    if (shouldCommit) {
      unawaited(widget.resizeBinding.commitWidth(columnId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.spec.resizable || widget.spec.columnId == null) {
      return widget.child;
    }
    final theme = Theme.of(context);
    final active = _hovering || _dragging;
    final dividerColor = active
        ? theme.colorScheme.primary
        : theme.dividerColor;
    final columnId = widget.spec.columnId!;

    return Stack(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: _handleWidth / 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: widget.child,
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: _handleWidth,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            child: Semantics(
              label: 'Spaltenbreite ändern',
              child: GestureDetector(
                key: ValueKey<String>(
                  'table-column-resize-'
                  '${widget.resizeBinding.tableId}-$columnId',
                ),
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _startDrag,
                onHorizontalDragUpdate: _updateDrag,
                onHorizontalDragEnd: _endDrag,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: active ? 2 : 1,
                    color: dividerColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
