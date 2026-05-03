import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_vital_block.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders label, subtitle and current/max', (tester) async {
    await tester.pumpWidget(_wrap(InspectorVitalBlock(
      label: 'LeP',
      subtitle: 'Lebenspunkte',
      current: 32,
      max: 38,
      kind: VitalKind.lep,
      onChanged: (_) {},
    )));

    expect(find.text('LeP'), findsOneWidget);
    expect(find.text('Lebenspunkte'), findsOneWidget);
    expect(
      find.textContaining('32', findRichText: true),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.textContaining('/ 38', findRichText: true),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('-1 button decrements by one', (tester) async {
    int? captured;
    await tester.pumpWidget(_wrap(InspectorVitalBlock(
      label: 'LeP',
      subtitle: 'Lebenspunkte',
      current: 10,
      max: 20,
      kind: VitalKind.lep,
      onChanged: (v) => captured = v,
    )));

    await tester.tap(find.byKey(const ValueKey('vital-block-minus-1')));
    expect(captured, 9);
  });

  testWidgets('-5 button decrements by five', (tester) async {
    int? captured;
    await tester.pumpWidget(_wrap(InspectorVitalBlock(
      label: 'LeP',
      subtitle: 'Lebenspunkte',
      current: 10,
      max: 20,
      kind: VitalKind.lep,
      onChanged: (v) => captured = v,
    )));

    await tester.tap(find.byKey(const ValueKey('vital-block-minus-5')));
    expect(captured, 5);
  });

  testWidgets('+1 button increments by one without upper clamp', (tester) async {
    int? captured;
    await tester.pumpWidget(_wrap(InspectorVitalBlock(
      label: 'LeP',
      subtitle: 'Lebenspunkte',
      current: 38,
      max: 38,
      kind: VitalKind.lep,
      onChanged: (v) => captured = v,
    )));

    await tester.tap(find.byKey(const ValueKey('vital-block-plus-1')));
    expect(captured, 39);
  });

  testWidgets('+5 button increments by five without upper clamp', (tester) async {
    int? captured;
    await tester.pumpWidget(_wrap(InspectorVitalBlock(
      label: 'LeP',
      subtitle: 'Lebenspunkte',
      current: 38,
      max: 38,
      kind: VitalKind.lep,
      onChanged: (v) => captured = v,
    )));

    await tester.tap(find.byKey(const ValueKey('vital-block-plus-5')));
    expect(captured, 43);
  });

  testWidgets('-1 clamps at -10', (tester) async {
    int? captured;
    await tester.pumpWidget(_wrap(InspectorVitalBlock(
      label: 'LeP',
      subtitle: 'Lebenspunkte',
      current: -10,
      max: 20,
      kind: VitalKind.lep,
      onChanged: (v) => captured = v,
    )));

    await tester.tap(find.byKey(const ValueKey('vital-block-minus-1')));
    expect(captured, -10,
        reason: 'must not drop below the documented vital floor');
  });

  testWidgets('-5 clamps at -10', (tester) async {
    int? captured;
    await tester.pumpWidget(_wrap(InspectorVitalBlock(
      label: 'LeP',
      subtitle: 'Lebenspunkte',
      current: -7,
      max: 20,
      kind: VitalKind.lep,
      onChanged: (v) => captured = v,
    )));

    await tester.tap(find.byKey(const ValueKey('vital-block-minus-5')));
    expect(captured, -10);
  });

  testWidgets('reset button resets to max value', (tester) async {
    int? captured;
    await tester.pumpWidget(_wrap(InspectorVitalBlock(
      label: 'LeP',
      subtitle: 'Lebenspunkte',
      current: 10,
      max: 20,
      kind: VitalKind.lep,
      onChanged: (v) => captured = v,
    )));

    await tester.tap(find.byKey(const ValueKey('vital-block-reset')));
    expect(captured, 20);
  });

  testWidgets('reset button is hidden when current equals max', (tester) async {
    await tester.pumpWidget(_wrap(InspectorVitalBlock(
      label: 'LeP',
      subtitle: 'Lebenspunkte',
      current: 20,
      max: 20,
      kind: VitalKind.lep,
      onChanged: (_) {},
    )));

    expect(find.byKey(const ValueKey('vital-block-reset')), findsNothing);
  });
}
