import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/kurzregel_def.dart';
import 'package:dsa_heldenverwaltung/catalog/kurzregel_loader.dart';
import 'package:dsa_heldenverwaltung/state/kurzregel_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/kurzregeln_panel.dart';

/// Erfundene Eintraege: geprueft werden Anzeige und Bedienung.
void main() {
  const offen = KurzregelKatalog(
    eintraege: [
      KurzregelDef(
        id: 'zustand_eins',
        titel: 'Betäubung',
        thema: 'zustaende',
        quellen: ['Testbuch, S. 12'],
        kurztext: 'Erfundener offizieller Text.',
        hinweise: ['Erster erfundener Hinweis'],
        hausregelText: 'Erfundene Hausregel-Abweichung.',
        hausregelQuelle: 'testpaket_v1',
      ),
      KurzregelDef(
        id: 'kampf_eins',
        titel: 'Wuchtschlag',
        thema: 'kampf',
        quellen: ['Testbuch, S. 40', 'Zweites Buch, S. 7'],
        kurztext: 'Zweiter erfundener Text.',
      ),
    ],
  );
  const gesperrt = KurzregelKatalog(
    eintraege: [
      KurzregelDef(
        id: 'zustand_eins',
        titel: 'Betäubung',
        thema: 'zustaende',
        quellen: ['Testbuch, S. 12'],
        hausregelQuelle: 'testpaket_v1',
        gesperrt: true,
      ),
    ],
  );

  Future<void> zeige(
    WidgetTester tester,
    KurzregelKatalog katalog, {
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
          home: const Scaffold(body: KurzregelnPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('zeigt Eintraege mit Thema und Hausregel-Kennzeichnung', (
    tester,
  ) async {
    await zeige(tester, offen);

    expect(find.text('Betäubung'), findsOneWidget);
    expect(find.text('Zustände · mit Hausregel'), findsOneWidget);
    expect(find.text('Wuchtschlag'), findsOneWidget);
    expect(find.text('Kampf'), findsWidgets);
  });

  testWidgets('Aufklappen trennt offizielle Regel, Hausregel und Quelle', (
    tester,
  ) async {
    await zeige(tester, offen);

    await tester.tap(find.text('Betäubung'));
    await tester.pumpAndSettle();

    expect(find.text('Offizielle Regel (DSA 4.1)'), findsOneWidget);
    expect(find.text('Erfundener offizieller Text.'), findsOneWidget);
    expect(find.text('Erster erfundener Hinweis'), findsOneWidget);
    expect(find.text('Hausregel'), findsOneWidget);
    expect(find.text('Erfundene Hausregel-Abweichung.'), findsOneWidget);
    expect(find.text('Beleg: testpaket_v1'), findsOneWidget);
    expect(find.text('Quelle: Testbuch, S. 12'), findsOneWidget);
  });

  testWidgets('Suche und Themenfilter schraenken die Liste ein', (
    tester,
  ) async {
    await zeige(tester, offen);

    await tester.enterText(
      find.byKey(const ValueKey('kurzregeln-suchfeld')),
      'betaubung',
    );
    await tester.pumpAndSettle();
    expect(find.text('Betäubung'), findsOneWidget);
    expect(find.text('Wuchtschlag'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('kurzregeln-suchfeld')),
      'nichtvorhanden',
    );
    await tester.pumpAndSettle();
    expect(find.text('Keine Kurzregel gefunden.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('kurzregeln-suchfeld')),
      '',
    );
    await tester.tap(find.byKey(const ValueKey('kurzregeln-thema-kampf')));
    await tester.pumpAndSettle();
    expect(find.text('Wuchtschlag'), findsOneWidget);
    expect(find.text('Betäubung'), findsNothing);
  });

  testWidgets('leeres Kompendium nennt den Zustand', (tester) async {
    await zeige(tester, const KurzregelKatalog());

    expect(
      find.text('Das Kompendium enthält noch keine Einträge.'),
      findsOneWidget,
    );
  });

  testWidgets('gesperrte Texte zeigen Hinweis statt Chiffretext', (
    tester,
  ) async {
    await zeige(tester, gesperrt);

    expect(find.text('Die Regeltexte sind gesperrt.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('kurzregeln-freischalten')),
      findsOneWidget,
    );

    await tester.tap(find.text('Betäubung'));
    await tester.pumpAndSettle();
    expect(
      find.text('Gesperrt – Katalogpasswort erforderlich.'),
      findsNWidgets(2),
    );
    expect(find.text('Quelle: Testbuch, S. 12'), findsOneWidget);
  });

  testWidgets('echtes Asset ohne Passwort: Liste mit Themen, Texte gesperrt', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [catalogContentPasswordProvider.overrideWithValue(null)],
        child: const MaterialApp(home: Scaffold(body: KurzregelnPanel())),
      ),
    );
    // rootBundle liest echt asynchron; im Fake-Async-Test braucht das echte Zeit.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Die Regeltexte sind gesperrt.'), findsOneWidget);
    expect(find.byKey(const ValueKey('kurzregeln-thema-kampf')), findsOne);
    expect(find.byKey(const ValueKey('kurzregeln-thema-magie')), findsOne);

    await tester.enterText(
      find.byKey(const ValueKey('kurzregeln-suchfeld')),
      'Wuchtschlag',
    );
    await tester.pumpAndSettle();
    // Titel und Schlagworte sind Klartext und damit auch gesperrt auffindbar.
    expect(
      find.byKey(const ValueKey('kurzregel-manoever_wuchtschlag')),
      findsOne,
    );
    expect(tester.takeException(), isNull);
  });

  for (final breite in <double>[320, 390]) {
    testWidgets('läuft bei $breite dp und Textfaktor 2 ohne Überlauf', (
      tester,
    ) async {
      await zeige(tester, offen, breite: breite, skalierung: 2);

      await tester.tap(find.text('Betäubung'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('kurzregeln-thema-kampf')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('gesperrte Liste läuft bei $breite dp, Faktor 2', (
      tester,
    ) async {
      await zeige(tester, gesperrt, breite: breite, skalierung: 2);

      await tester.tap(find.text('Betäubung'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
