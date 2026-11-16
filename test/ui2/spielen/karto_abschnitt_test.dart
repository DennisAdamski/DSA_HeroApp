import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

/// Kopf-Bedienung einer Kachel (Vergrößern, Einklappen): mit Maus nur bei
/// Hover sichtbar, ohne Maus immer; dazu das Füllen einer gedehnten Kachel.
void main() {
  Future<void> zeige(
    WidgetTester tester, {
    bool eingeklappt = false,
    KartoAkzent? akzent,
    double? hoehe,
  }) async {
    final abschnitt = KartoKachelSteuerung(
      kennung: 'test',
      eingeklappt: eingeklappt,
      onEinklappen: (_) {},
      onVergroessern: () {},
      child: KartoAbschnitt(
        key: const ValueKey<String>('abschnitt'),
        titel: 'Kampf',
        akzent: akzent,
        child: const Text('Inhalt'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKartoTheme(
          brightness: Brightness.light,
          centerAppBarTitle: false,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 320, height: hoehe, child: abschnitt),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double deckkraft(WidgetTester tester, Finder ziel) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(of: ziel, matching: find.byType(AnimatedOpacity)).first,
      )
      .opacity;

  final pfeil = find.byKey(
    const ValueKey<String>('karto-kachel-test-einklappen'),
  );
  final vergroessern = find.byIcon(Icons.open_in_full);

  testWidgets('ohne Maus bleibt die Kopf-Bedienung sichtbar', (tester) async {
    await zeige(tester);
    expect(deckkraft(tester, pfeil), 1);
    expect(deckkraft(tester, vergroessern), 1);
  });

  testWidgets('mit Maus erscheint sie erst über der Kachel', (tester) async {
    final maus = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await maus.addPointer(location: const Offset(700, 500));
    addTearDown(maus.removePointer);
    await zeige(tester);
    expect(deckkraft(tester, pfeil), 0);
    expect(deckkraft(tester, vergroessern), 0);

    await maus.moveTo(tester.getCenter(find.text('Inhalt')));
    await tester.pumpAndSettle();
    expect(deckkraft(tester, pfeil), 1);
    expect(deckkraft(tester, vergroessern), 1);

    await maus.moveTo(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(deckkraft(tester, pfeil), 0);
  });

  testWidgets('eingeklappt bleibt der Pfeil auch mit Maus stehen', (
    tester,
  ) async {
    final maus = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await maus.addPointer(location: const Offset(700, 500));
    addTearDown(maus.removePointer);
    await zeige(tester, eingeklappt: true);
    expect(deckkraft(tester, pfeil), 1);
  });

  for (final akzent in [null, KartoAkzent.messing]) {
    testWidgets('eine gedehnte Kachel füllt ihre Höhe (Akzent $akzent)', (
      tester,
    ) async {
      await zeige(tester, akzent: akzent, hoehe: 400);
      final flaeche = find.descendant(
        of: find.byKey(const ValueKey<String>('abschnitt')),
        matching: find.byType(DecoratedBox),
      );
      expect(tester.getSize(flaeche.first).height, 400);
    });
  }
}
