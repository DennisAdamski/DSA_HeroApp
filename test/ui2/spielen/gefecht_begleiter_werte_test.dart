import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/begleiter_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_begleiter.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

/// Das Gefecht zeigt die laufenden Werte der Begleiter (V2), sonst nichts
/// Neues: Handelnde Begleiter kommen erst mit V3.
void main() {
  const mira = HeroCompanion(
    id: 'mira',
    name: 'Mira',
    typ: BegleiterTyp.vertrauter,
    maxLep: 24,
    startLep: 24,
    maxAsp: 10,
    startAsp: 10,
  );

  Future<void> zeige(
    WidgetTester tester,
    Map<String, BegleiterZustand> zustaende,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKartoTheme(
          brightness: Brightness.light,
          centerAppBarTitle: false,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: GefechtBegleiter(
              begleiter: const [mira],
              zustaende: zustaende,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gefecht-begleiter-mira')));
    await tester.pumpAndSettle();
  }

  testWidgets('zeigt gespeicherte und volle Werte', (tester) async {
    await zeige(tester, const {'mira': BegleiterZustand(currentLep: 17)});
    expect(
      find.byKey(const ValueKey('gefecht-begleiter-laufend-mira')),
      findsOneWidget,
    );
    expect(find.text('Aktuell: LeP 17/24 · AsP 10/10'), findsOneWidget);
  });

  testWidgets('ohne Eintrag sind die Werte voll', (tester) async {
    await zeige(tester, const {});
    expect(find.text('Aktuell: LeP 24/24 · AsP 10/10'), findsOneWidget);
  });
}
