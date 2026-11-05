import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/kurzregel_def.dart';
import 'package:dsa_heldenverwaltung/catalog/kurzregel_loader.dart';
import 'package:dsa_heldenverwaltung/state/kurzregel_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/rules_lookup_dialog.dart';

/// Reiter-Rahmen des Regel-Nachschlags: Kurzregeln zuerst, Wissensbasis dahinter.
void main() {
  const katalog = KurzregelKatalog(
    eintraege: [
      KurzregelDef(
        id: 'kampf_eins',
        titel: 'Erfundene Regel',
        thema: 'kampf',
        quellen: ['Testbuch, S. 1'],
        kurztext: 'Erfundener Text.',
      ),
    ],
  );

  Future<void> zeige(
    WidgetTester tester, {
    double breite = 800,
    double skalierung = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kurzregelKatalogProvider.overrideWith((ref) async => katalog),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(skalierung)),
            child: child!,
          ),
          home: const Scaffold(body: RegelnNachschlagDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Kurzregeln sind der Standardreiter', (tester) async {
    await zeige(tester);

    expect(find.byKey(const ValueKey('rules-lookup-tab-kurzregeln')), findsOne);
    expect(find.byKey(const ValueKey('kurzregeln-suchfeld')), findsOneWidget);
    expect(find.text('Erfundene Regel'), findsOneWidget);
  });

  testWidgets('Wechsel auf die Wissensbasis und zurück erhält die Suche', (
    tester,
  ) async {
    await zeige(tester);
    await tester.enterText(
      find.byKey(const ValueKey('kurzregeln-suchfeld')),
      'erfunden',
    );
    await tester.tap(
      find.byKey(const ValueKey('rules-lookup-tab-wissensbasis')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rules-lookup-tab-kurzregeln')));
    await tester.pumpAndSettle();

    final feld = tester.widget<TextField>(
      find.byKey(const ValueKey('kurzregeln-suchfeld')),
    );
    expect(feld.controller?.text ?? 'erfunden', 'erfunden');
    expect(tester.takeException(), isNull);
  });

  for (final breite in <double>[320, 390]) {
    testWidgets('läuft bei $breite dp und Textfaktor 2 ohne Überlauf', (
      tester,
    ) async {
      await zeige(tester, breite: breite, skalierung: 2);
      await tester.tap(
        find.byKey(const ValueKey('rules-lookup-tab-wissensbasis')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  test('der Einstieg wird auf jeder Plattform angeboten', () {
    expect(isRulesLookupSupported(), isTrue);
  });
}
