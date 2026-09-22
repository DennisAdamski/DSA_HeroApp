import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';

const _inhalt = ValueKey<String>('inhalt');

Future<BoxDecoration> pumpFlaeche(
  WidgetTester tester,
  KartoFlaeche flaeche, {
  Brightness helligkeit = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildKartoTheme(brightness: helligkeit, centerAppBarTitle: false),
      home: Scaffold(body: Center(child: flaeche)),
    ),
  );
  final box = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.byKey(_inhalt), matching: find.byType(DecoratedBox))
        .first,
  );
  return box.decoration as BoxDecoration;
}

void main() {
  group('Flaechenstufen', () {
    testWidgets('jede Stufe nimmt ihr Token aus dem Theme', (tester) async {
      for (final fall in <(KartoFlaechenstufe, Color)>[
        (KartoFlaechenstufe.senke, kartoHell.senke),
        (KartoFlaechenstufe.blatt, kartoHell.blatt),
        (KartoFlaechenstufe.feld, kartoHell.feld),
      ]) {
        final dekoration = await pumpFlaeche(
          tester,
          KartoFlaeche(
            stufe: fall.$1,
            child: const SizedBox(key: _inhalt, width: 40, height: 40),
          ),
        );
        expect(dekoration.color, fall.$2, reason: 'Stufe ${fall.$1.name}');
      }
    });

    testWidgets('die dunkle Palette dreht die Richtung, nicht die Rolle', (
      tester,
    ) async {
      final senke = await pumpFlaeche(
        tester,
        const KartoFlaeche(
          stufe: KartoFlaechenstufe.senke,
          child: SizedBox(key: _inhalt, width: 40, height: 40),
        ),
        helligkeit: Brightness.dark,
      );
      final feld = await pumpFlaeche(
        tester,
        const KartoFlaeche(
          child: SizedBox(key: _inhalt, width: 40, height: 40),
        ),
        helligkeit: Brightness.dark,
      );
      expect(senke.color, kartoDunkel.senke);
      expect(feld.color, kartoDunkel.feld);
      // Hell tritt `feld` durch mehr Helligkeit hervor, dunkel durch weniger
      // Dunkelheit. Die Rolle bleibt in beiden Paletten dieselbe.
      expect(
        kartoHell.feld.computeLuminance(),
        greaterThan(kartoHell.senke.computeLuminance()),
      );
      expect(
        kartoDunkel.feld.computeLuminance(),
        greaterThan(kartoDunkel.senke.computeLuminance()),
      );
    });
  });

  group('Kante', () {
    testWidgets('jedes Strichgewicht bleibt an sein Farbtoken gepaart', (
      tester,
    ) async {
      for (final fall in <(StrichGewicht, Color, double)>[
        (StrichGewicht.hoehenlinie, kartoHell.hoehenlinie, Strich.hoehenlinie),
        (StrichGewicht.grat, kartoHell.grat, Strich.grat),
        (StrichGewicht.kueste, kartoHell.kueste, Strich.kueste),
      ]) {
        final dekoration = await pumpFlaeche(
          tester,
          KartoFlaeche(
            kante: fall.$1,
            child: const SizedBox(key: _inhalt, width: 40, height: 40),
          ),
        );
        expect(dekoration.border!.top.color, fall.$2);
        expect(dekoration.border!.top.width, fall.$3);
      }
    });

    testWidgets('ohne Kante bleibt nur die Flaeche', (tester) async {
      final dekoration = await pumpFlaeche(
        tester,
        const KartoFlaeche(
          kante: null,
          child: SizedBox(key: _inhalt, width: 40, height: 40),
        ),
      );
      expect(dekoration.border, isNull);
      expect(dekoration.color, kartoHell.feld);
    });
  });

  testWidgets('kleine Bedienelemente bekommen den kleineren Radius', (
    tester,
  ) async {
    final gross = await pumpFlaeche(
      tester,
      const KartoFlaeche(child: SizedBox(key: _inhalt, width: 40, height: 40)),
    );
    final klein = await pumpFlaeche(
      tester,
      const KartoFlaeche(
        klein: true,
        child: SizedBox(key: _inhalt, width: 40, height: 40),
      ),
    );
    expect(gross.borderRadius, BorderRadius.circular(kKartoRadius));
    expect(klein.borderRadius, BorderRadius.circular(kKartoRadiusKlein));
    expect(kKartoRadiusKlein, lessThan(kKartoRadius));
  });

  testWidgets('ohne Kartograph-Theme rendert die Flaeche trotzdem', (
    tester,
  ) async {
    // KartoTheme.of faellt bewusst auf die helle Palette zurueck, statt zu
    // werfen. Ein Primitiv darf eine Vorschau nicht zum Absturz bringen.
    await tester.pumpWidget(
      const MaterialApp(
        home: KartoFlaeche(
          child: SizedBox(key: _inhalt, width: 40, height: 40),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final box = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byKey(_inhalt),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((box.decoration as BoxDecoration).color, kartoHell.feld);
  });
}
