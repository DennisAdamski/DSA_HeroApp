import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/debug/karto_token_sheet.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

import 'karto_test_fonts.dart';

void main() {
  setUpAll(ladeKartoSchriften);

  Future<void> zeige(
    WidgetTester tester, {
    required Brightness helligkeit,
    required Size groesse,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = groesse;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildKartoTheme(
          brightness: helligkeit,
          centerAppBarTitle: false,
        ),
        home: const KartoTokenSheet(),
      ),
    );
    await tester.pump();
  }

  // Das Token-Blatt ist die Sichtpruefung fuer die ganze Schicht. Wenn es
  // nicht mehr baut, fehlt ein Token oder eine Schriftrolle ist leer.
  for (final helligkeit in Brightness.values) {
    for (final groesse in <(String, Size)>[
      ('breit', Size(1366, 900)),
      ('Tablet', Size(834, 1112)),
      ('schmal', Size(320, 640)),
    ]) {
      testWidgets('Token-Blatt baut ${helligkeit.name} auf ${groesse.$1}', (
        tester,
      ) async {
        await zeige(tester, helligkeit: helligkeit, groesse: groesse.$2);

        expect(find.text('Token-Blatt'), findsOneWidget);
        expect(find.text('Flächen'), findsOneWidget);

        // Die weiter unten liegenden Abschnitte baut die Liste erst, wenn sie
        // in den Sichtbereich kommen. Bis ans Ende scrollen prueft damit auch
        // gleich, dass keiner davon ueberlaeuft.
        final liste = find.byType(Scrollable).first;
        for (final abschnitt in <String>[
          'Die neun Schriftrollen',
          'Gewichtsprobe',
          'Ziffernprobe',
        ]) {
          await tester.scrollUntilVisible(
            find.text(abschnitt),
            240,
            scrollable: liste,
          );
          expect(find.text(abschnitt), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final fall in <(Brightness, KartoTheme)>[
    (Brightness.light, kartoHell),
    (Brightness.dark, kartoDunkel),
  ]) {
    testWidgets('das Blatt nimmt die ${fall.$1.name}-Token aus dem Theme', (
      tester,
    ) async {
      await zeige(tester, helligkeit: fall.$1, groesse: const Size(1366, 900));

      final kontext = tester.element(find.byType(KartoTokenSheet));
      final token = KartoTheme.of(kontext);
      expect(token.blatt, fall.$2.blatt);
      expect(token.schrift, fall.$2.schrift);
      expect(token.meer, fall.$2.meer);
    });
  }
}
