import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_aktionsdialog.dart';

import '../../rules/gefecht_ansagen_paket2_test.dart' as fixture;
import '../shell/karto_test_support.dart';

void main() {
  for (final breite in [390.0, 820.0, 1200.0, 1440.0]) {
    for (final hell in Brightness.values) {
      for (final tastatur in [0.0, 250.0]) {
        testWidgets('Ansagen $breite $hell Tastatur=$tastatur', (tester) async {
          tester.view.physicalSize = Size(breite, 1000);
          tester.view.devicePixelRatio = 1;
          tester.view.viewInsets = FakeViewPadding(bottom: tastatur);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: hell),
              home: Scaffold(
                body: GefechtAktionsdialog(
                  zustand: const Gefechtszustand(iniWurf: 6, dk: 'N'),
                  werte: fixture.ansageSnapshot(sf: true),
                  katalog: testCatalog,
                  aktion: Gefechtsaktion.angriff,
                  titel: 'Angreifen',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('gefecht-finte')),
            '3',
          );
          final wucht = find.byKey(const ValueKey('gefecht-wuchtschlag'));
          await tester.ensureVisible(wucht);
          await tester.enterText(wucht, '4');
          await tester.pumpAndSettle();
          expect(
            find.text('Bei erfolgreichem Angriff: Abwehr +3 · TP +4.'),
            findsOneWidget,
          );
          expect(find.text('Weitere Erschwernis'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('gefecht-kontext-bestaetigen')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
