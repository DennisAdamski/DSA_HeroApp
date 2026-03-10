import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/widgets/adaptive_table_columns.dart';

/// Beschreibt eine einzelne Zeile fuer [FlexibleTable].
class FlexibleTableRow {
  const FlexibleTableRow({required this.cells, this.backgroundColor, this.key});

  final List<Widget> cells;
  final Color? backgroundColor;
  final LocalKey? key;
}

/// Horizontale Tabelle mit optional adaptiven Spaltenbreiten.
class FlexibleTable extends StatefulWidget {
  const FlexibleTable({
    super.key,
    required this.headerCells,
    required this.rows,
    this.preHeaderRows = const <List<Widget>>[],
    this.tableKey,
    this.minChars = 3,
    this.columnSpecs,
    this.horizontalPadding = const EdgeInsets.fromLTRB(6, 4, 6, 6),
  }) : assert(
         columnSpecs == null || columnSpecs.length == headerCells.length,
         'columnSpecs must match headerCells length',
       );

  final List<Widget> headerCells;
  final List<FlexibleTableRow> rows;
  final List<List<Widget>> preHeaderRows;
  final Key? tableKey;
  final int minChars;
  final List<AdaptiveTableColumnSpec>? columnSpecs;
  final EdgeInsets horizontalPadding;

  @override
  State<FlexibleTable> createState() => _FlexibleTableState();
}

class _FlexibleTableState extends State<FlexibleTable> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicator);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollIndicator();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollIndicator);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollIndicator() {
    if (!_scrollController.hasClients) return;
    final canScroll =
        _scrollController.position.maxScrollExtent >
        _scrollController.position.pixels + 1;
    if (canScroll != _canScrollRight) {
      setState(() {
        _canScrollRight = canScroll;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final minWidth = (widget.minChars <= 0 ? 3 : widget.minChars) * 12.0;
    final useLegacyCellMinWidth = widget.columnSpecs == null;
    final allRows = <TableRow>[
      ...widget.preHeaderRows.map(
        (cells) => _buildRow(
          cells: cells,
          minWidth: minWidth,
          useLegacyCellMinWidth: useLegacyCellMinWidth,
        ),
      ),
      _buildRow(
        cells: widget.headerCells,
        minWidth: minWidth,
        isHeader: true,
        useLegacyCellMinWidth: useLegacyCellMinWidth,
      ),
      ...widget.rows.map(
        (row) => _buildRow(
          key: row.key,
          cells: row.cells,
          minWidth: minWidth,
          useLegacyCellMinWidth: useLegacyCellMinWidth,
          backgroundColor: row.backgroundColor,
        ),
      ),
    ];
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _updateScrollIndicator();
            return false;
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final responsiveLayout =
                  widget.columnSpecs == null || !constraints.maxWidth.isFinite
                  ? null
                  : resolveAdaptiveTableLayout(
                      widget.columnSpecs!,
                      availableWidth: constraints.maxWidth,
                    );
              final columnWidths = widget.columnSpecs == null
                  ? null
                  : (responsiveLayout?.toColumnWidthMap() ??
                        buildAdaptiveTableColumnWidths(widget.columnSpecs!));

              return SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Table(
                  key: widget.tableKey,
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: columnWidths,
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  children: allRows,
                ),
              );
            },
          ),
        ),
        if (_canScrollRight)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 24,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Theme.of(context).scaffoldBackgroundColor.withAlpha(0),
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  TableRow _buildRow({
    LocalKey? key,
    required List<Widget> cells,
    required double minWidth,
    required bool useLegacyCellMinWidth,
    bool isHeader = false,
    Color? backgroundColor,
  }) {
    return TableRow(
      key: key,
      decoration: backgroundColor == null
          ? null
          : BoxDecoration(color: backgroundColor),
      children: cells
          .map(
            (cell) => Padding(
              padding: widget.horizontalPadding,
              child: useLegacyCellMinWidth
                  ? ConstrainedBox(
                      constraints: BoxConstraints(minWidth: minWidth),
                      child: isHeader
                          ? DefaultTextStyle.merge(
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              child: cell,
                            )
                          : cell,
                    )
                  : (isHeader
                        ? DefaultTextStyle.merge(
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            child: cell,
                          )
                        : cell),
            ),
          )
          .toList(growable: false),
    );
  }
}

/// Textfeld fuer [FlexibleTable], das Aenderungen beim Verlassen commitet.
class FlexibleTableCommitField extends StatefulWidget {
  const FlexibleTableCommitField({
    super.key,
    required this.value,
    required this.onCommit,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.textAlign = TextAlign.left,
  });

  final String value;
  final ValueChanged<String> onCommit;
  final TextInputType keyboardType;
  final bool enabled;
  final TextAlign textAlign;

  @override
  State<FlexibleTableCommitField> createState() =>
      _FlexibleTableCommitFieldState();
}

class _FlexibleTableCommitFieldState extends State<FlexibleTableCommitField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant FlexibleTableCommitField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode.hasFocus) {
      return;
    }
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _commitIfChanged();
    }
  }

  void _commitIfChanged() {
    final next = _controller.text;
    if (next == widget.value) {
      return;
    }
    widget.onCommit(next);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      keyboardType: widget.keyboardType,
      textAlign: widget.textAlign,
      maxLines: 1,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onSubmitted: (_) => _commitIfChanged(),
      onTapOutside: (_) {
        _commitIfChanged();
        _focusNode.unfocus();
      },
    );
  }
}
