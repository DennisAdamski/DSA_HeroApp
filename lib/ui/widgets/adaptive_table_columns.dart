import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Beschreibt eine adaptive Tabellen-Spalte mit fester Unter- und Obergrenze.
///
/// Die effektive Breite folgt dem breitesten Inhalt der Spalte, bleibt aber
/// immer innerhalb von [minWidth] und [maxWidth].
@immutable
class AdaptiveTableColumnSpec {
  /// Erzeugt eine adaptive Spaltendefinition.
  const AdaptiveTableColumnSpec({
    required this.minWidth,
    required this.maxWidth,
    this.flex,
  });

  /// Erzeugt eine feste Spalte ohne adaptive Breitenberechnung.
  const AdaptiveTableColumnSpec.fixed(double width)
    : minWidth = width,
      maxWidth = width,
      flex = null;

  /// Die minimale Spaltenbreite in logischen Pixeln.
  final double minWidth;

  /// Die maximale Spaltenbreite in logischen Pixeln.
  final double maxWidth;

  /// Optionaler Flex-Wert fuer Restbreite innerhalb der Tabelle.
  final double? flex;

  /// Die normalisierte Mindestbreite der Spalte.
  double get lowerBound => math.min(minWidth, maxWidth);

  /// Die normalisierte Maximalbreite der Spalte.
  double get upperBound => math.max(minWidth, maxWidth);

  /// Baut die zugehoerige Flutter-[TableColumnWidth].
  TableColumnWidth toTableColumnWidth() {
    if (lowerBound == upperBound) {
      return FixedColumnWidth(lowerBound);
    }

    final intrinsicWidth = IntrinsicColumnWidth(flex: flex);
    final minBoundedWidth = MaxColumnWidth(
      FixedColumnWidth(lowerBound),
      intrinsicWidth,
    );
    return MinColumnWidth(minBoundedWidth, FixedColumnWidth(upperBound));
  }
}

/// Beschreibt eine `DataTable`-Spalte inklusive Kopf, Zahlenausrichtung und
/// adaptiver Breitenregel an einer einzigen Stelle.
@immutable
class AdaptiveDataColumnSpec {
  /// Erzeugt eine adaptive `DataTable`-Spaltendefinition.
  const AdaptiveDataColumnSpec({
    required this.label,
    required this.width,
    this.numeric = false,
    this.debugName,
    this.contentPadding = 24,
  });

  /// Kopf-Widget der Spalte.
  final Widget label;

  /// Adaptive Breitenregel der Spalte.
  final AdaptiveTableColumnSpec width;

  /// Aktiviert die numerische Ausrichtung fuer `DataTable`.
  final bool numeric;

  /// Optionaler Klarname fuer Lesbarkeit und Debugging.
  final String? debugName;

  /// Reserviert Platz fuer `DataTable`-internes Zell- und Header-Padding.
  final double contentPadding;

  /// Baut die zugehoerige Flutter-[DataColumn].
  DataColumn toDataColumn({double? resolvedWidth}) {
    final headerAlignment = numeric
        ? Alignment.centerRight
        : Alignment.centerLeft;
    return DataColumn(
      label: Align(
        alignment: headerAlignment,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: headerAlignment,
          child: label,
        ),
      ),
      numeric: numeric,
      columnWidth: resolvedWidth == null
          ? width.toTableColumnWidth()
          : FixedColumnWidth(resolvedWidth),
    );
  }
}

/// Beschreibt das auf die verfuegbare Breite aufgeloeste Layout einer
/// `DataTable`.
@immutable
class AdaptiveDataTableLayout {
  /// Erzeugt ein aufgeloestes Layout fuer `DataTable`-Spalten.
  const AdaptiveDataTableLayout({
    required this.specs,
    required this.columnWidths,
    required this.columns,
    required this.tableMinWidth,
    required this.tableWidth,
  });

  /// Urspruengliche Spaltendefinitionen.
  final List<AdaptiveDataColumnSpec> specs;

