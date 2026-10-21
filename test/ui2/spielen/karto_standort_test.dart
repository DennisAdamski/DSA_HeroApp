import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/spielen/karto_standort.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

/// Standortzeile: Anzeige, Eingabe und Kartenlink.
void main() {
  Future<void> zeige(
    WidgetTester tester, {
    String standort = '',
    required List<String> gespeichert,
    List<Uri>? geoeffnet,
    bool oeffnenGelingt = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKartoTheme(
          brightness: Brightness.light,
          centerAppBarTitle: false,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: KartoStandortZeile(
              standort: standort,
              onSpeichern: (text) async => gespeichert.add(text),
              oeffneLink: (uri) async {
                geoeffnet?.add(uri);
                return oeffnenGelingt;
              },
            ),
          ),
        ),
      ),
    );
  }

  Finder schluessel(String name) => find.byKey(ValueKey<String>(name));

  testWidgets('ohne Standort: Hinweis, kein Kartenlink', (tester) async {
    await zeige(tester, gespeichert: []);

    expect(schluessel('karto-spiel-standort-leer'), findsOneWidget);
    expect(schluessel('karto-spiel-standort-karte'), findsNothing);
    expect(find.text('Standort festhalten'), findsOneWidget);
  });

  testWidgets('mit Standort: Name und Link auf Avesmaps', (tester) async {
    final geoeffnet = <Uri>[];
    await zeige(
      tester,
      standort: 'Gareth',
      gespeichert: [],
      geoeffnet: geoeffnet,
    );

    expect(find.text('Gareth'), findsOneWidget);
    expect(schluessel('karto-spiel-standort-aendern'), findsOneWidget);

    await tester.tap(schluessel('karto-spiel-standort-karte'));
    await tester.pump();

    expect(geoeffnet.single.toString(), 'https://avesmaps.de/?siedlung=Gareth');
  });

  testWidgets('scheitert das Öffnen, erscheint eine Meldung', (tester) async {
    await zeige(
      tester,
      standort: 'Gareth',
      gespeichert: [],
      oeffnenGelingt: false,
    );

    await tester.tap(schluessel('karto-spiel-standort-karte'));
    await tester.pump();

    expect(
      find.text('Die Karte konnte nicht geöffnet werden.'),
      findsOneWidget,
    );
  });

  testWidgets('Eingabe wird bereinigt gespeichert', (tester) async {
    final gespeichert = <String>[];
    await zeige(tester, gespeichert: gespeichert);

    await tester.tap(schluessel('karto-spiel-standort-aendern'));
    await tester.pumpAndSettle();
    await tester.enterText(
      schluessel('karto-spiel-standort-feld'),
      '  Bad   Garetz ',
    );
    await tester.tap(schluessel('karto-spiel-standort-speichern'));
    await tester.pumpAndSettle();

    expect(gespeichert, ['Bad Garetz']);
  });

  testWidgets('Abbrechen speichert nichts', (tester) async {
    final gespeichert = <String>[];
    await zeige(tester, standort: 'Gareth', gespeichert: gespeichert);

    await tester.tap(schluessel('karto-spiel-standort-aendern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(gespeichert, isEmpty);
  });

  testWidgets('Entfernen speichert einen leeren Standort', (tester) async {
    final gespeichert = <String>[];
    await zeige(tester, standort: 'Gareth', gespeichert: gespeichert);

    await tester.tap(schluessel('karto-spiel-standort-aendern'));
    await tester.pumpAndSettle();
    await tester.tap(schluessel('karto-spiel-standort-entfernen'));
    await tester.pumpAndSettle();

    expect(gespeichert, ['']);
  });
}
