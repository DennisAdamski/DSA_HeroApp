import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/grossmeister_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_grossmeister.dart';

void main() {
  testWidgets('Gefecht zeigt freien Pool und schaltet GE statt KK', (
    tester,
  ) async {
    bool? geschaltet;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GefechtGrossmeisterkarte(
              meisterschaft: const MeisterschaftUebersicht(
                grossmeisterName: 'Waffen-Großmeister (Säbel)',
                poolPunkte: 3,
                geStattKkMoeglich: true,
                tpKkMitGe: 2,
              ),
              poolFrei: 1,
              gesperrt: false,
              onGeStattKk: (an) => geschaltet = an,
            ),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('gefecht-grossmeister-pool')))
          .textSpan!
          .toPlainText(),
      '1 / 3',
    );
    expect(find.text('Großmeister'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('gefecht-grossmeister-ge-statt-kk')),
    );
    expect(geschaltet, isTrue);
  });
}
