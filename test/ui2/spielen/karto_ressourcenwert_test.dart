import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/spielen/karto_ressourcenwert.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

void main() {
  Future<void> zeige(
    WidgetTester tester, {
    String bezeichnung = 'Lebenspunkte',
    required int aktuell,
    required int maximum,
    VoidCallback? onBearbeiten,
    double breite = 320,
    double skalierung = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, 400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKartoTheme(
          brightness: Brightness.light,
          centerAppBarTitle: false,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(skalierung)),
          child: child!,
        ),
        home: Scaffold(
          body: KartoRessourcenwert(
            bezeichnung: bezeichnung,
            aktuell: aktuell,
            maximum: maximum,
            onBearbeiten: onBearbeiten,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Ressource nennt Wert und Maximum und öffnet Bearbeitung', (
    tester,
  ) async {
    var geoeffnet = false;
    await zeige(
      tester,
      aktuell: 23,
      maximum: 35,
      onBearbeiten: () => geoeffnet = true,
    );
    expect(find.text('23 / 35'), findsOneWidget);
    expect(find.text('Lebenspunkte'), findsOneWidget);
    await tester.tap(find.byTooltip('Lebenspunkte ändern'));
    expect(geoeffnet, isTrue);
  });

  testWidgets('ohne Rückruf gibt es kein Bearbeitungsziel', (tester) async {
    await zeige(tester, aktuell: 23, maximum: 35);
    expect(find.byTooltip('Lebenspunkte ändern'), findsNothing);
    expect(find.text('23 / 35'), findsOneWidget);
  });

  testWidgets('negativer Wert bleibt lesbar und leert den Balken', (
    tester,
  ) async {
    await zeige(tester, aktuell: -3, maximum: 35);
    expect(find.text('-3 / 35'), findsOneWidget);
    final balken = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(balken.value, 0);
  });

  testWidgets('Maximum 0 zeigt den Wert ohne Division', (tester) async {
    await zeige(tester, bezeichnung: 'Karmapunkte', aktuell: 0, maximum: 0);
    expect(find.text('0 / 0'), findsOneWidget);
    final balken = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(balken.value, 0);
  });

  testWidgets('Überheilung füllt den Balken ohne den Wert zu kürzen', (
    tester,
  ) async {
    await zeige(tester, aktuell: 40, maximum: 35);
    expect(find.text('40 / 35'), findsOneWidget);
    final balken = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(balken.value, 1);
  });

  testWidgets('Bearbeitungsziel ist mindestens 48 dp groß', (tester) async {
    await zeige(tester, aktuell: 23, maximum: 35, onBearbeiten: () {});
    final groesse = tester.getSize(find.byTooltip('Lebenspunkte ändern'));
    expect(groesse.width, greaterThanOrEqualTo(48));
    expect(groesse.height, greaterThanOrEqualTo(48));
  });

  testWidgets('langer Name und Textskalierung 2 laufen nicht über', (
    tester,
  ) async {
    await zeige(
      tester,
      bezeichnung: 'Astralenergie der Gildenmagierin',
      aktuell: 128,
      maximum: 140,
      onBearbeiten: () {},
      breite: 200,
      skalierung: 2,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('128 / 140'), findsOneWidget);
  });
}
