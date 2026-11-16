import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_bewegung.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spieltisch_siegel.dart';

/// Kopfornament ist endlich und beim Abschalten sofort statisch.
void main() {
  testWidgets('Daten- und Themewechsel starten den Auftritt nicht erneut', (
    tester,
  ) async {
    var dunkel = false;
    var wert = 12;
    late StateSetter aendern;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            aendern = setState;
            return Theme(
              data: ThemeData(
                brightness: dunkel ? Brightness.dark : Brightness.light,
              ),
              child: Column(
                children: [const KartoSpieltischSiegel(), Text('$wert')],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    aendern(() {
      wert = 9;
      dunkel = true;
    });
    await tester.pump();
    expect(find.text('9'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  for (final abschalten in ['animationen', 'dekoration', 'system']) {
    testWidgets('$abschalten stoppt das Kopfornament sofort', (tester) async {
      var aus = false;
      late StateSetter aendern;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              aendern = setState;
              return MediaQuery(
                data: MediaQueryData(
                  disableAnimations: aus && abschalten == 'system',
                ),
                child: KartoEffektEinstellungen(
                  animationen: !(aus && abschalten == 'animationen'),
                  dekorativeEffekte: !(aus && abschalten == 'dekoration'),
                  child: const Center(child: KartoSpieltischSiegel()),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      aendern(() => aus = true);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.tap(find.byType(KartoSpieltischSiegel));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
    });
  }

  testWidgets('Auftritt und erneutes Antippen kommen zur Ruhe', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: KartoSpieltischSiegel())),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.tap(find.byType(KartoSpieltischSiegel));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
