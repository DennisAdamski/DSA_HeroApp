import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_anzeige_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/merkmale/karto_merkmal_karten.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';
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
    KartoKachelGroesse? groesse,
    bool startAufgeklappt = false,
    double schrift = 1,
  }) async {
    var aufgeklappt = startAufgeklappt;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKartoTheme(
          brightness: Brightness.light,
          centerAppBarTitle: false,
        ),
        builder: (context, kind) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(schrift)),
          child: kind!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: breite,
              child: StatefulBuilder(
                builder: (context, setState) {
                  final uebersicht = KartoMerkmalsuebersicht(
                    vorteile: vorteile,
                    nachteile: nachteile,
                    aufgeklappt: aufgeklappt,
                    onUmschalten: mitUmschalter
                        ? (wert) => setState(() => aufgeklappt = wert)
                        : null,
                  );
                  return groesse == null
                      ? uebersicht
                      : KartoKachelSteuerung(
                          kennung: 'merkmale-test',
                          groesse: groesse,
                          child: uebersicht,
                        );
                },
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

  group('weite Stufe', () {
    double zeilenHoehe(WidgetTester tester, String anfang) =>
        tester.getSize(find.textContaining(anfang)).height;

    testWidgets('eingeklappt zeigt bis zu drei Zeilen je Art', (tester) async {
      for (final (groesse, zeilen) in [
        (KartoKachelGroesse.kompakt, 1),
        (KartoKachelGroesse.normal, 1),
        (KartoKachelGroesse.weit, kMerkmaleZeilenWeit),
      ]) {
        await zeige(
          tester,
          vorteile: viele,
          nachteile: [for (var i = 1; i <= 12; i++) _anzeige('Nachteil $i')],
          breite: 640,
          groesse: groesse,
        );
        final zeile = tester
            .widgetList<Text>(find.byType(Text))
            .firstWhere((t) => t.maxLines != null);
        expect(zeile.maxLines, zeilen, reason: '$groesse');
      }
      final eine = zeilenHoehe(tester, 'Vorteile  ');
      // Bei weit ist die Vorteilzeile hoeher als eine Zeile, aber nie hoeher
      // als drei.
      expect(eine, greaterThan(20));
      expect(find.text('LeP +1'), findsNothing);
    });

    testWidgets('weit zeigt mehr Einträge als normal', (tester) async {
      Future<double> hoehe(KartoKachelGroesse groesse) async {
        await zeige(
          tester,
          vorteile: viele,
          breite: 640,
          groesse: groesse,
          mitUmschalter: false,
        );
        return zeilenHoehe(tester, 'Vorteile  ');
      }

      final normal = await hoehe(KartoKachelGroesse.normal);
      final weit = await hoehe(KartoKachelGroesse.weit);
      expect(weit, greaterThan(normal * 2));
      expect(weit, lessThanOrEqualTo(normal * kMerkmaleZeilenWeit + 1));
    });

    testWidgets('aufgeklappt stehen Vorteile und Nachteile nebeneinander', (
      tester,
    ) async {
      await zeige(
        tester,
        vorteile: [
          _anzeige('Flink', wirkungen: ['LeP +1']),
        ],
        nachteile: [_anzeige('Goldgier 6')],
        breite: 640,
        groesse: KartoKachelGroesse.weit,
        startAufgeklappt: true,
      );
      expect(
        find.byKey(const ValueKey('karto-merkmale-spalten')),
        findsOneWidget,
      );
      final vorteile = tester.getTopLeft(find.text('Vorteile'));
      final nachteile = tester.getTopLeft(find.text('Nachteile'));
      expect(vorteile.dy, nachteile.dy);
      expect(nachteile.dx, greaterThan(vorteile.dx + 200));
      expect(find.text('LeP +1'), findsOneWidget);
    });

    testWidgets('mit nur einer Art oder in schmaleren Stufen untereinander', (
      tester,
    ) async {
      await zeige(
        tester,
        vorteile: [_anzeige('Flink')],
        breite: 640,
        groesse: KartoKachelGroesse.weit,
        startAufgeklappt: true,
      );
      expect(
        find.byKey(const ValueKey('karto-merkmale-spalten')),
        findsNothing,
      );
      for (final groesse in [
        null,
        KartoKachelGroesse.kompakt,
        KartoKachelGroesse.normal,
      ]) {
        await zeige(
          tester,
          vorteile: [_anzeige('Flink')],
          nachteile: [_anzeige('Goldgier 6')],
          breite: 640,
          groesse: groesse,
          startAufgeklappt: true,
        );
        expect(
          find.byKey(const ValueKey('karto-merkmale-spalten')),
          findsNothing,
          reason: '$groesse',
        );
        expect(
          tester.getTopLeft(find.text('Nachteile')).dy,
          greaterThan(tester.getTopLeft(find.text('Vorteile')).dy),
        );
      }
    });

    for (final breite in [600.0, 744.0, 1024.0, 1440.0]) {
      for (final schrift in [1.0, 2.0]) {
        testWidgets('ohne Überlauf bei $breite dp und Schrift $schrift', (
          tester,
        ) async {
          for (final aufgeklappt in [false, true]) {
            await zeige(
              tester,
              vorteile: viele,
              nachteile: [
                for (var i = 1; i <= 12; i++)
                  _anzeige(
                    'Nachteil mit langem Namen $i',
                    wirkungen: ['MR -1'],
                  ),
              ],
              breite: breite,
              groesse: KartoKachelGroesse.weit,
              startAufgeklappt: aufgeklappt,
              schrift: schrift,
            );
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  });
}
