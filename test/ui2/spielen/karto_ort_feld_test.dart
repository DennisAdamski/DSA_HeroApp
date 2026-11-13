import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
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
  late List<OrtEintrag> gewaehlt;

  Future<void> zeige(
    WidgetTester tester, {
    List<OrtEintrag>? verzeichnis,
    Future<List<AvesmapsOrt>> Function(String anfrage)? onlineSuche,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    controller = TextEditingController();
    addTearDown(controller.dispose);
    geaendert = [];
    abgeschickt = [];
    gewaehlt = [];
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
              onOrtGewaehlt: gewaehlt.add,
              onlineSuche: onlineSuche,
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

  testWidgets('ein Vorschlag mit Kartenposition trägt das Kartensymbol und '
      'wird beim Übernehmen gemeldet', (tester) async {
    await zeige(
      tester,
      verzeichnis: <OrtEintrag>[
        OrtEintrag(
          name: 'Gareth',
          art: OrtArt.siedlung,
          ortId: 'g',
          kartenX: 551.6,
          kartenY: 533,
        ),
        OrtEintrag(name: 'Garetien', art: OrtArt.region),
      ],
    );

    await tester.enterText(schluessel('ort-feld'), 'gar');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);

    await tester.tap(schluessel('karto-ort-vorschlag-0'));
    await tester.pumpAndSettle();
    expect(gewaehlt.single.ortId, 'g');
    expect(controller.text, 'Gareth');
  });

  group('Online-Suche als Ersatz', () {
    testWidgets('fragt erst nach der Tipppause und nur für den letzten Text', (
      tester,
    ) async {
      final anfragen = <String>[];
      await zeige(
        tester,
        onlineSuche: (anfrage) async {
          anfragen.add(anfrage);
          return const <AvesmapsOrt>[
            AvesmapsOrt(id: 'h2', name: 'Havenhus', art: 'dorf', x: 1, y: 2),
          ];
        },
      );

      await tester.enterText(schluessel('ort-feld'), 'ha');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(schluessel('ort-feld'), 'hav');
      await tester.pump(KartoOrtFeld.onlinePause);
      await tester.pumpAndSettle();

      expect(anfragen, <String>['hav']);
      // Lokaler und Online-Treffer stehen zusammen in der Liste.
      expect(find.text('Havena'), findsOneWidget);
      expect(find.text('Havenhus'), findsOneWidget);

      await tester.tap(find.text('Havenhus'));
      await tester.pumpAndSettle();
      expect(gewaehlt.single.ortId, 'h2');
      expect(gewaehlt.single.unterart, 'Dorf');
    });

    testWidgets('unter zwei Zeichen und ohne Treffer bleibt es bei den '
        'lokalen Vorschlägen', (tester) async {
      var anfragen = 0;
      await zeige(
        tester,
        onlineSuche: (_) async {
          anfragen++;
          return const <AvesmapsOrt>[];
        },
      );

      await tester.enterText(schluessel('ort-feld'), 'h');
      await tester.pump(KartoOrtFeld.onlinePause);
      await tester.pumpAndSettle();
      expect(anfragen, 0);
      expect(find.text('Havena'), findsOneWidget);

      await tester.enterText(schluessel('ort-feld'), 'hav');
      await tester.pump(KartoOrtFeld.onlinePause);
      await tester.pumpAndSettle();
      expect(anfragen, 1);
      expect(find.text('Havena'), findsOneWidget);
    });
  });
}
