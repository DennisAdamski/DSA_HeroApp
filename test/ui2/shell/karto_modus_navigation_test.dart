import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/shell/karto_arbeitsbereich.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_modus_navigation.dart';

void main() {
  testWidgets('Screenreader und Tastatur können die Ziele aktivieren', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    KartoArbeitsbereich? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KartoModusNavigation(
            bereich: KartoArbeitsbereich.spielen,
            kompakt: false,
            onAuswahl: (value) => selected = value,
          ),
        ),
      ),
    );
    final ziel = find.bySemanticsLabel('Spielen');
    final data = tester.getSemantics(ziel).getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester.getSemantics(ziel).getSemanticsData().flagsCollection.isFocused,
      Tristate.isTrue,
    );
    expect(find.byKey(const ValueKey('karto-fokus-spielen')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected, KartoArbeitsbereich.spielen);
    semantics.dispose();
  });

  testWidgets('drei Modi sind erreichbar und melden die Auswahl', (
    tester,
  ) async {
    KartoArbeitsbereich? gewaehlt;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KartoModusNavigation(
            bereich: KartoArbeitsbereich.spielen,
            kompakt: false,
            onAuswahl: (wert) => gewaehlt = wert,
          ),
        ),
      ),
    );
    expect(find.text('Spielen'), findsOneWidget);
    expect(find.text('Held verwalten'), findsOneWidget);
    await tester.tap(find.text('Entwicklung planen'));
    expect(gewaehlt, KartoArbeitsbereich.entwickeln);
  });

  testWidgets('kompakte Ziele behalten vollstaendige semantische Namen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KartoModusNavigation(
            bereich: KartoArbeitsbereich.verwalten,
            kompakt: true,
            onAuswahl: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Verwalten'), findsOneWidget);
    expect(find.text('Planen'), findsOneWidget);
    expect(find.bySemanticsLabel('Held verwalten'), findsOneWidget);
    expect(find.bySemanticsLabel('Entwicklung planen'), findsOneWidget);
  });

  testWidgets('vorgemerkte Steigerungen stehen als Marke an der Planung', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    Future<void> zeige(int vorgemerkt, {required bool kompakt}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KartoModusNavigation(
              bereich: KartoArbeitsbereich.spielen,
              kompakt: kompakt,
              vorgemerkt: vorgemerkt,
              onAuswahl: (_) {},
            ),
          ),
        ),
      );
    }

    await zeige(0, kompakt: false);
    expect(find.byKey(const ValueKey('karto-marke-entwickeln')), findsNothing);

    for (final kompakt in <bool>[false, true]) {
      await zeige(2, kompakt: kompakt);
      expect(
        find.byKey(const ValueKey('karto-marke-entwickeln')),
        findsOneWidget,
      );
      expect(find.text('2'), findsOneWidget);
      // Der Name bleibt unveraendert; die Zahl steht als Wert daneben, damit
      // bestehende Bedienpruefungen das Ziel weiter unter seinem Namen finden.
      final daten = tester
          .getSemantics(find.bySemanticsLabel('Entwicklung planen'))
          .getSemanticsData();
      expect(daten.value, '2 vorgemerkt');
    }
    semantics.dispose();
  });
}
