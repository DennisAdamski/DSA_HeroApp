import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/learn/learn_complexity.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/steigerungs_dialog.dart';

void main() {
  testWidgets(
    'manuelle Komplexität ändert AP-Kosten und bestätigtes Ergebnis',
    (tester) async {
      SteigerungsErgebnis? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () async {
                    result = await showSteigerungsDialog(
                      context: context,
                      bezeichnung: 'Athletik',
                      aktuellerWert: 0,
                      maxWert: 10,
                      effektiveKomplexitaet: LearnCost.c,
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

      expect(find.text('AP-Kosten: 2'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('steigerungs-dialog-complexity-value'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('steigerungs-dialog-complexity-increase'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Standard: C'), findsOneWidget);
      expect(find.text('AP-Kosten: 3'), findsOneWidget);

      await tester.tap(find.text('Steigern'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.neuerWert, 1);
      expect(result!.apKosten, 3);
    },
  );

  testWidgets('SE-Berechnung verwendet die manuell gewählte Komplexität', (
    tester,
  ) async {
    SteigerungsErgebnis? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await showSteigerungsDialog(
                    context: context,
                    bezeichnung: 'Sinnesschärfe',
                    aktuellerWert: 0,
                    maxWert: 10,
                    effektiveKomplexitaet: LearnCost.b,
                    verfuegbareAp: 999,
                    seAnzahl: 1,
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

    expect(find.textContaining('Mit 1 SE: 1 Schritt als A'), findsOneWidget);
    expect(find.text('AP-Kosten: 1'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('steigerungs-dialog-complexity-increase'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Standard: B'), findsOneWidget);
    expect(find.textContaining('Mit 1 SE: 1 Schritt als B'), findsOneWidget);
    expect(find.text('AP-Kosten: 2'), findsOneWidget);

    await tester.tap(find.text('Steigern'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.apKosten, 2);
    expect(result!.seVerbraucht, 1);
  });
}
