import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_combat_quick_chip.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders label and value', (tester) async {
    await tester.pumpWidget(_wrap(InspectorCombatQuickChip(
      label: 'AT',
      value: 10,
      onTap: () {},
    )));

    expect(find.text('AT'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('tap fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(InspectorCombatQuickChip(
      label: 'PA',
      value: 9,
      onTap: () => taps++,
    )));

    await tester.tap(find.byType(InspectorCombatQuickChip));
    expect(taps, 1);
  });

  testWidgets('shows tooltip when provided', (tester) async {
    await tester.pumpWidget(_wrap(InspectorCombatQuickChip(
      label: 'AT (Nh)',
      value: 7,
      tooltip: 'Dolch',
      onTap: () {},
    )));

    expect(find.byTooltip('Dolch'), findsOneWidget);
  });
}
