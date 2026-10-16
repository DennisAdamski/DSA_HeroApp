import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/sync_object_diff.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/sync_conflict_comparison_table.dart';

void main() {
  // Gleiche Eckdaten isolieren die Hinweise vom übrigen Konflikt-Gate.
  Widget table({
    bool offline = false,
    SyncObjectDiff? diff,
    DateTime? localUpdatedAt,
    DateTime? remoteUpdatedAt,
  }) {
    final conflict = SyncConflict(
      id: offline ? 'offlineHero-h-1' : 'hero-h-1',
      objectType: SyncObjectType.hero,
      objectId: 'h-1',
      title: 'Alrik',
      localSummary: 'Alrik',
      remoteSummary: 'Alrik',
      detectedAt: DateTime.utc(2026),
      localUpdatedAt: localUpdatedAt,
      remoteUpdatedAt: remoteUpdatedAt,
    );
    return MaterialApp(
      home: Scaffold(
        body: SyncConflictComparisonTable(conflict: conflict, diff: diff),
      ),
    );
  }

  const missing = SyncObjectDiff(
    entries: <SyncDiffEntry>[],
    remoteMissing: true,
  );
  const empty = SyncObjectDiff(entries: <SyncDiffEntry>[]);
  const changed = SyncObjectDiff(
    entries: <SyncDiffEntry>[
      SyncDiffEntry(
        path: <String>['name'],
        kind: SyncDiffKind.changed,
        localValue: 'Offline Alrik',
        remoteValue: 'Konto Alrik',
      ),
    ],
  );

  final diffCases = <String, SyncObjectDiff?>{
    'ohne Diff': null,
    'ohne Konto-Held': missing,
    'ohne Unterschiede': empty,
    'mit Unterschieden': changed,
  };
  for (final entry in diffCases.entries) {
    testWidgets('Offline-Hinweis erscheint ${entry.key}', (tester) async {
      await tester.pumpWidget(table(offline: true, diff: entry.value));

      expect(
        find.textContaining('„Nur Lokal“ ersetzt den Konto-Stand'),
        findsOneWidget,
      );
    });
  }

  testWidgets('fehlender Konto-Held wird nicht als gelöscht bezeichnet', (
    tester,
  ) async {
    await tester.pumpWidget(table(offline: true, diff: missing));

    expect(find.textContaining('Im Konto existiert kein Held'), findsOneWidget);
    expect(find.textContaining('Online-Version wurde gelöscht'), findsNothing);
  });

  testWidgets('normaler Löschkonflikt behält seinen Hinweis', (tester) async {
    await tester.pumpWidget(table(diff: missing));

    expect(
      find.textContaining('Online-Version wurde gelöscht'),
      findsOneWidget,
    );
    expect(
      find.textContaining('„Nur Lokal“ ersetzt den Konto-Stand'),
      findsNothing,
    );
  });

  final stamp = DateTime.utc(2026, 10, 9, 12);
  final timestamps = <(DateTime?, DateTime?)>[
    (null, null),
    (stamp, null),
    (null, stamp),
  ];
  for (var index = 0; index < timestamps.length; index++) {
    testWidgets('unvollständige Zeitstempel blenden Zeile aus: $index', (
      tester,
    ) async {
      final (local, remote) = timestamps[index];
      await tester.pumpWidget(
        table(localUpdatedAt: local, remoteUpdatedAt: remote),
      );

      expect(find.text('Gespeichert'), findsNothing);
      expect(find.text('Unbekannt'), findsNothing);
    });
  }

  testWidgets('vollständige Zeitstempel bleiben vergleichbar', (tester) async {
    await tester.pumpWidget(
      table(localUpdatedAt: stamp, remoteUpdatedAt: stamp),
    );

    expect(find.text('Gespeichert'), findsOneWidget);
  });
}
