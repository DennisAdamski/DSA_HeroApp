import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/grossmeister_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/combat_meisterschaft_card.dart';

void main() {
  testWidgets('zeigt Pool, Wirkungen und meldet den GE-Schalter', (
    tester,
  ) async {
    bool? geschaltet;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CombatMeisterschaftCard(
              meisterschaft: const MeisterschaftUebersicht(
                waffenmeisterName: 'Waffenmeister (Amazonensäbel)',
                waffenmeisterWirkungen: <String>['INI +1'],
                grossmeisterName: 'Waffen-Großmeister (Säbel)',
                grossmeisterWirkungen: <String>[
                  'GE/INI 15/2 statt 15/3: INI +3',
                ],
                poolPunkte: 3,
                geStattKkMoeglich: true,
                tpKkMitKk: 0,
                tpKkMitGe: 2,
              ),
              onGeStattKk: (an) => geschaltet = an,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Säbel-Pool: 3 Punkte je KR'), findsOneWidget);
    expect(find.text('• GE/INI 15/2 statt 15/3: INI +3'), findsOneWidget);
    expect(find.text('• INI +1'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('combat-meisterschaft-ge-statt-kk')),
    );
    expect(geschaltet, isTrue);
  });
}
