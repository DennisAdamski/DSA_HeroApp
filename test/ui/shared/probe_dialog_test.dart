import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_dialog.dart';

const _kAttrRequest = ResolvedProbeRequest(
  type: ProbeType.attribute,
  title: 'Eigenschaftsprobe: Mut',
  subtitle: 'MU',
  ruleHint: 'rule',
  diceSpec: DiceSpec(count: 1, sides: 20),
  targets: <ProbeTargetValue>[ProbeTargetValue(label: 'MU', value: 14)],
);

const _kDamageRequest = ResolvedProbeRequest(
  type: ProbeType.damage,
  title: 'Schadenswurf',
  subtitle: '1W6+4',
  ruleHint: 'rule',
  diceSpec: DiceSpec(count: 1, sides: 6, modifier: 4),
  targets: <ProbeTargetValue>[],
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Future<void> _rollMainProbe(WidgetTester tester) async {
  await tester.tap(find.text('Würfeln').first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pumpAndSettle();
}

Future<void> _rollTrefferzone(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Trefferzone würfeln'));
  await tester.tap(find.text('Trefferzone würfeln'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dialog opens in idle state - kein Ergebnis vor dem Würfeln', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ProbeDialog(request: _kAttrRequest)));
    await tester.pumpAndSettle();

    expect(find.text('Eigenschaftsprobe: Mut'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('probe-dialog-result-headline')),
      findsNothing,
    );
  });

  testWidgets('Ergebnis erscheint nach Klick auf Würfeln', (tester) async {
    await tester.pumpWidget(_wrap(const ProbeDialog(request: _kAttrRequest)));
    await tester.pumpAndSettle();

    await _rollMainProbe(tester);

    expect(
      find.byKey(const ValueKey<String>('probe-dialog-result-headline')),
      findsOneWidget,
    );
  });

  testWidgets('manueller Modus wertet eingegebene Würfelwerte aus', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ProbeDialog(request: _kAttrRequest)));
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

  testWidgets('Talentproben zeigen den Spezialisierungs-Toggle', (
    tester,
  ) async {
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

    await tester.pumpWidget(_wrap(const ProbeDialog(request: request)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('probe-dialog-specialization')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Schadenswurf zeigt Trefferzonen-Stepper und keinen gezielten Schlag mehr',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ProbeDialog(
            request: _kDamageRequest,
            rollTrefferzone: _rollBrust,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _rollMainProbe(tester);
      await _rollTrefferzone(tester);

      expect(find.text('Brust'), findsOneWidget);
      expect(find.textContaining('Gezielter Schlag'), findsNothing);
      expect(find.text('Wunden durch Treffer'), findsOneWidget);
      expect(find.text('1W6 würfeln'), findsOneWidget);

      await tester.ensureVisible(find.byIcon(Icons.arrow_drop_up));
      await tester.tap(find.byIcon(Icons.arrow_drop_up));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('trefferzonen-wunden-value')),
        findsOneWidget,
      );
      expect(find.text('2W6 würfeln'), findsOneWidget);
    },
  );
}

int _rollBrust() => 15;
