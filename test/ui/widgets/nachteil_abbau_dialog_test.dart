import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/widgets/nachteil_abbau_dialog.dart';

void main() {
  testWidgets(
    'Goldgier: Kosten summieren sich pro gesenktem Punkt (Selbststudium)',
    (tester) async {
      NachteilAbbauErgebnis? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () async {
                    result = await showNachteilAbbauDialog(
                      context: context,
                      bezeichnung: 'Goldgier',
                      aktuellerWert: 8,
                      minWert: 1,
                      gpWertProPunkt: -1,
                      istSpeziellerErfahrungFaehig: true,
                      verfuegbareAp: 999,
                    );
                  },
                  child: const Text('Öffnen'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Öffnen'));
      await tester.pumpAndSettle();

      // Default-Ziel: aktuellerWert - 1 = 7, also 1 Punkt gesenkt -> 75 AP.
      expect(find.text('AP-Kosten: 75'), findsOneWidget);

      // Vier weitere Schritte senken auf Ziel 3 (5 Punkte insgesamt).
      final senkenButton = find.widgetWithIcon(IconButton, Icons.remove);
      for (var i = 0; i < 4; i++) {
        await tester.tap(senkenButton);
        await tester.pumpAndSettle();
      }

      expect(find.text('3'), findsOneWidget);
      expect(find.text('AP-Kosten: 375'), findsOneWidget);

      // Spezielle Erfahrung aktivieren -> günstigerer Faktor (50x statt 75x).
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'nachteil-abbau-dialog-spezielle-erfahrung',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AP-Kosten: 250'), findsOneWidget);

      await tester.tap(find.text('Abbauen'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.neuerWert, 3);
      expect(result!.apKosten, 250);
      expect(result!.mitSpeziellerErfahrung, isTrue);
    },
  );

  testWidgets('Absenken bis unter den Minimalwert markiert vollständige Entfernung', (
    tester,
  ) async {
    NachteilAbbauErgebnis? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await showNachteilAbbauDialog(
                    context: context,
                    bezeichnung: 'Goldgier',
                    aktuellerWert: 1,
                    minWert: 1,
                    gpWertProPunkt: -1,
                    istSpeziellerErfahrungFaehig: true,
                    verfuegbareAp: 999,
                  );
                },
                child: const Text('Öffnen'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();

    expect(find.text('entfernt'), findsOneWidget);
    expect(
      find.text('Der Nachteil wird bei Bestätigung vollständig entfernt.'),
      findsOneWidget,
    );
    expect(find.text('AP-Kosten: 75'), findsOneWidget);

    await tester.tap(find.text('Abbauen'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.neuerWert, 0);
    expect(result!.apKosten, 75);
  });

  testWidgets(
    'gestufter Nachteil ohne SE-Marker zeigt keine Checkbox und nutzt 100er Faktor',
    (tester) async {
      NachteilAbbauErgebnis? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () async {
                    result = await showNachteilAbbauDialog(
                      context: context,
                      bezeichnung: 'Niedrige Lebenskraft',
                      aktuellerWert: 3,
                      minWert: 1,
                      gpWertProPunkt: -2,
                      verfuegbareAp: 999,
                    );
                  },
                  child: const Text('Öffnen'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Öffnen'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>(
            'nachteil-abbau-dialog-spezielle-erfahrung',
          ),
        ),
        findsNothing,
      );
      // 1 Punkt gesenkt, 100 x |-2| = 200 AP.
      expect(find.text('AP-Kosten: 200'), findsOneWidget);

      await tester.tap(find.text('Abbauen'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.apKosten, 200);
      expect(result!.mitSpeziellerErfahrung, isFalse);
    },
  );

  testWidgets(
    'nicht parsbarer Katalogtext fällt auf editierbares AP-Kosten-Feld zurück',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () async {
                    await showNachteilAbbauDialog(
                      context: context,
                      bezeichnung: 'Angst vor',
                      aktuellerWert: 2,
                      minWert: 1,
                      verfuegbareAp: 999,
                    );
                  },
                  child: const Text('Öffnen'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Öffnen'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('nachteil-abbau-dialog-ap-kosten')),
        findsOneWidget,
      );
    },
  );

  testWidgets('nicht genug AP verhindert Bestätigung', (tester) async {
    NachteilAbbauErgebnis? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await showNachteilAbbauDialog(
                    context: context,
                    bezeichnung: 'Goldgier',
                    aktuellerWert: 8,
                    minWert: 1,
                    gpWertProPunkt: -1,
                    istSpeziellerErfahrungFaehig: true,
                    verfuegbareAp: 10,
                  );
                },
                child: const Text('Öffnen'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();

    final senkenButton = find.widgetWithIcon(IconButton, Icons.remove);
    for (var i = 0; i < 4; i++) {
      await tester.tap(senkenButton);
      await tester.pumpAndSettle();
    }

    expect(find.text('Nicht genug AP für diesen Abbau.'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Abbauen'),
    );
    expect(button.onPressed, isNull);
    expect(result, isNull);
  });
}
