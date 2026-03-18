import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/widgets/combat_quick_stats.dart';

void main() {
  Widget buildTestWidget(CombatQuickStats widget) {
    return MaterialApp(
      home: Scaffold(body: widget),
    );
  }

  group('CombatQuickStats', () {
    testWidgets('zeigt alle 7 Chips im Nahkampf-Modus', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const CombatQuickStats(
            at: 12,
            pa: 10,
            tpExpression: '1W6+3',
            kampfInitiative: 8,
            ausweichen: 5,
            rs: 3,
            ebe: 2,
          ),
        ),
      );

      expect(find.text('AT: 12'), findsOneWidget);
      expect(find.text('PA: 10'), findsOneWidget);
      expect(find.text('TP: 1W6+3'), findsOneWidget);
      expect(find.text('Kampf INI: 8'), findsOneWidget);
      expect(find.text('Ausweichen: 5'), findsOneWidget);
      expect(find.text('RS: 3'), findsOneWidget);
      expect(find.text('eBE: 2'), findsOneWidget);

      // Fernkampf-Chips nicht vorhanden
      expect(find.textContaining('Ladezeit'), findsNothing);
      expect(find.textContaining('Geschosse'), findsNothing);
    });

    testWidgets('versteckt PA und zeigt Ladezeit/Geschosse im Fernkampf',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const CombatQuickStats(
            at: 9,
            tpExpression: '1W6+1',
            kampfInitiative: 7,
            ausweichen: 4,
            rs: 2,
            ebe: 1,
            isRanged: true,
            ladezeit: '3 Aktionen',
            geschosse: 12,
          ),
        ),
      );

      // PA nicht sichtbar
      expect(find.textContaining('PA:'), findsNothing);

      // Fernkampf-Chips vorhanden
      expect(find.text('Ladezeit: 3 Aktionen'), findsOneWidget);
      expect(find.text('Geschosse: 12'), findsOneWidget);

      // Restliche Chips weiterhin da
      expect(find.text('AT: 9'), findsOneWidget);
      expect(find.text('TP: 1W6+1'), findsOneWidget);
      expect(find.text('Kampf INI: 7'), findsOneWidget);
      expect(find.text('Ausweichen: 4'), findsOneWidget);
      expect(find.text('RS: 2'), findsOneWidget);
      expect(find.text('eBE: 1'), findsOneWidget);
    });

    testWidgets('formatiert Werte korrekt', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const CombatQuickStats(
            at: 0,
            pa: 0,
            tpExpression: '2W6',
            kampfInitiative: 15,
            ausweichen: 0,
            rs: 7,
            ebe: 0,
          ),
        ),
      );

      expect(find.text('AT: 0'), findsOneWidget);
      expect(find.text('PA: 0'), findsOneWidget);
      expect(find.text('TP: 2W6'), findsOneWidget);
      expect(find.text('Kampf INI: 15'), findsOneWidget);
      expect(find.text('Ausweichen: 0'), findsOneWidget);
      expect(find.text('RS: 7'), findsOneWidget);
      expect(find.text('eBE: 0'), findsOneWidget);
    });

    testWidgets('nutzt ActionChips wenn Roll-Callbacks gesetzt sind',
        (tester) async {
      var atTapped = 0;
      await tester.pumpWidget(
        buildTestWidget(
          CombatQuickStats(
            at: 12,
            pa: 10,
            tpExpression: '1W6+3',
            kampfInitiative: 8,
            ausweichen: 5,
            rs: 3,
            ebe: 2,
            onRollAt: () {
              atTapped++;
            },
          ),
        ),
      );

      await tester.tap(find.text('AT: 12'));
      await tester.pump();

      expect(atTapped, 1);
      expect(find.byIcon(Icons.casino_outlined), findsOneWidget);
    });
  });
}
