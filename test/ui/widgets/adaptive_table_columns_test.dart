import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/widgets/adaptive_table_columns.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/flexible_table.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/resizable_table_columns.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/responsive_adaptive_table.dart';

void main() {
  test('AdaptiveDataColumnSpec builds DataColumn with numeric and width', () {
    const spec = AdaptiveDataColumnSpec(
      label: Text('ZfW'),
      width: AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 96),
      numeric: true,
      debugName: 'spellValue',
    );

    final column = spec.toDataColumn();

    expect(column.label, isA<Align>());
    expect(column.numeric, isTrue);
    expect(column.columnWidth, isA<MinColumnWidth>());
  });

  test('buildAdaptiveDataColumns keeps spec order', () {
    const specs = <AdaptiveDataColumnSpec>[
      AdaptiveDataColumnSpec(
        label: Text('Name'),
        width: AdaptiveTableColumnSpec(minWidth: 120, maxWidth: 180),
      ),
      AdaptiveDataColumnSpec(
        label: Text('Mod'),
        width: AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 96),
        numeric: true,
      ),
    ];

    final columns = buildAdaptiveDataColumns(specs);

    expect(columns, hasLength(2));
    final firstLabel = (columns[0].label as Align).child as FittedBox;
    final secondLabel = (columns[1].label as Align).child as FittedBox;
    expect(((firstLabel.child as Text).data), 'Name');
    expect(columns[0].numeric, isFalse);
    expect(((secondLabel.child as Text).data), 'Mod');
    expect(columns[1].numeric, isTrue);
  });

  test('responsive layout grows only flex columns within max bounds', () {
    const specs = <AdaptiveDataColumnSpec>[
      AdaptiveDataColumnSpec(
        label: Text('Name'),
        width: AdaptiveTableColumnSpec(minWidth: 100, maxWidth: 180, flex: 2),
      ),
      AdaptiveDataColumnSpec(
        label: Text('Typ'),
        width: AdaptiveTableColumnSpec(minWidth: 80, maxWidth: 120, flex: 1),
      ),
      AdaptiveDataColumnSpec(
        label: Text('INI'),
        width: AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 80),
        numeric: true,
      ),
    ];

    final layout = resolveAdaptiveDataTableLayout(
      specs,
      availableWidth: 500,
      columnSpacing: 12,
      horizontalMargin: 12,
    );

    expect(layout.contentWidthFor(0), 180);
    expect(layout.contentWidthFor(1), greaterThan(80));
    expect(layout.contentWidthFor(1), lessThanOrEqualTo(120));
    expect(layout.contentWidthFor(2), 56);
  });

  test(
    'responsive layout increases content width when more space is available',
    () {
      const specs = <AdaptiveDataColumnSpec>[
        AdaptiveDataColumnSpec(
          label: Text('Name'),
          width: AdaptiveTableColumnSpec(minWidth: 100, maxWidth: 220, flex: 2),
        ),
        AdaptiveDataColumnSpec(
          label: Text('ZfW'),
          width: AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 80),
          numeric: true,
        ),
      ];

      final narrowLayout = resolveAdaptiveDataTableLayout(
        specs,
        availableWidth: 150,
        columnSpacing: 0,
        horizontalMargin: 0,
      );
      final wideLayout = resolveAdaptiveDataTableLayout(
        specs,
        availableWidth: 320,
        columnSpacing: 0,
        horizontalMargin: 0,
      );

      expect(narrowLayout.contentWidthFor(0), 100);
      expect(wideLayout.contentWidthFor(0), greaterThan(100));
      expect(wideLayout.contentWidthFor(0), lessThanOrEqualTo(220));
    },
  );

  test('responsive table layout grows only flex columns within max bounds', () {
    const specs = <AdaptiveTableColumnSpec>[
      AdaptiveTableColumnSpec(minWidth: 120, maxWidth: 220, flex: 2),
      AdaptiveTableColumnSpec(minWidth: 80, maxWidth: 140, flex: 1),
      AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 80),
    ];

    final layout = resolveAdaptiveTableLayout(specs, availableWidth: 500);

    expect(layout.widthFor(0), 220);
    expect(layout.widthFor(1), greaterThan(80));
    expect(layout.widthFor(1), lessThanOrEqualTo(140));
    expect(layout.widthFor(2), 56);
  });

  test('user width override changes only the addressed resizable column', () {
    const specs = <AdaptiveTableColumnSpec>[
      AdaptiveTableColumnSpec(
        columnId: 'name',
        minWidth: 100,
        maxWidth: 180,
        flex: 2,
        resizable: true,
        resizeMaxWidth: 480,
      ),
      AdaptiveTableColumnSpec(
        columnId: 'type',
        minWidth: 80,
        maxWidth: 120,
        flex: 1,
        resizable: true,
        resizeMaxWidth: 480,
      ),
      AdaptiveTableColumnSpec.fixed(56),
    ];

    final automatic = resolveAdaptiveTableLayout(specs, availableWidth: 300);
    final customized = resolveAdaptiveTableLayout(
      specs,
      availableWidth: 300,
      userWidths: const <String, double>{'name': 240},
    );

    expect(customized.widthFor(0), 240);
    expect(customized.widthFor(1), automatic.widthFor(1));
    expect(customized.widthFor(2), automatic.widthFor(2));
    expect(
      customized.tableWidth,
      closeTo(automatic.tableWidth + 240 - automatic.widthFor(0), 0.001),
    );
  });

  test('user widths clamp to resize bounds and ignore fixed columns', () {
    const specs = <AdaptiveTableColumnSpec>[
      AdaptiveTableColumnSpec(
        columnId: 'name',
        minWidth: 100,
        maxWidth: 180,
        resizable: true,
        resizeMaxWidth: 480,
      ),
      AdaptiveTableColumnSpec(columnId: 'fixed', minWidth: 56, maxWidth: 56),
    ];

    final belowMinimum = resolveAdaptiveTableLayout(
      specs,
      availableWidth: 156,
      userWidths: const <String, double>{'name': 1, 'fixed': 300},
    );
    final aboveMaximum = resolveAdaptiveTableLayout(
      specs,
      availableWidth: 156,
      userWidths: const <String, double>{'name': 999},
    );
    final invalid = resolveAdaptiveTableLayout(
      specs,
      availableWidth: 156,
      userWidths: const <String, double>{'name': double.nan},
    );

    expect(belowMinimum.columnWidths, <double>[100, 56]);
    expect(aboveMaximum.columnWidths, <double>[480, 56]);
    expect(invalid.columnWidths, <double>[100, 56]);
  });

  testWidgets(
    'FlexibleTable preserves fixed columns while adaptive columns fill the row',
    (tester) async {
      Future<void> pumpFlexibleTable(String name) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: FlexibleTable(
                horizontalPadding: EdgeInsets.zero,
                columnSpecs: const <AdaptiveTableColumnSpec>[
                  AdaptiveTableColumnSpec(minWidth: 80, maxWidth: 120),
                  AdaptiveTableColumnSpec.fixed(40),
                ],
                headerCells: const <Widget>[Text('Name'), SizedBox.shrink()],
                rows: <FlexibleTableRow>[
                  FlexibleTableRow(
                    cells: <Widget>[Text(name), const SizedBox.shrink()],
                  ),
                  const FlexibleTableRow(
                    cells: <Widget>[
                      _MeasuredCell(
                        measureKey: ValueKey<String>('flex-name-width'),
                      ),
                      _MeasuredCell(
                        measureKey: ValueKey<String>('flex-action-width'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }

      await pumpFlexibleTable('Kurz');
      final shortWidth = tester
          .getSize(find.byKey(const ValueKey<String>('flex-name-width')))
          .width;
      final actionWidth = tester
          .getSize(find.byKey(const ValueKey<String>('flex-action-width')))
          .width;

      expect(shortWidth, greaterThanOrEqualTo(80));
      expect(shortWidth, greaterThan(120));
      expect(actionWidth, greaterThan(0));

      await pumpFlexibleTable('1234567890123456789012345678901234567890');
      final longWidth = tester
          .getSize(find.byKey(const ValueKey<String>('flex-name-width')))
          .width;

      expect(longWidth, greaterThanOrEqualTo(shortWidth));
    },
  );

  testWidgets('DataTable numeric column grows and shrinks within min max', (
    tester,
  ) async {
    Future<void> pumpDataTable(String number) async {
      const specs = <AdaptiveDataColumnSpec>[
        AdaptiveDataColumnSpec(
          label: SizedBox.shrink(),
          width: AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 96),
          numeric: true,
        ),
        AdaptiveDataColumnSpec(
          label: SizedBox.shrink(),
          width: AdaptiveTableColumnSpec.fixed(40),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: DataTable(
                horizontalMargin: 0,
                columnSpacing: 0,
                columns: buildAdaptiveDataColumns(specs),
                rows: <DataRow>[
                  DataRow(
                    cells: <DataCell>[
                      DataCell(Text(number)),
                      const DataCell(Text('A')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    await pumpDataTable('7');
    final shortWidth = tester.getSize(find.byType(Table)).width;
    expect(shortWidth, greaterThanOrEqualTo(56));
    expect(shortWidth, lessThanOrEqualTo(140));
    expect(tester.takeException(), isNull);

    await pumpDataTable('1234567890');
    final longWidth = tester.getSize(find.byType(Table)).width;
    expect(longWidth, greaterThan(shortWidth));
    expect(longWidth, lessThanOrEqualTo(180));
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlexibleTable applies persisted widths and renders a handle', (
    tester,
  ) async {
    final resizeBinding = TableColumnResizeBinding(
      tableId: 'inventory.items',
      widths: const <String, double>{'name': 180},
      updateWidth: (_, _) {},
      commitWidth: (_) async {},
      resetWidths: () async {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 220,
              child: FlexibleTable(
                horizontalPadding: EdgeInsets.zero,
                columnResize: resizeBinding,
                columnSpecs: const <AdaptiveTableColumnSpec>[
                  AdaptiveTableColumnSpec(
                    columnId: 'name',
                    minWidth: 100,
                    maxWidth: 140,
                    resizable: true,
                    resizeMaxWidth: 480,
                  ),
                  AdaptiveTableColumnSpec.fixed(40),
                ],
                headerCells: const <Widget>[Text('Name'), Text('Wert')],
                rows: const <FlexibleTableRow>[
                  FlexibleTableRow(
                    cells: <Widget>[
                      _MeasuredCell(
                        measureKey: ValueKey<String>('resized-flex-cell'),
                      ),
                      Text('7'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(
        const ValueKey<String>('table-column-resize-inventory.items-name'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('resized-flex-cell')))
          .width,
      180,
    );
  });

  testWidgets('ResponsiveAdaptiveTable hides resize controls in card mode', (
    tester,
  ) async {
    final resizeBinding = TableColumnResizeBinding(
      tableId: 'talents.general',
      widths: const <String, double>{'name': 180},
      updateWidth: (_, _) {},
      commitWidth: (_) async {},
      resetWidths: () async {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 80,
              child: ResponsiveAdaptiveTable<String>(
                columnResize: resizeBinding,
                columnSpecs: const <AdaptiveTableColumnSpec>[
                  AdaptiveTableColumnSpec(
                    columnId: 'name',
                    minWidth: 100,
                    maxWidth: 140,
                    resizable: true,
                    resizeMaxWidth: 480,
                  ),
                  AdaptiveTableColumnSpec.fixed(40),
                ],
                headerRow: const TableRow(
                  children: <Widget>[Text('Name'), Text('Wert')],
                ),
                items: const <String>['Axxeleratus'],
                tableRowBuilder: (item) {
                  return TableRow(
                    children: <Widget>[Text(item), const Text('7')],
                  );
                },
                cardBuilder: (context, item) => Text('Karte: $item'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Karte: Axxeleratus'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('table-column-resize-talents.general-name'),
      ),
      findsNothing,
    );
  });
}

class _MeasuredCell extends StatelessWidget {
  const _MeasuredCell({required this.measureKey});

  final Key measureKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: measureKey,
      width: double.infinity,
      height: 10,
      color: Colors.transparent,
    );
  }
}
