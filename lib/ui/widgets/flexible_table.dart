import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/adaptive_table_columns.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/karto_variante.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/resizable_table_columns.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Beschreibt eine einzelne Zeile fuer [FlexibleTable].
class FlexibleTableRow {
  const FlexibleTableRow({required this.cells, this.backgroundColor, this.key});

  final List<Widget> cells;
  final Color? backgroundColor;
  final LocalKey? key;
}

/// Horizontale Tabelle mit optional adaptiven Spaltenbreiten.
///
/// Unter Kartograph ([kartoVariante]) ohne getoenten Kasten: eine Haarlinie
/// rahmt die Tabelle, der Kopf liegt auf `senke` in der Etikettschrift, und
/// Haarlinien trennen die Zeilen. Spalten aus [numerischeSpalten] stehen dort
/// rechtsbuendig mit Tabellenziffern, damit Zahlen untereinander stehen.
class FlexibleTable extends StatefulWidget {
  const FlexibleTable({
    super.key,
    required this.headerCells,
    required this.rows,
    this.preHeaderRows = const <List<Widget>>[],
    this.tableKey,
    this.minChars = 3,
    this.columnSpecs,
    this.columnResize,
    this.horizontalPadding = const EdgeInsets.fromLTRB(6, 4, 6, 6),
    this.numerischeSpalten = const <int>{},
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

  /// Optionale Nutzerbreiten und Resize-Aktionen für adaptive Spalten.
  final TableColumnResizeBinding? columnResize;
  final EdgeInsets horizontalPadding;

  /// Spaltenindizes mit Zahlen; nur unter Kartograph rechtsbuendig gesetzt.
  final Set<int> numerischeSpalten;

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
    final codex = context.codexTheme;
    final karto = kartoVariante(context);
    final minWidth = (widget.minChars <= 0 ? 3 : widget.minChars) * 12.0;
    final useLegacyCellMinWidth = widget.columnSpecs == null;
    final zeilenzahl = widget.rows.length;
    return Container(
      decoration: karto == null
          ? BoxDecoration(
              color: codex.panelRaised.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(codex.panelRadius),
              border: Border.all(color: codex.rule),
            )
          : BoxDecoration(
              borderRadius: BorderRadius.circular(kKartoRadius),
              border: Border.all(
                color: karto.hoehenlinie,
                width: Strich.hoehenlinie,
              ),
            ),
      clipBehavior: karto == null ? Clip.none : Clip.antiAlias,
      child: Stack(
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
                        userWidths:
                            widget.columnResize?.widths ??
                            const <String, double>{},
                      );
                final columnWidths = widget.columnSpecs == null
                    ? null
                    : (responsiveLayout?.toColumnWidthMap() ??
                          buildAdaptiveTableColumnWidths(widget.columnSpecs!));
                final tableWidth =
                    responsiveLayout?.tableWidth ?? constraints.maxWidth;
                final minTableWidth = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : tableWidth;
                final headerCells = _buildHeaderCells(responsiveLayout);
                final allRows = <TableRow>[
                  ...widget.preHeaderRows.map(
                    (cells) => _buildRow(
                      cells: cells,
                      minWidth: minWidth,
                      useLegacyCellMinWidth: useLegacyCellMinWidth,
                    ),
                  ),
                  _buildRow(
                    cells: headerCells,
                    minWidth: minWidth,
                    isHeader: true,
                    useLegacyCellMinWidth: useLegacyCellMinWidth,
                  ),
                  for (var i = 0; i < zeilenzahl; i++)
                    _buildRow(
                      key: widget.rows[i].key,
                      cells: widget.rows[i].cells,
                      minWidth: minWidth,
                      useLegacyCellMinWidth: useLegacyCellMinWidth,
                      backgroundColor: widget.rows[i].backgroundColor,
                      letzte: i == zeilenzahl - 1,
                    ),
                ];

                return SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: minTableWidth),
                    child: SizedBox(
                      width: tableWidth,
                      child: Table(
                        key: widget.tableKey,
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        columnWidths: columnWidths,
                        defaultColumnWidth: const IntrinsicColumnWidth(),
                        children: allRows,
                      ),
                    ),
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
                        (karto?.feld ?? codex.panelRaised).withValues(alpha: 0),
                        karto?.feld ?? codex.panelRaised,
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildHeaderCells(AdaptiveTableLayout? layout) {
    final specs = widget.columnSpecs;
    final resizeBinding = widget.columnResize;
    if (specs == null || resizeBinding == null || layout == null) {
      return widget.headerCells;
    }
    return buildResizableTableHeaderCells(
      cells: widget.headerCells,
      specs: specs,
      resolvedWidths: layout.columnWidths,
      resizeBinding: resizeBinding,
    );
  }

  TableRow _buildRow({
    LocalKey? key,
    required List<Widget> cells,
    required double minWidth,
    required bool useLegacyCellMinWidth,
    bool isHeader = false,
    Color? backgroundColor,
    bool letzte = false,
  }) {
    final karto = kartoVariante(context);
    if (karto != null) {
      return _kartographZeile(
        karto: karto,
        key: key,
        cells: cells,
        minWidth: minWidth,
        useLegacyCellMinWidth: useLegacyCellMinWidth,
        isHeader: isHeader,
        backgroundColor: backgroundColor,
        letzte: letzte,
      );
    }
    final codex = context.codexTheme;
    return TableRow(
      key: key,
      decoration: BoxDecoration(
        color: isHeader
            ? codex.parchmentStrong.withValues(alpha: 0.92)
            : backgroundColor,
      ),
      children: cells
          .map(
            (cell) => Padding(
              padding: widget.horizontalPadding,
              child: useLegacyCellMinWidth
                  ? ConstrainedBox(
                      constraints: BoxConstraints(minWidth: minWidth),
                      child: isHeader
                          ? DefaultTextStyle.merge(
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: codex.ink,
                              ),
                              child: cell,
                            )
                          : cell,
                    )
                  : (isHeader
                        ? DefaultTextStyle.merge(
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: codex.ink,
                            ),
                            child: cell,
                          )
                        : cell),
            ),
          )
          .toList(growable: false),
    );
  }