  /// Effektive Breite jeder Spalte innerhalb der Tabelle.
  final List<double> columnWidths;

  /// Fertig gebaute `DataColumn`-Liste mit den aufgeloesten Breiten.
  final List<DataColumn> columns;

  /// Mindestbreite der Tabelleninhalte ohne `DataTable`-Chrome.
  final double tableMinWidth;

  /// Effektiv genutzte Inhaltsbreite der Tabelle ohne `DataTable`-Chrome.
  final double tableWidth;

  /// Liefert die effektive Breite einer Spalte.
  double widthFor(int columnIndex) => columnWidths[columnIndex];

  /// Liefert eine Breite fuer Zellinhalte, optional reduziert um Inset.
  double contentWidthFor(int columnIndex, {double inset = 0}) {
    final contentPadding = specs[columnIndex].contentPadding;
    final resolvedWidth = widthFor(columnIndex) - contentPadding - inset;
    return math.max(0, resolvedWidth);
  }
}

/// Beschreibt das auf die verfuegbare Breite aufgeloeste Layout einer
/// Flutter-[Table].
@immutable
class AdaptiveTableLayout {
  /// Erzeugt ein aufgeloestes Layout fuer `Table`-Spalten.
  const AdaptiveTableLayout({
    required this.specs,
    required this.columnWidths,
    required this.tableWidth,
  });

  /// Urspruengliche Spaltendefinitionen.
  final List<AdaptiveTableColumnSpec> specs;

  /// Effektive Breite jeder Spalte innerhalb der Tabelle.
  final List<double> columnWidths;

  /// Effektiv genutzte Tabellenbreite.
  final double tableWidth;

  /// Liefert die effektive Breite einer Spalte.
  double widthFor(int columnIndex) => columnWidths[columnIndex];

  /// Liefert die `Table.columnWidths`-Map fuer fixe Spaltenbreiten.
  Map<int, TableColumnWidth> toColumnWidthMap() {
    return <int, TableColumnWidth>{
      for (var i = 0; i < columnWidths.length; i++)
        i: FixedColumnWidth(columnWidths[i]),
    };
  }
}

/// Erzeugt die [Table.columnWidths]-Map fuer eine geordnete Spaltenliste.
Map<int, TableColumnWidth> buildAdaptiveTableColumnWidths(
  List<AdaptiveTableColumnSpec> specs,
) {
  return <int, TableColumnWidth>{
    for (var i = 0; i < specs.length; i++) i: specs[i].toTableColumnWidth(),
  };
}

/// Summiert die Mindestbreite aller Spalten fuer aeussere Mindest-Constraints.
double adaptiveTableMinWidth(List<AdaptiveTableColumnSpec> specs) {
  return specs.fold<double>(0, (sum, spec) => sum + spec.lowerBound);
}

/// Loest adaptive `Table`-Spalten auf die verfuegbare Breite auf.
AdaptiveTableLayout resolveAdaptiveTableLayout(
  List<AdaptiveTableColumnSpec> specs, {
  required double availableWidth,
}) {
  final resolvedWidths = _resolveAdaptiveWidths(
    specs.map((spec) => spec.lowerBound).toList(growable: false),
    specs.map((spec) => spec.upperBound).toList(growable: false),
    specs.map((spec) => spec.flex ?? 0).toList(growable: false),
    availableWidth: availableWidth,
  );

  return AdaptiveTableLayout(
    specs: specs,
    columnWidths: resolvedWidths,
    tableWidth: resolvedWidths.fold<double>(0, (sum, width) => sum + width),
  );
}

