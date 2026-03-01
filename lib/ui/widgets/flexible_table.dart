import 'package:flutter/material.dart';

class FlexibleTableRow {
  const FlexibleTableRow({required this.cells, this.backgroundColor, this.key});

  final List<Widget> cells;
  final Color? backgroundColor;
  final LocalKey? key;
}

class FlexibleTable extends StatelessWidget {
  const FlexibleTable({
    super.key,
    required this.headerCells,
    required this.rows,
    this.preHeaderRows = const <List<Widget>>[],
    this.tableKey,
    this.minChars = 3,
    this.horizontalPadding = const EdgeInsets.fromLTRB(6, 4, 6, 6),
  });

  final List<Widget> headerCells;
  final List<FlexibleTableRow> rows;
  final List<List<Widget>> preHeaderRows;
  final Key? tableKey;
  final int minChars;
  final EdgeInsets horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final minWidth = (minChars <= 0 ? 3 : minChars) * 12.0;
    final allRows = <TableRow>[
      ...preHeaderRows.map(
        (cells) => _buildRow(cells: cells, minWidth: minWidth),
      ),
      _buildRow(cells: headerCells, minWidth: minWidth, isHeader: true),
      ...rows.map(
        (row) => _buildRow(
          key: row.key,
          cells: row.cells,
          minWidth: minWidth,
          backgroundColor: row.backgroundColor,
        ),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        key: tableKey,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: allRows,
      ),
    );
  }

  TableRow _buildRow({
    LocalKey? key,
    required List<Widget> cells,
    required double minWidth,
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
              padding: horizontalPadding,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minWidth),
                child: isHeader
                    ? DefaultTextStyle.merge(
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        child: cell,
                      )
                    : cell,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

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
