import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/shell/karto_heldenmarke.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_ornamente.dart';

Future<void> pumpMarke(WidgetTester tester, KartoHeldenmarke marke) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildKartoTheme(
        brightness: Brightness.light,
        centerAppBarTitle: false,
      ),
      home: Scaffold(
        backgroundColor: kartoHell.navigation,
        body: SizedBox(width: 240, child: marke),
      ),
    ),
  );
}

void main() {
  testWidgets('ohne Bild steht das Monogramm in der Fassung', (tester) async {
    await pumpMarke(
      tester,
      const KartoHeldenmarke(name: 'Rondra', herkunft: 'Geweihte'),
    );
    expect(find.text('R'), findsOneWidget);
    expect(find.text('Rondra'), findsOneWidget);
    expect(find.text('Geweihte'), findsOneWidget);
  });

  testWidgets('das Bild bekommt das Monogramm als Ersatz gereicht', (
    tester,
  ) async {
    Widget? gereichterErsatz;
    await pumpMarke(
      tester,
      KartoHeldenmarke(
        name: 'Rondra',
        bild: (ersatz) {
          gereichterErsatz = ersatz;
          return const Text('Bildinhalt');
        },
      ),
    );
    // Die Bruecke zeigt den Ersatz selbst an, sobald ein Bild fehlt oder nicht
    // ladbar ist. Sie darf dafuer keinen eigenen Platzhalter erfinden.
    expect(gereichterErsatz, isNotNull);
    expect(find.text('Bildinhalt'), findsOneWidget);
    expect(find.text('R'), findsNothing);
  });

  testWidgets('Bild und Monogramm tragen dieselbe runde Fassung', (
    tester,
  ) async {
    Set<Object?> fassungen() => tester
        .widgetList<KartoKompassring>(find.byType(KartoKompassring))
        .map((ring) => (ring.farbe, ring.groesse, ring.schein))
        .toSet();

    await pumpMarke(tester, const KartoHeldenmarke(name: 'Rondra'));
    final ohneBild = fassungen();
    await pumpMarke(
      tester,
      KartoHeldenmarke(name: 'Rondra', bild: (_) => const Text('Bildinhalt')),
    );
    expect(ohneBild, <Object?>{(kartoHell.messingNavigation, 112.0, true)});
    expect(fassungen(), ohneBild);
    // Der Inhalt ist rund beschnitten und liegt innerhalb des Rings.
    expect(
      find.ancestor(
        of: find.text('Bildinhalt'),
        matching: find.byType(ClipOval),
      ),
      findsOneWidget,
    );
  });

  test('ein Bild fuellt die Fassung bis an den Ring', () {
    final innen = KartoHeldenmarke.bildGroesse(112);
    expect(innen, 112 - 2 * KartoKompassring.randFuer(112));
    expect(innen, greaterThan(80));
  });

  testWidgets('ein leerer Name laesst die Fassung nicht leer stehen', (
    tester,
  ) async {
    await pumpMarke(tester, const KartoHeldenmarke(name: '   '));
    expect(find.text('?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('eine leere Herkunft erzeugt keine Zeile', (tester) async {
    await pumpMarke(
      tester,
      const KartoHeldenmarke(name: 'Rondra', herkunft: '  '),
    );
    expect(find.text('  '), findsNothing);
  });

  testWidgets('ein langer Name bleibt bei doppelter Schrift im Rahmen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKartoTheme(
          brightness: Brightness.dark,
          centerAppBarTitle: false,
        ),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const Scaffold(
            body: KartoHeldenmarke(
              name: 'Rondra Alrike von Gareth und den Silberquellen',
              herkunft: 'Reisende Gelehrte aus dem Mittelreich',
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
