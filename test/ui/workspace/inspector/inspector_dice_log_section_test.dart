import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_dice_log_section.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

DiceLogEntry _entry({
  required int hour,
  required int minute,
  required bool success,
  String title = 'Probe · KL',
  String subtitle = 'Eigenschaftsprobe ≤ 12',
  AutomaticOutcome outcome = AutomaticOutcome.none,
}) {
  return DiceLogEntry(
    timestamp: DateTime.utc(2026, 4, 30, hour, minute),
    type: ProbeType.attribute,
    title: title,
    subtitle: subtitle,
    success: success,
    diceValues: const [9],
    targetValue: 12,
    automaticOutcome: outcome,
  );
}

void main() {
  testWidgets('renders empty hint when log is empty', (tester) async {
    await tester.pumpWidget(
      _wrap(const InspectorDiceLogSection(entries: <DiceLogEntry>[])),
    );

    expect(find.textContaining('Noch keine'), findsOneWidget);
  });

  testWidgets('renders entries with newest first', (tester) async {
    final older = _entry(
      hour: 8,
      minute: 0,
      success: true,
      title: 'Probe · KL',
    );
    final newer = _entry(
      hour: 8,
      minute: 5,
      success: false,
      title: 'Probe · IN',
    );

    await tester.pumpWidget(
      _wrap(InspectorDiceLogSection(entries: [older, newer])),
    );

    final klFinder = find.text('Probe · KL');
    final inFinder = find.text('Probe · IN');
    expect(klFinder, findsOneWidget);
    expect(inFinder, findsOneWidget);

    final klPos = tester.getTopLeft(klFinder).dy;
    final inPos = tester.getTopLeft(inFinder).dy;
    expect(inPos, lessThan(klPos), reason: 'newer entry must be above older');
  });

  testWidgets('renders GELUNGEN for success and MISSLUNGEN for failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        InspectorDiceLogSection(
          entries: [
            _entry(hour: 8, minute: 0, success: true),
            _entry(hour: 8, minute: 1, success: false),
          ],
        ),
      ),
    );

    expect(find.text('GELUNGEN'), findsOneWidget);
    expect(find.text('MISSLUNGEN'), findsOneWidget);
  });

  testWidgets('renders AUTO label on automatic success', (tester) async {
    await tester.pumpWidget(
      _wrap(
        InspectorDiceLogSection(
          entries: [
            _entry(
              hour: 8,
              minute: 0,
              success: true,
              outcome: AutomaticOutcome.success,
            ),
          ],
        ),
      ),
    );

    expect(find.textContaining('AUTO'), findsOneWidget);
  });

  testWidgets('renders neutral roll entries with result details', (
    tester,
  ) async {
    final entry = DiceLogEntry(
      timestamp: DateTime.utc(2026, 4, 30, 8, 2),
      type: ProbeType.genericRoll,
      title: 'Trefferzone',
      subtitle: 'Brust',
      success: true,
      diceValues: const [15],
      total: 15,
      isNeutral: true,
    );

    await tester.pumpWidget(_wrap(InspectorDiceLogSection(entries: [entry])));

    expect(find.text('WURF'), findsOneWidget);
    expect(find.textContaining('Würfe: 15'), findsOneWidget);
    expect(find.textContaining('Gesamt: 15'), findsOneWidget);
  });
}