/// Baut die `DataTable.columns`-Liste aus geordneten Spaltendefinitionen.
List<DataColumn> buildAdaptiveDataColumns(
  List<AdaptiveDataColumnSpec> specs, {
  double? availableWidth,
  double columnSpacing = 56,
  double horizontalMargin = 24,
}) {
  if (availableWidth == null) {
    return specs.map((spec) => spec.toDataColumn()).toList(growable: false);
  }
  return resolveAdaptiveDataTableLayout(
    specs,
    availableWidth: availableWidth,
    columnSpacing: columnSpacing,
    horizontalMargin: horizontalMargin,
  ).columns;
}

/// Loest adaptive `DataTable`-Spalten auf die verfuegbare Breite auf.
AdaptiveDataTableLayout resolveAdaptiveDataTableLayout(
  List<AdaptiveDataColumnSpec> specs, {
  required double availableWidth,
  required double columnSpacing,
  required double horizontalMargin,
}) {
  final minColumnWidths = specs
      .map((spec) => spec.width.lowerBound + spec.contentPadding)
      .toList(growable: false);
  final maxColumnWidths = specs
      .map((spec) => spec.width.upperBound + spec.contentPadding)
      .toList(growable: false);
  final chromeWidth = _adaptiveDataTableChromeWidth(
    columnCount: specs.length,
    columnSpacing: columnSpacing,
    horizontalMargin: horizontalMargin,
  );
  final availableContentWidth = math
      .max(0.0, availableWidth - chromeWidth)
      .toDouble();
  final resolvedWidths = _resolveAdaptiveWidths(
    minColumnWidths,
    maxColumnWidths,
    specs.map((spec) => spec.width.flex ?? 0).toList(growable: false),
    availableWidth: availableContentWidth,
  );
  final minTableWidth = minColumnWidths.fold<double>(
    0,
    (sum, width) => sum + width,
  );

  final columns = <DataColumn>[
    for (var i = 0; i < specs.length; i++)
      specs[i].toDataColumn(resolvedWidth: resolvedWidths[i]),
  ];

  return AdaptiveDataTableLayout(
    specs: specs,
    columnWidths: resolvedWidths,
    columns: columns,
    tableMinWidth: minTableWidth,
    tableWidth: resolvedWidths.fold<double>(0, (sum, width) => sum + width),
  );
}

List<double> _resolveAdaptiveWidths(
  List<double> minColumnWidths,
  List<double> maxColumnWidths,
  List<double> flexValues, {
  required double availableWidth,
}) {
  final resolvedWidths = List<double>.from(minColumnWidths);
  final minTableWidth = minColumnWidths.fold<double>(
    0,
    (sum, width) => sum + width,
  );
  final targetWidth = math.max(minTableWidth, availableWidth);
  var remainingWidth = math.max(0, targetWidth - minTableWidth);

  while (remainingWidth > 0.001) {
    final growableIndexes = <int>[
      for (var i = 0; i < resolvedWidths.length; i++)
        if (flexValues[i] > 0 && resolvedWidths[i] < maxColumnWidths[i]) i,
    ];
    if (growableIndexes.isEmpty) {
      break;
    }

    final totalFlex = growableIndexes.fold<double>(
      0,
      (sum, index) => sum + flexValues[index],
    );
    if (totalFlex <= 0) {
      break;
    }

    var distributedThisPass = 0.0;
    for (final index in growableIndexes) {
      final desiredShare = remainingWidth * (flexValues[index] / totalFlex);
      final maxGrowth = maxColumnWidths[index] - resolvedWidths[index];
      final appliedGrowth = math.min(desiredShare, maxGrowth);
      resolvedWidths[index] += appliedGrowth;
      distributedThisPass += appliedGrowth;
    }

    if (distributedThisPass <= 0.001) {
      break;
    }
    remainingWidth -= distributedThisPass;
  }

  return resolvedWidths;
}

double _adaptiveDataTableChromeWidth({
  required int columnCount,
  required double columnSpacing,
  required double horizontalMargin,
}) {
  if (columnCount <= 0) {
    return 0;
  }
  final spacingWidth = math.max(0, columnCount - 1) * columnSpacing;
  return spacingWidth + horizontalMargin * 2;
}
