import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/sync_controller.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/sync_object_diff.dart';
import 'package:dsa_heldenverwaltung/ui/screens/sync_conflict_gate.dart';

void main() {
  SyncConflict conflict({String id = 'hero-h-1'}) {
    return SyncConflict(
      id: id,
      objectType: SyncObjectType.hero,
      objectId: 'h-1',
      title: 'Held: Alrik',
      localSummary: 'Alrik lokal',
      remoteSummary: 'Alrik online',
      detectedAt: DateTime.utc(2026, 1, 1),
      supportsKeepBoth: true,
      localApTotal: 1100,
      localApAvailable: 20,
      remoteApTotal: 1200,
      remoteApAvailable: 5,
    );
  }

  Widget buildGate(_FakeSyncController controller) {
    return MaterialApp(
      home: SyncConflictGate(
        syncController: controller,
        child: const Text('App-Inhalt'),
      ),
    );
  }

  testWidgets('zeigt Feldunterschiede nach dem Aufklappen', (tester) async {
    final controller = _FakeSyncController(
      SyncStatusSnapshot(openConflicts: <SyncConflict>[conflict()]),
      diffs: <String, SyncObjectDiff>{
        'hero-h-1': const SyncObjectDiff(
          entries: <SyncDiffEntry>[
            SyncDiffEntry(
              path: <String>['name'],
              kind: SyncDiffKind.changed,
              localValue: 'Alrik lokal',
              remoteValue: 'Alrik online',
            ),
            SyncDiffEntry(
              path: <String>['attributes', 'mu'],
              kind: SyncDiffKind.changed,
              localValue: 12,
              remoteValue: 14,
            ),
          ],
        ),
      },
    );
    addTearDown(controller.close);

    await tester.pumpWidget(buildGate(controller));
    await tester.pumpAndSettle();

    expect(find.text('Unterschiede anzeigen (2)'), findsOneWidget);
    expect(find.text('Eigenschaften › MU'), findsNothing);

    await tester.tap(find.text('Unterschiede anzeigen (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Alrik lokal → Alrik online'), findsOneWidget);
    expect(find.text('Eigenschaften › MU'), findsOneWidget);
    expect(find.text('12 → 14'), findsOneWidget);
  });

  testWidgets('meldet geloeschte Online-Version statt Feldliste', (
    tester,
  ) async {
    final controller = _FakeSyncController(
      SyncStatusSnapshot(openConflicts: <SyncConflict>[conflict()]),
      diffs: <String, SyncObjectDiff>{
        'hero-h-1': const SyncObjectDiff(remoteMissing: true),
      },
    );
    addTearDown(controller.close);

    await tester.pumpWidget(buildGate(controller));
    await tester.pumpAndSettle();

    expect(
      find.text('Die Online-Version wurde gelöscht – kein Feldvergleich '
          'möglich.'),
      findsOneWidget,
    );
    expect(find.textContaining('Unterschiede anzeigen'), findsNothing);
  });

  testWidgets('bleibt ohne Diff-Daten unveraendert nutzbar', (tester) async {
    final controller = _FakeSyncController(
      SyncStatusSnapshot(openConflicts: <SyncConflict>[conflict()]),
    );
    addTearDown(controller.close);

    await tester.pumpWidget(buildGate(controller));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unterschiede anzeigen'), findsNothing);

    await tester.tap(find.text('Lokal behalten'));
    await tester.pumpAndSettle();

    expect(controller.resolvedConflicts, [
      ('hero-h-1', SyncResolutionChoice.keepLocal),
    ]);
  });
}

class _FakeSyncController implements AppSyncController {
  _FakeSyncController(
    SyncStatusSnapshot initial, {
    Map<String, SyncObjectDiff> diffs = const <String, SyncObjectDiff>{},
  }) : _current = initial,
       _diffs = diffs;

  final StreamController<SyncStatusSnapshot> _controller =
      StreamController<SyncStatusSnapshot>.broadcast();
  final Map<String, SyncObjectDiff> _diffs;
  final SyncStatusSnapshot _current;
  final List<(String, SyncResolutionChoice)> resolvedConflicts =
      <(String, SyncResolutionChoice)>[];

  @override
  SyncStatusSnapshot get currentStatus => _current;

  @override
  Stream<SyncStatusSnapshot> watchStatus() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<void> syncNow() async {}

  @override
  Future<void> resolveConflict(
    String conflictId,
    SyncResolutionChoice resolution,
  ) async {
    resolvedConflicts.add((conflictId, resolution));
  }

  @override
  SyncObjectDiff? conflictDiff(String conflictId) => _diffs[conflictId];

  Future<void> close() => _controller.close();
}
