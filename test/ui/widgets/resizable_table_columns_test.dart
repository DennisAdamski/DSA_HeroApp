import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/adaptive_table_columns.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/flexible_table.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/resizable_table_columns.dart';

void main() {
  testWidgets('resizable data columns preserve content width and add handle', (
    tester,
  ) async {
    const specs = <AdaptiveDataColumnSpec>[
      AdaptiveDataColumnSpec(
        label: Text('Sehr lange Spaltenüberschrift'),
        width: AdaptiveTableColumnSpec(
          columnId: 'name',
          minWidth: 100,
          maxWidth: 140,
          resizable: true,
          resizeMaxWidth: 480,
        ),
      ),
      AdaptiveDataColumnSpec(
        label: Text('Wert'),
        width: AdaptiveTableColumnSpec.fixed(40),
      ),
    ];
    final layout = resolveAdaptiveDataTableLayout(
      specs,
      availableWidth: 260,
      columnSpacing: 0,
      horizontalMargin: 0,
      userWidths: const <String, double>{'name': 180},
    );
    final binding = TableColumnResizeBinding(
      tableId: 'magic.activeSpells',
      widths: const <String, double>{'name': 180},
      updateWidth: (_, _) {},
      commitWidth: (_) async {},
      resetWidths: () async {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: DataTable(
            horizontalMargin: 0,
            columnSpacing: 0,
            columns: buildResizableDataColumns(
              layout: layout,
              resizeBinding: binding,
            ),
            rows: const <DataRow>[
              DataRow(
                cells: <DataCell>[
                  DataCell(Text('Axxeleratus')),
                  DataCell(Text('7')),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(layout.contentWidthFor(0), 180);
    expect(
      find.byKey(
        const ValueKey<String>('table-column-resize-magic.activeSpells-name'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag updates locally and persists once on pointer release', (
    tester,
  ) async {
    final repository = _FakeSettingsRepository(const AppSettings());
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: _ResizeHarness())),
      ),
    );
    await tester.pump();

    final handle = find.byKey(
      const ValueKey<String>('table-column-resize-magic.activeSpells-name'),
    );
    expect(handle, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();

    expect(find.text('200'), findsOneWidget);
    expect(repository.saveCount, 0);

    await gesture.up();
    await tester.pump();

    expect(repository.saveCount, 1);
    expect(
      repository.settings.tableColumnWidths['magic.activeSpells']?['name'],
      200,
    );
    expect(find.text('Spalten zurücksetzen'), findsOneWidget);
  });

  testWidgets('reset action removes only the current table preferences', (
    tester,
  ) async {
    final repository = _FakeSettingsRepository(
      const AppSettings(
        tableColumnWidths: <String, Map<String, double>>{
          'magic.activeSpells': <String, double>{'name': 280},
          'inventory.items': <String, double>{'status': 360},
        },
      ),
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: _ResizeHarness())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Spalten zurücksetzen'));
    await tester.pump();

    expect(repository.saveCount, 1);
    expect(repository.settings.tableColumnWidths, <String, Map<String, double>>{
      'inventory.items': <String, double>{'status': 360},
    });
    expect(find.text('Spalten zurücksetzen'), findsNothing);
  });

  testWidgets('resize handle exposes its cursor and accepts mouse drags', (
    tester,
  ) async {
    final repository = _FakeSettingsRepository(const AppSettings());
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: _ResizeHarness())),
      ),
    );
    await tester.pump();

    final handle = find.byKey(
      const ValueKey<String>('table-column-resize-magic.activeSpells-name'),
    );
    final mouseRegion = find.ancestor(
      of: handle,
      matching: find.byType(MouseRegion),
    );
    expect(
      tester.widget<MouseRegion>(mouseRegion.first).cursor,
      SystemMouseCursors.resizeColumn,
    );

    final center = tester.getCenter(handle);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: center);
    await mouse.down(center);
    await mouse.moveBy(const Offset(40, 0));
    await mouse.up();
    await tester.pump();

    expect(repository.saveCount, 1);
    expect(
      repository.settings.tableColumnWidths['magic.activeSpells']?['name'],
      160,
    );
    await mouse.removePointer();
  });

  testWidgets('horizontal scrolling remains available outside the handle', (
    tester,
  ) async {
    final repository = _FakeSettingsRepository(const AppSettings());
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: Scaffold(body: _ScrollableResizeHarness()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(FlexibleTable),
      matching: find.byType(Scrollable),
    );
    final state = tester.state<ScrollableState>(scrollable);
    expect(state.position.pixels, 0);

    await tester.drag(
      find.byKey(const ValueKey<String>('scrollable-table-cell')),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();

    expect(state.position.pixels, greaterThan(0));
    expect(repository.saveCount, 0);
  });

  testWidgets('failed persistence keeps the session width and reports it', (
    tester,
  ) async {
    final repository = _FakeSettingsRepository(
      const AppSettings(),
      throwOnSave: true,
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: _ResizeHarness())),
      ),
    );
    await tester.pump();

    final handle = find.byKey(
      const ValueKey<String>('table-column-resize-magic.activeSpells-name'),
    );
    await tester.drag(handle, const Offset(80, 0));
    await tester.pumpAndSettle();

    expect(find.text('200'), findsOneWidget);
    expect(
      find.text('Spaltenbreite konnte nicht gespeichert werden.'),
      findsOneWidget,
    );
  });

  testWidgets('a saved width rebuilds only the resized table', (tester) async {
    final repository = _FakeSettingsRepository(const AppSettings());
    addTearDown(repository.dispose);
    var resizedBuilds = 0;
    var otherBuilds = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                _CountingTable(
                  tableId: 'magic.activeSpells',
                  onBuild: () => resizedBuilds++,
                ),
                _CountingTable(
                  tableId: 'inventory.items',
                  onBuild: () => otherBuilds++,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    resizedBuilds = 0;
    otherBuilds = 0;
    await tester.drag(
      find.byKey(
        const ValueKey<String>('table-column-resize-magic.activeSpells-name'),
      ),
      const Offset(40, 0),
    );
    await tester.pumpAndSettle();

    expect(repository.saveCount, 1);
    expect(resizedBuilds, greaterThan(0));
    expect(otherBuilds, 0);
  });
}