  // Eine Zelle der Kartograph-Tabelle: Kopfschrift oder Tabellenziffern,
  // numerisch rechtsbuendig, auf Wunsch mit alter Mindestbreite.
  Widget _kartographZelle(
    Widget zelle, {
    required bool numerisch,
    required bool isHeader,
    required TextStyle kopfstil,
    required double? minWidth,
  }) {
    var ergebnis = zelle;
    if (isHeader) {
      ergebnis = DefaultTextStyle.merge(style: kopfstil, child: ergebnis);
    } else if (numerisch) {
      ergebnis = DefaultTextStyle.merge(
        style: const TextStyle(
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        ),
        child: ergebnis,
      );
    }
    if (numerisch) {
      ergebnis = Align(alignment: Alignment.centerRight, child: ergebnis);
    }
    if (minWidth != null) {
      ergebnis = ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth),
        child: ergebnis,
      );
    }
    return ergebnis;
  }

  // Kopf auf senke in der Etikettschrift, Zeilen durch Haarlinien getrennt.
  // Numerische Spalten stehen rechtsbuendig mit Tabellenziffern.
  TableRow _kartographZeile({
    required KartoTheme karto,
    required LocalKey? key,
    required List<Widget> cells,
    required double minWidth,
    required bool useLegacyCellMinWidth,
    required bool isHeader,
    required Color? backgroundColor,
    required bool letzte,
  }) {
    final texte = Theme.of(context).textTheme;
    final standardAbstand =
        widget.horizontalPadding == const EdgeInsets.fromLTRB(6, 4, 6, 6);
    final abstand = standardAbstand
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
        : widget.horizontalPadding;
    final kopfstil = texte.etikett.copyWith(color: karto.schriftLeise);
    return TableRow(
      key: key,
      decoration: BoxDecoration(
        color: isHeader ? karto.senke : backgroundColor,
        border: isHeader || !letzte
            ? Border(
                bottom: BorderSide(
                  color: karto.hoehenlinie,
                  width: Strich.hoehenlinie,
                ),
              )
            : null,
      ),
      children: <Widget>[
        for (var spalte = 0; spalte < cells.length; spalte++)
          Padding(
            padding: abstand,
            child: _kartographZelle(
              cells[spalte],
              numerisch: widget.numerischeSpalten.contains(spalte),
              isHeader: isHeader,
              kopfstil: kopfstil,
              minWidth: useLegacyCellMinWidth ? minWidth : null,
            ),
          ),
      ],
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
