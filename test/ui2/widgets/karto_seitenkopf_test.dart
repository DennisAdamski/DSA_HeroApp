import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielraster_bedienung.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_seitenkopf.dart';

Future<void> pumpKopf(WidgetTester tester, KartoSeitenkopf kopf) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildKartoTheme(
        brightness: Brightness.light,
        centerAppBarTitle: false,
      ),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: kopf),
      ),
    ),
  );
}

TextStyle stilVon(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  testWidgets('der Seitentitel nutzt die groesste Schriftrolle', (
    tester,
  ) async {
    await pumpKopf(tester, const KartoSeitenkopf(titel: 'Am Spieltisch'));
    final erwartet = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .theme!
        .textTheme
        .titelGross;
    // Ohne diese Rolle beginnt jede Ansicht bei der Abschnittsgroesse und es
    // entsteht keine Hierarchie. Sie kam vor der Ueberarbeitung nirgends vor.
    expect(stilVon(tester, 'Am Spieltisch').fontSize, erwartet.fontSize);
    expect(stilVon(tester, 'Am Spieltisch').fontFamily, kSchriftTitel);
  });

  testWidgets('kompakt faellt der Titel eine Stufe kleiner aus', (
    tester,
  ) async {
    await pumpKopf(
      tester,
      const KartoSeitenkopf(titel: 'Am Spieltisch', kompakt: true),
    );
    final theme = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .theme!
        .textTheme;
    expect(stilVon(tester, 'Am Spieltisch').fontSize, theme.titel.fontSize);
    expect(theme.titel.fontSize, lessThan(theme.titelGross.fontSize!));
  });

  testWidgets('die Kontextzeile steht ueber dem Titel', (tester) async {
    await pumpKopf(
      tester,
      const KartoSeitenkopf(
        titel: 'Am Spieltisch',
        kontext: 'Die Spuren im Nebel',
      ),
    );
    expect(
      tester.getTopLeft(find.text('Die Spuren im Nebel')).dy,
      lessThan(tester.getTopLeft(find.text('Am Spieltisch')).dy),
    );
  });

  testWidgets('eine leere Kontextzeile erzeugt keine Zeile', (tester) async {
    await pumpKopf(
      tester,
      const KartoSeitenkopf(titel: 'Am Spieltisch', kontext: '   '),
    );
    expect(find.text('   '), findsNothing);
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('Unterzeile und Beschreibung folgen dem Titel', (tester) async {
    await pumpKopf(
      tester,
      const KartoSeitenkopf(
        titel: 'Die Spuren im Nebel',
        kontext: 'Am Spieltisch',
        unterzeile: '12. Phex 1043 BF',
        beschreibung: 'Die Gruppe folgt der Spur des Nebelreiters.',
      ),
    );
    final titel = tester.getTopLeft(find.text('Die Spuren im Nebel')).dy;
    final datum = tester.getTopLeft(find.text('12. Phex 1043 BF')).dy;
    final text = tester
        .getTopLeft(find.text('Die Gruppe folgt der Spur des Nebelreiters.'))
        .dy;
    expect(datum, greaterThan(titel));
    expect(text, greaterThan(datum));
  });

  testWidgets('leere Zusatzzeilen erzeugen keine Zeile', (tester) async {
    await pumpKopf(
      tester,
      const KartoSeitenkopf(
        titel: 'Am Spieltisch',
        unterzeile: ' ',
        beschreibung: '  ',
      ),
    );
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('die Beschreibung bleibt eine kurze Gedaechtnisstuetze', (
    tester,
  ) async {
    await pumpKopf(
      tester,
      const KartoSeitenkopf(titel: 'Am Spieltisch', beschreibung: 'Lang'),
    );
    expect(tester.widget<Text>(find.text('Lang')).maxLines, 3);
    await pumpKopf(
      tester,
      const KartoSeitenkopf(
        titel: 'Am Spieltisch',
        beschreibung: 'Lang',
        kompakt: true,
      ),
    );
    expect(tester.widget<Text>(find.text('Lang')).maxLines, 2);
  });

  testWidgets('mit onTap ist der ganze Kopf die Klickflaeche', (tester) async {
    var getippt = 0;
    await pumpKopf(
      tester,
      KartoSeitenkopf(
        titel: 'Die Spuren im Nebel',
        kontext: 'Am Spieltisch',
        beschreibung: 'Die Gruppe folgt der Spur.',
        tippHinweis: 'Abenteuer öffnen',
        onTap: () => getippt++,
      ),
    );
    await tester.tap(find.text('Die Gruppe folgt der Spur.'));
    await tester.tap(find.text('Die Spuren im Nebel'));
    expect(getippt, 2);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byTooltip('Abenteuer öffnen'), findsOneWidget);
    // Der Titel bleibt ein eigener Text in der grossen Rolle.
    final theme = Theme.of(tester.element(find.text('Die Spuren im Nebel')));
    expect(
      stilVon(tester, 'Die Spuren im Nebel').fontSize,
      theme.textTheme.titelGross.fontSize,
    );
  });

  testWidgets('ohne onTap gibt es weder Pfeil noch Klickflaeche', (
    tester,
  ) async {
    await pumpKopf(tester, const KartoSeitenkopf(titel: 'Am Spieltisch'));
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('die Seitenaktion steht rechts neben dem Titel', (tester) async {
    await pumpKopf(
      tester,
      KartoSeitenkopf(
        titel: 'Nächste Schritte',
        aktion: FilledButton(onPressed: () {}, child: const Text('Übernehmen')),
      ),
    );
    final titel = tester.getTopLeft(find.text('Nächste Schritte'));
    final aktion = tester.getTopLeft(find.text('Übernehmen'));
    expect(aktion.dx, greaterThan(titel.dx));
  });

  testWidgets('der Kopf trennt ohne Linie', (tester) async {
    // Eine Regel unter jeder Ueberschrift ergaebe zusammen mit den
    // Abschnittskanten ein Liniengitter; getrennt wird hier durch Weissraum.
    await pumpKopf(tester, const KartoSeitenkopf(titel: 'Am Spieltisch'));
    expect(find.byType(Divider), findsNothing);
  });

  group('feste Mitte neben dem Titel', () {
    const mitteSchluessel = ValueKey<String>('test-mitte');

    // Wie die Schnellaktionen: eine Leiste, die umbrechen darf.
    Widget mitteLeiste() => Wrap(
      key: mitteSchluessel,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final name in [
          'Probe suchen',
          'Regeln',
          'Rast',
          'Schaden',
          'Gefecht',
        ])
          OutlinedButton(onPressed: () {}, child: Text(name)),
      ],
    );

    Future<void> zeigeKopf(
      WidgetTester tester, {
      required double breite,
      required double skalierung,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(breite, 900);
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
            body: Align(
              alignment: Alignment.topLeft,
              child: KartoSeitenkopf(
                titel: 'Am Spieltisch',
                mitte: mitteLeiste(),
                // Die Aktion des Anordnen-Modus ist die breiteste.
                aktion: KartoAnordnenAbschluss(
                  speichert: false,
                  onStandard: () {},
                  onAbbrechen: () {},
                  onFertig: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Ob die Mitte in der Zeile des Titels steht (sonst darunter).
    bool nebenTitel(WidgetTester tester) {
      final titel = tester.getRect(find.text('Am Spieltisch'));
      final mitte = tester.getRect(find.byKey(mitteSchluessel));
      return mitte.top < titel.bottom;
    }

    for (final breite in [1200.0, 1440.0, 1920.0]) {
      for (final skalierung in [1.0, 1.3, 1.5, 2.0]) {
        testWidgets('bei $breite dp und Schrift $skalierung ohne Überlauf', (
          tester,
        ) async {
          await zeigeKopf(tester, breite: breite, skalierung: skalierung);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('normale Schrift: ab 1200 dp neben dem Titel', (tester) async {
      await zeigeKopf(tester, breite: 1200, skalierung: 1);
      expect(nebenTitel(tester), isTrue);
    });

    testWidgets('normale Schrift: unter 1200 dp unter dem Titel', (
      tester,
    ) async {
      await zeigeKopf(tester, breite: 1100, skalierung: 1);
      expect(nebenTitel(tester), isFalse);
    });

    testWidgets('große Schrift rückt die Mitte unter den Titel', (
      tester,
    ) async {
      await zeigeKopf(tester, breite: 1440, skalierung: 2);
      expect(nebenTitel(tester), isFalse);
      // Mit genug Breite steht sie auch dann wieder daneben.
      await zeigeKopf(tester, breite: 2600, skalierung: 2);
      expect(nebenTitel(tester), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('die Schwelle wächst mit der Schrift', (tester) async {
      await zeigeKopf(tester, breite: 1440, skalierung: 1.5);
      expect(nebenTitel(tester), isFalse);
      await zeigeKopf(tester, breite: 1920, skalierung: 1.5);
      expect(nebenTitel(tester), isTrue);
    });

    testWidgets('kleinere Schrift senkt die Schwelle nicht', (tester) async {
      await zeigeKopf(tester, breite: 1100, skalierung: 0.8);
      expect(nebenTitel(tester), isFalse);
    });
  });
}
