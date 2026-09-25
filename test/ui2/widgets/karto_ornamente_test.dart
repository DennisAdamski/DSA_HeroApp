import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_ornamente.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_papier.dart';

void main() {
  Future<void> zeige(
    WidgetTester tester,
    Brightness helligkeit,
    Widget kind,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKartoTheme(
          brightness: helligkeit,
          centerAppBarTitle: false,
        ),
        home: Scaffold(body: Center(child: kind)),
      ),
    );
    // Wechselt die Helligkeit zwischen zwei Aufrufen, blendet MaterialApp
    // die Themes ueber; erst danach tragen die Token ihre Endwerte.
    await tester.pumpAndSettle();
  }

  for (final helligkeit in Brightness.values) {
    group('Ornamente ${helligkeit.name}', () {
      testWidgets('Kompassrose zeichnet in jeder Groesse', (tester) async {
        for (final groesse in <double>[0, 12, 48, 220]) {
          await zeige(
            tester,
            helligkeit,
            KartoKompassrose(groesse: groesse),
          );
          expect(tester.takeException(), isNull, reason: 'Groesse $groesse');
        }
      });

      testWidgets('Kompassring beschneidet den Inhalt rund', (tester) async {
        await zeige(
          tester,
          helligkeit,
          const KartoKompassring(
            groesse: 96,
            schein: true,
            child: ColoredBox(
              key: ValueKey<String>('inhalt'),
              color: Color(0xFF000000),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          find.ancestor(
            of: find.byKey(const ValueKey<String>('inhalt')),
            matching: find.byType(ClipOval),
          ),
          findsOneWidget,
        );
        // Der Inhalt liegt innerhalb des Rings, nicht darunter hindurch.
        final inhalt = tester.getSize(
          find.byKey(const ValueKey<String>('inhalt')),
        );
        expect(inhalt.width, lessThan(96));
      });

      testWidgets('Hoehenlinien, Zierlinie und Stern bauen', (tester) async {
        await zeige(
          tester,
          helligkeit,
          const SizedBox(
            width: 300,
            height: 200,
            child: Column(
              children: [
                Expanded(
                  child: KartoHoehenlinien(
                    farbe: Color(0x22000000),
                    gelaende: KartoGelaende.ruecken,
                  ),
                ),
                KartoZierlinie(maxBreite: 200),
                KartoStern(),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('Ornamente bleiben aus der Semantik heraus', (tester) async {
        final semantik = tester.ensureSemantics();
        await zeige(
          tester,
          helligkeit,
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KartoKompassrose(groesse: 48),
              SizedBox(width: 200, child: KartoZierlinie()),
            ],
          ),
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && (w.properties.label?.isNotEmpty ?? false),
          ),
          findsNothing,
        );
        semantik.dispose();
      });
    });
  }

  testWidgets('Papiergrund traegt hell die Textur, dunkel nicht', (
    tester,
  ) async {
    for (final fall in <(Brightness, KartoTheme, bool)>[
      (Brightness.light, kartoHell, true),
      (Brightness.dark, kartoDunkel, false),
    ]) {
      await zeige(
        tester,
        fall.$1,
        const KartoPapier(child: SizedBox(width: 100, height: 100)),
      );
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(KartoPapier),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final dekoration = box.decoration as BoxDecoration;
      expect(dekoration.color, fall.$2.blatt);
      expect(dekoration.image != null, fall.$3, reason: fall.$1.name);
    }
  });

  testWidgets('Hoehenlinien schlucken keine Tipps', (tester) async {
    // Das Wasserzeichen liegt ueber Flaechen mit Bedienelementen.
    var getippt = 0;
    await zeige(
      tester,
      Brightness.light,
      SizedBox(
        width: 200,
        height: 100,
        child: Stack(
          children: [
            Positioned.fill(
              child: TextButton(
                onPressed: () => getippt++,
                child: const Text('Knopf'),
              ),
            ),
            const Positioned.fill(
              child: KartoHoehenlinien(farbe: Color(0x22000000)),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Knopf'));
    expect(getippt, 1);
  });
}