class _CountingTable extends StatelessWidget {
  const _CountingTable({required this.tableId, required this.onBuild});

  final String tableId;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    return PersistedTableColumnLayout(
      tableId: tableId,
      builder: (context, binding) {
        onBuild();
        return SizedBox(
          width: 240,
          height: 48,
          child: ResizableTableHeaderCell(
            spec: const AdaptiveTableColumnSpec(
              columnId: 'name',
              minWidth: 100,
              maxWidth: 180,
              resizable: true,
              resizeMaxWidth: 480,
            ),
            currentWidth: binding.widths['name'] ?? 120,
            resizeBinding: binding,
            child: const Text('Name'),
          ),
        );
      },
    );
  }
}

class _ResizeHarness extends StatelessWidget {
  const _ResizeHarness();

  @override
  Widget build(BuildContext context) {
    const spec = AdaptiveTableColumnSpec(
      columnId: 'name',
      minWidth: 100,
      maxWidth: 180,
      resizable: true,
      resizeMaxWidth: 480,
    );
    return PersistedTableColumnLayout(
      tableId: 'magic.activeSpells',
      builder: (context, binding) {
        final width = binding.widths['name'] ?? 120;
        return Column(
          children: <Widget>[
            Text(width.toStringAsFixed(0)),
            SizedBox(
              width: 240,
              height: 48,
              child: ResizableTableHeaderCell(
                spec: spec,
                currentWidth: width,
                resizeBinding: binding,
                child: const Text('Name'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScrollableResizeHarness extends StatelessWidget {
  const _ScrollableResizeHarness();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 200,
        child: PersistedTableColumnLayout(
          tableId: 'inventory.items',
          builder: (context, binding) => FlexibleTable(
            horizontalPadding: EdgeInsets.zero,
            columnResize: binding,
            columnSpecs: const <AdaptiveTableColumnSpec>[
              AdaptiveTableColumnSpec(
                columnId: 'name',
                minWidth: 180,
                maxWidth: 180,
                resizable: true,
                resizeMaxWidth: 480,
              ),
              AdaptiveTableColumnSpec.fixed(240),
            ],
            headerCells: const <Widget>[Text('Name'), Text('Status')],
            rows: const <FlexibleTableRow>[
              FlexibleTableRow(
                cells: <Widget>[
                  Text(
                    'Axxeleratus',
                    key: ValueKey<String>('scrollable-table-cell'),
                  ),
                  Text('Aktiv'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FakeSettingsRepository implements HiveSettingsRepository {
  _FakeSettingsRepository(this.settings, {this.throwOnSave = false});

  final StreamController<AppSettings> _controller =
      StreamController<AppSettings>.broadcast();
  AppSettings settings;
  final bool throwOnSave;
  int saveCount = 0;

  @override
  AppSettings load() => settings;

  @override
  Future<void> save(AppSettings next) async {
    if (throwOnSave) {
      throw StateError('test save failure');
    }
    settings = next;
    saveCount++;
    _controller.add(next);
  }

  @override
  Stream<AppSettings> watch() => _controller.stream;

  Future<void> dispose() => _controller.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
