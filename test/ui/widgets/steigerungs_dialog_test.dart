import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/learn/learn_complexity.dart';
import 'package:dsa_heldenverwaltung/domain/learn/learn_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/steigerung_herleitung_rules.dart';
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

  testWidgets('Epos-Aufschlag erhöht die AP-Kosten um 25 %', (tester) async {
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
                    episch: true,
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
      find.textContaining('Epos-Aufschlag (+25 %): +1 AP'),
      findsOneWidget,
    );

    await tester.tap(find.text('Steigern'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.apKosten, 3);
  });

  testWidgets('Haupteigenschaft bleibt vom Epos-Aufschlag verschont', (
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
                    bezeichnung: 'Körperkraft',
                    aktuellerWert: 0,
                    maxWert: 10,
                    effektiveKomplexitaet: LearnCost.c,
                    verfuegbareAp: 999,
                    episch: true,
                    istHaupteigenschaft: true,
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
    expect(find.textContaining('Epos-Aufschlag'), findsNothing);
    expect(
      find.byKey(
        const ValueKey<String>('steigerungs-dialog-main-attribute-hint'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Steigern'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.apKosten, 2);
  });

  testWidgets('die aufklappbare Berechnung nennt die Schritte der Regel', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () => showSteigerungsDialog(
                  context: context,
                  bezeichnung: 'Klettern',
                  aktuellerWert: 4,
                  maxWert: 12,
                  effektiveKomplexitaet: LearnCost.d,
                  verfuegbareAp: 999,
                  seAnzahl: 1,
                  episch: true,
                ),
                child: const Text('Öffnen'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();

    final kachel = find.byKey(
      const ValueKey<String>('steigerungs-dialog-herleitung'),
    );
    expect(kachel, findsOneWidget);
    expect(find.text('Grundkosten'), findsNothing);
    await tester.ensureVisible(kachel);
    await tester.tap(find.text('Berechnung der AP-Kosten'));
    await tester.pumpAndSettle();

    expect(find.text('Grundkosten'), findsOneWidget);
    expect(find.text('Sondererfahrung'), findsOneWidget);
    expect(find.text('Epischer Aufschlag (+25 %)'), findsOneWidget);
  });

  Future<void> oeffne(
    WidgetTester tester, {
    required int aktuellerWert,
    Lernregeln lernregeln = Lernregeln.keine,
    int? lehrmeisterMaxWert,
    LearnCost komplexitaet = LearnCost.d,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showSteigerungsDialog(
                context: context,
                bezeichnung: 'Wand aus Erz',
                aktuellerWert: aktuellerWert,
                maxWert: 14,
                effektiveKomplexitaet: komplexitaet,
                verfuegbareAp: 9999,
                lehrmeisterVerfuegbar: true,
                lernregeln: lernregeln,
                lehrmeisterMaxWert: lehrmeisterMaxWert,
                komplexitaetsHinweis: 'Lernkomplexität D',
              ),
              child: const Text('Öffnen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();
  }

  testWidgets('Hexalogie senkt die Kosten und nennt ihren Hinweis', (
    tester,
  ) async {
    await oeffne(
      tester,
      aktuellerWert: 3,
      lernregeln: const Lernregeln(
        erleichterungBisWert: 9,
        hinweise: ['Elementare Wände: eine Spalte leichter bis ZfW 9'],
      ),
    );
    expect(
      find.textContaining('eine Spalte leichter bis ZfW 9'),
      findsOneWidget,
    );
    // Schritt 3 -> 4 in Spalte C statt D.
    expect(
      find.text('AP-Kosten: ${LearnCost.c.costForStep(3)}'),
      findsOneWidget,
    );
  });

  testWidgets('ein Lehrmeister wirkt nur bis Stufe + 3', (tester) async {
    await oeffne(tester, aktuellerWert: 5, lehrmeisterMaxWert: 5);
    await tester.ensureVisible(find.text('Mit Lehrmeister'));
    await tester.tap(find.text('Mit Lehrmeister'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('steigerungs-dialog-lm-grenze')),
      findsOneWidget,
    );
    final ohneLm = LearnCost.d.costForStep(5);
    expect(find.text('Kosten (LM): $ohneLm AP'), findsOneWidget);
  });

  testWidgets('innerhalb der Grenze gilt der Lehrmeister-Nachlass', (
    tester,
  ) async {
    await oeffne(tester, aktuellerWert: 3, lehrmeisterMaxWert: 10);
    await tester.ensureVisible(find.text('Mit Lehrmeister'));
    await tester.tap(find.text('Mit Lehrmeister'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('steigerungs-dialog-lm-grenze')),
      findsNothing,
    );
    expect(
      find.text(
        'Kosten (LM): ${apMitLehrmeister(LearnCost.d.costForStep(3))} AP',
      ),
      findsOneWidget,
    );
  });

  testWidgets('die Berechnung zeigt Lernspalte in Spalten und Hexalogie', (
    tester,
  ) async {
    await oeffne(
      tester,
      aktuellerWert: 3,
      lernregeln: Lernregeln(
        erleichterungBisWert: 9,
        spaltenHerleitung: Herleitung(
          bezeichnung: 'Lernspalte',
          schritte: const [
            HerleitungsSchritt(
              bezeichnung: 'Komplexität des Zaubers',
              betrag: 4,
              art: HerleitungsArt.grundwert,
              formel: 'Spalte D',
            ),
            HerleitungsSchritt(
              bezeichnung: 'Merkmalskenntnis',
              betrag: -1,
              art: HerleitungsArt.modifikator,
              quelle: 'Merkmalskenntnis',
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Berechnung der AP-Kosten'));
    await tester.pumpAndSettle();

    expect(find.text('Lernspalte'), findsOneWidget);
    expect(find.textContaining('Merkmalskenntnis: -1 Spalte'), findsOneWidget);
    expect(find.text('Ergebnis: Spalte C'), findsOneWidget);
    expect(find.text('Hexalogie'), findsOneWidget);
  });
}
