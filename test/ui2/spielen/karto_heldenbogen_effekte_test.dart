import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_bewegung.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_heldenbogen_rahmen.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_wert_rueckmeldung.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_klappinhalt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_ressourcenwert.dart';

/// Effekte bleiben endlich, abschaltbar und lassen Bedienaktionen durch.
void main() {
  for (final system in [false, true]) {
    testWidgets('laufende Kontur und Balken stoppen sofort (System $system)', (
      tester,
    ) async {
      var aktiv = false;
      var aus = false;
      var wert = 12;
      late StateSetter aktualisieren;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              aktualisieren = setState;
              return MediaQuery(
                data: MediaQueryData(disableAnimations: system && aus),
                child: KartoEffektEinstellungen(
                  animationen: system || !aus,
                  dekorativeEffekte: false,
                  child: Center(
                    child: SizedBox(
                      width: 320,
                      child: KartoHeldenbogenRahmen(
                        aktiv: aktiv,
                        child: KartoRessourcenwert(
                          bezeichnung: 'Lebenspunkte',
                          aktuell: wert,
                          maximum: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      aktualisieren(() {
        aktiv = true;
        wert = 8;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        greaterThan(0.4),
      );
      aktualisieren(() => aus = true);
      await tester.pump();
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.4,
      );
      expect(tester.binding.transientCallbackCount, 0);
    });
  }

  testWidgets('Einklappen wird animiert und lässt sich sofort abschalten', (
    tester,
  ) async {
    var zu = false;
    var animationen = true;
    late StateSetter aktualisieren;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            aktualisieren = setState;
            return Center(
              child: KartoEffektEinstellungen(
                animationen: animationen,
                dekorativeEffekte: true,
                child: KartoKlappinhalt(
                  eingeklappt: zu,
                  child: const SizedBox(
                    height: 200,
                    child: Text('Klappinhalt'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    final inhalt = find.byType(KartoKlappinhalt);
    expect(tester.getSize(inhalt).height, 200);
    aktualisieren(() => zu = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(inhalt).height, greaterThan(0));
    expect(tester.getSize(inhalt).height, lessThan(200));
    aktualisieren(() => animationen = false);
    await tester.pump();
    expect(tester.getSize(inhalt).height, 0);
    expect(find.text('Klappinhalt'), findsNothing);
    aktualisieren(() => zu = false);
    await tester.pump();
    expect(tester.getSize(inhalt).height, 200);
  });

  for (final option in ['animationen', 'dekoration', 'system']) {
    testWidgets('$option stoppt einen laufenden Lichtschimmer', (tester) async {
      var aus = false;
      var klicks = 0;
      late StateSetter aktualisieren;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              aktualisieren = setState;
              return MediaQuery(
                data: MediaQueryData(
                  disableAnimations: aus && option == 'system',
                ),
                child: KartoEffektEinstellungen(
                  animationen: !(aus && option == 'animationen'),
                  dekorativeEffekte: !(aus && option == 'dekoration'),
                  child: Center(
                    child: KartoHeldenbogenRahmen(
                      magisch: true,
                      child: GestureDetector(
                        onTap: () => klicks++,
                        child: const Text('Probe'),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Probe'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(klicks, 1);
      aktualisieren(() => aus = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.tap(find.text('Probe'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpAndSettle();
      expect(klicks, 2);
    });
  }

  testWidgets(
    'Wertänderung animiert endlich und behält den echten Zahlenwert',
    (tester) async {
      var wert = 12;
      late StateSetter aktualisieren;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              aktualisieren = setState;
              return KartoWertRueckmeldung(
                wert: wert,
                farbe: Colors.red,
                child: Text('$wert'),
              );
            },
          ),
        ),
      );
      aktualisieren(() => wert = 9);
      await tester.pump();
      expect(find.text('9'), findsOneWidget);
      expect(find.text('12'), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
}
