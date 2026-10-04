import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_dialog.dart';

void main() {
  testWidgets(
    'Ein Gefechtsauftrag wertet nur einmal aus und friert Ergebnis ein',
    (tester) async {
      var anzahl = 0;
      const request = ResolvedProbeRequest(
        type: ProbeType.combatAttack,
        title: 'AT',
        subtitle: '',
        ruleHint: '',
        diceSpec: DiceSpec(count: 1, sides: 20),
        targets: [ProbeTargetValue(label: 'AT', value: 14)],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProbeDialog(
              request: request,
              singleResolution: true,
              onResolved: (_) => anzahl++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Manuell'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('probe-dialog-die-0')),
        '12',
      );
      await tester.tap(find.text('Auswerten'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Auswerten'));
      await tester.pumpAndSettle();
      expect(anzahl, 1);
      final feld = tester.widget<TextField>(
        find.byKey(const ValueKey('probe-dialog-modifier')),
      );
      expect(feld.enabled, false);
    },
  );
}
