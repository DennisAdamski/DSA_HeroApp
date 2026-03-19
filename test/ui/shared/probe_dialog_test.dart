import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_dialog.dart';

void main() {
  Widget wrapApp(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('dialog shows an initial digital result', (tester) async {
    const request = ResolvedProbeRequest(
      type: ProbeType.attribute,
      title: 'Eigenschaftsprobe: Mut',
      subtitle: 'MU',
      ruleHint: 'rule',
      diceSpec: DiceSpec(count: 1, sides: 20),
      targets: <ProbeTargetValue>[ProbeTargetValue(label: 'MU', value: 14)],
    );

    await tester.pumpWidget(wrapApp(const ProbeDialog(request: request)));
    await tester.pumpAndSettle();

    expect(find.text('Eigenschaftsprobe: Mut'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('probe-dialog-result-headline')),
      findsOneWidget,
    );
  });

  testWidgets('manual mode evaluates entered dice values', (tester) async {
    const request = ResolvedProbeRequest(
      type: ProbeType.attribute,
      title: 'Eigenschaftsprobe: Mut',
      subtitle: 'MU',
      ruleHint: 'rule',
      diceSpec: DiceSpec(count: 1, sides: 20),
      targets: <ProbeTargetValue>[ProbeTargetValue(label: 'MU', value: 14)],
    );

    await tester.pumpWidget(wrapApp(const ProbeDialog(request: request)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manuell'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('probe-dialog-die-0')),
      '20',
    );
    await tester.pumpAndSettle();

    expect(find.text('Misslungen'), findsOneWidget);
  });

  testWidgets('talent probes expose the specialization toggle', (tester) async {
    const request = ResolvedProbeRequest(
      type: ProbeType.talent,
      title: 'Talentprobe: Athletik',
      subtitle: 'MU / GE / KK',
      ruleHint: 'rule',
      diceSpec: DiceSpec(count: 3, sides: 20),
      targets: <ProbeTargetValue>[
        ProbeTargetValue(label: 'MU', value: 14),
        ProbeTargetValue(label: 'GE', value: 12),
        ProbeTargetValue(label: 'KK', value: 13),
      ],
      basePool: 7,
      specializationBonus: 2,
    );

    await tester.pumpWidget(wrapApp(const ProbeDialog(request: request)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('probe-dialog-specialization')),
      findsOneWidget,
    );
  });
}
