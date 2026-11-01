import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_anzeige_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/merkmale/karto_merkmal_karten.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

MerkmalAnzeige _anzeige(
  String kurz, {
  List<String> wirkungen = const [],
  MerkmalHerkunft herkunft = MerkmalHerkunft.katalog,
}) => MerkmalAnzeige(
  art: 'Vorteil',
  name: kurz,
  detail: '',
  wirkungen: wirkungen,
  herkunft: herkunft,
  kurz: kurz,
);

void main() {
  Future<void> zeige(
    WidgetTester tester, {
    required List<MerkmalAnzeige> vorteile,
    List<MerkmalAnzeige> nachteile = const [],
    double breite = 300,
    bool mitUmschalter = true,
  }) async {
    var aufgeklappt = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKartoTheme(
          brightness: Brightness.light,
          centerAppBarTitle: false,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: breite,
              child: StatefulBuilder(
                builder: (context, setState) => KartoMerkmalsuebersicht(
                  vorteile: vorteile,
                  nachteile: nachteile,
                  aufgeklappt: aufgeklappt,
                  onUmschalten: mitUmschalter
                      ? (wert) => setState(() => aufgeklappt = wert)
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> umschalten(WidgetTester tester) async {
    final knopf = find.byKey(const ValueKey('karto-spiel-merkmale-umschalten'));
    await tester.ensureVisible(knopf);
    await tester.tap(knopf);
    await tester.pumpAndSettle();
  }

  final viele = [
    for (var i = 1; i <= 12; i++)
      _anzeige('Sehr langer Vorteil $i', wirkungen: ['LeP +$i']),
  ];

  testWidgets('eingeklappt hat je Art höchstens eine Zeile', (tester) async {
    await zeige(
      tester,
      vorteile: viele,
      nachteile: [_anzeige('Goldgier 6'), _anzeige('Jähzorn 5')],
    );
    final zeilen = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.maxLines == 1 && t.overflow == TextOverflow.ellipsis);
    expect(zeilen, hasLength(2));
    // Die Vorteilzeile ist hoeher als eine Zeile nie: ein Text.rich mit Ellipse.
    final hoehe = tester.getSize(find.textContaining('Vorteile  ')).height;
    final nachteilHoehe = tester
        .getSize(find.textContaining('Nachteile  '))
        .height;
    expect(hoehe, nachteilHoehe);
    // Wirkungstexte erscheinen erst aufgeklappt.
    expect(find.text('LeP +1'), findsNothing);
  });

  testWidgets('aufgeklappt zeigt jeden Eintrag mit Wirkung', (tester) async {
    await zeige(tester, vorteile: viele);
    expect(find.text('Alle zeigen (12)'), findsOneWidget);

    await umschalten(tester);

    expect(find.text('Einklappen'), findsOneWidget);
    for (var i = 1; i <= 12; i++) {
      expect(find.text('Sehr langer Vorteil $i'), findsOneWidget);
      expect(find.text('LeP +$i'), findsOneWidget);
    }

    await umschalten(tester);
    expect(find.text('Alle zeigen (12)'), findsOneWidget);
    expect(find.text('LeP +1'), findsNothing);
  });

  testWidgets('offene Zuordnung trägt in beiden Ansichten ein (?)', (
    tester,
  ) async {
    await zeige(
      tester,
      vorteile: [_anzeige('Flink', herkunft: MerkmalHerkunft.pruefen)],
    );
    expect(find.textContaining('Flink (?)'), findsOneWidget);
    await umschalten(tester);
    expect(find.text('Flink (?)'), findsOneWidget);
  });

  testWidgets('ohne Aufrufer entfällt der Umschalter', (tester) async {
    await zeige(tester, vorteile: viele, mitUmschalter: false);
    expect(
      find.byKey(const ValueKey('karto-spiel-merkmale-umschalten')),
      findsNothing,
    );
  });

  testWidgets('leere Listen zeigen nur den Leerhinweis', (tester) async {
    await zeige(tester, vorteile: const []);
    expect(find.text('Keine Einträge.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('karto-spiel-merkmale-umschalten')),
      findsNothing,
    );
  });
}
