import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
