import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_ort_feld.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

/// Ortsfeld: Vorschläge aus dem Verzeichnis, Freitext bleibt erlaubt.
void main() {
  final orte = <OrtEintrag>[
    OrtEintrag(name: 'Gareth', art: OrtArt.siedlung, region: 'Garetien'),
    OrtEintrag(name: 'Garetien', art: OrtArt.region),
    OrtEintrag(name: 'Havena', art: OrtArt.siedlung, region: 'Albernia'),
  ];

  late TextEditingController controller;
  late List<String> geaendert;
  late List<String> abgeschickt;

  Future<void> zeige(
    WidgetTester tester, {
    List<OrtEintrag>? verzeichnis,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    controller = TextEditingController();
    addTearDown(controller.dispose);
    geaendert = [];
    abgeschickt = [];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKartoTheme(
          brightness: Brightness.light,
          centerAppBarTitle: false,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: KartoOrtFeld(
              feldSchluessel: const ValueKey<String>('ort-feld'),
              controller: controller,
              orte: verzeichnis ?? orte,
              onChanged: geaendert.add,
              onSubmitted: abgeschickt.add,
            ),
          ),
        ),
      ),
    );
  }

  Finder schluessel(String name) => find.byKey(ValueKey<String>(name));

  testWidgets('Tippen zeigt Vorschläge mit Art und Region', (tester) async {
    await zeige(tester);

    await tester.enterText(schluessel('ort-feld'), 'gar');
    await tester.pumpAndSettle();

    expect(schluessel('karto-ort-vorschlaege'), findsOneWidget);
    expect(find.text('Gareth'), findsOneWidget);
    expect(find.text('Siedlung · Garetien'), findsOneWidget);
    expect(find.text('Garetien'), findsOneWidget);
    expect(find.text('Havena'), findsNothing);
  });

  testWidgets('Tipp auf einen Vorschlag übernimmt den Namen', (tester) async {
    await zeige(tester);

    await tester.enterText(schluessel('ort-feld'), 'have');
    await tester.pumpAndSettle();
    await tester.tap(schluessel('karto-ort-vorschlag-0'));
    await tester.pumpAndSettle();

    expect(controller.text, 'Havena');
    expect(geaendert.last, 'Havena');
    expect(schluessel('karto-ort-vorschlaege'), findsNothing);
  });

  testWidgets('Freitext ohne Treffer bleibt stehen, Eingabetaste schickt ab', (
    tester,
  ) async {
    await zeige(tester);

    await tester.enterText(schluessel('ort-feld'), 'Auf der Reichsstraße');
    await tester.pumpAndSettle();
    expect(schluessel('karto-ort-vorschlaege'), findsNothing);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(controller.text, 'Auf der Reichsstraße');
    expect(abgeschickt, <String>['Auf der Reichsstraße']);
  });

  testWidgets('Eingabetaste übernimmt zuerst den offenen Vorschlag', (
    tester,
  ) async {
    await zeige(tester);

    await tester.enterText(schluessel('ort-feld'), 'hav');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(controller.text, 'Havena');
    expect(abgeschickt, isEmpty);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(abgeschickt, <String>['Havena']);
  });

  testWidgets('ohne Verzeichnis ist es ein gewöhnliches Textfeld', (
    tester,
  ) async {
    await zeige(tester, verzeichnis: const <OrtEintrag>[]);

    await tester.enterText(schluessel('ort-feld'), 'Gareth');
    await tester.pumpAndSettle();

    expect(schluessel('karto-ort-vorschlaege'), findsNothing);
    expect(controller.text, 'Gareth');
  });
}
