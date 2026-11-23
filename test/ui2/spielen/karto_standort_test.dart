import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_standort.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

/// Standortzeile: Anzeige, Eingabe und Kartenlink.
void main() {
  Future<void> zeige(
    WidgetTester tester, {
    String standort = '',
    String standortOrtId = '',
    required List<String> gespeichert,
    List<KartoStandortWahl>? wahlen,
    List<Uri>? geoeffnet,
    bool oeffnenGelingt = true,
    List<OrtEintrag> orte = const <OrtEintrag>[],
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildKartoTheme(
            brightness: Brightness.light,
            centerAppBarTitle: false,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: KartoStandortZeile(
                standort: standort,
                standortOrtId: standortOrtId,
                orte: orte,
                onSpeichern: (wahl) async {
                  gespeichert.add(wahl.standort);
                  wahlen?.add(wahl);
                },
                oeffneLink: (uri) async {
                  geoeffnet?.add(uri);
                  return oeffnenGelingt;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder schluessel(String name) => find.byKey(ValueKey<String>(name));

  testWidgets('ohne Standort: Hinweis, kein Kartenlink', (tester) async {
    await zeige(tester, gespeichert: []);

    expect(schluessel('karto-spiel-standort-leer'), findsOneWidget);
    expect(schluessel('karto-spiel-standort-karte'), findsNothing);
    expect(find.text('Standort festhalten'), findsOneWidget);
  });

  testWidgets('mit Standort: Name und Link auf Avesmaps', (tester) async {
    final geoeffnet = <Uri>[];
    await zeige(
      tester,
      standort: 'Gareth',
      gespeichert: [],
      geoeffnet: geoeffnet,
    );

    expect(find.text('Gareth'), findsOneWidget);
    expect(schluessel('karto-spiel-standort-aendern'), findsOneWidget);

    await tester.tap(schluessel('karto-spiel-standort-karte'));
    await tester.pump();

    expect(geoeffnet.single.toString(), 'https://avesmaps.de/?siedlung=Gareth');
  });

  testWidgets('scheitert das Öffnen, erscheint eine Meldung', (tester) async {
    await zeige(
      tester,
      standort: 'Gareth',
      gespeichert: [],
      oeffnenGelingt: false,
    );

    await tester.tap(schluessel('karto-spiel-standort-karte'));
    await tester.pump();

    expect(find.text('Der Link konnte nicht geöffnet werden.'), findsOneWidget);
  });

  testWidgets('Eingabe wird bereinigt gespeichert', (tester) async {
    final gespeichert = <String>[];
    await zeige(tester, gespeichert: gespeichert);

    await tester.tap(schluessel('karto-spiel-standort-aendern'));
    await tester.pumpAndSettle();
    await tester.enterText(
      schluessel('karto-spiel-standort-feld'),
      '  Bad   Garetz ',
    );
    await tester.tap(schluessel('karto-spiel-standort-speichern'));
    await tester.pumpAndSettle();

    expect(gespeichert, ['Bad Garetz']);
  });

  testWidgets('Abbrechen speichert nichts', (tester) async {
    final gespeichert = <String>[];
    await zeige(tester, standort: 'Gareth', gespeichert: gespeichert);

    await tester.tap(schluessel('karto-spiel-standort-aendern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(gespeichert, isEmpty);
  });

  testWidgets('Entfernen speichert einen leeren Standort', (tester) async {
    final gespeichert = <String>[];
    await zeige(tester, standort: 'Gareth', gespeichert: gespeichert);

    await tester.tap(schluessel('karto-spiel-standort-aendern'));
    await tester.pumpAndSettle();
    await tester.tap(schluessel('karto-spiel-standort-entfernen'));
    await tester.pumpAndSettle();

    expect(gespeichert, ['']);
  });

  final verzeichnis = <OrtEintrag>[
    OrtEintrag(name: 'Gareth', art: OrtArt.siedlung, region: 'Garetien'),
    OrtEintrag(name: 'Albernia', art: OrtArt.staat),
  ];

  testWidgets('Vorschlag aus dem Verzeichnis wird gespeichert', (tester) async {
    final gespeichert = <String>[];
    await zeige(tester, gespeichert: gespeichert, orte: verzeichnis);

    await tester.tap(schluessel('karto-spiel-standort-aendern'));
    await tester.pumpAndSettle();
    await tester.enterText(schluessel('karto-spiel-standort-feld'), 'gar');
    await tester.pumpAndSettle();
    await tester.tap(schluessel('karto-ort-vorschlag-0'));
    await tester.pumpAndSettle();
    await tester.tap(schluessel('karto-spiel-standort-speichern'));
    await tester.pumpAndSettle();

    expect(gespeichert, ['Gareth']);
  });

  testWidgets('Freitext bleibt trotz Verzeichnis möglich', (tester) async {
    final gespeichert = <String>[];
    await zeige(tester, gespeichert: gespeichert, orte: verzeichnis);

    await tester.tap(schluessel('karto-spiel-standort-aendern'));
    await tester.pumpAndSettle();
    await tester.enterText(
      schluessel('karto-spiel-standort-feld'),
      'Auf der Reichsstraße',
    );
    await tester.tap(schluessel('karto-spiel-standort-speichern'));
    await tester.pumpAndSettle();

    expect(gespeichert, ['Auf der Reichsstraße']);
  });

  testWidgets('für eine Region entfällt der Kartenlink', (tester) async {
    await zeige(
      tester,
      standort: 'Albernia',
      gespeichert: [],
      orte: verzeichnis,
    );

    expect(find.text('Albernia'), findsOneWidget);
    expect(schluessel('karto-spiel-standort-karte'), findsNothing);
  });

  testWidgets('für eine Siedlung bleibt der Kartenlink', (tester) async {
    await zeige(tester, standort: 'Gareth', gespeichert: [], orte: verzeichnis);

    expect(schluessel('karto-spiel-standort-karte'), findsOneWidget);
  });

  testWidgets('bekannter Ort führt auch ins Wiki Aventurica', (tester) async {
    final geoeffnet = <Uri>[];
    await zeige(
      tester,
      standort: 'Gareth',
      gespeichert: [],
      geoeffnet: geoeffnet,
      orte: verzeichnis,
    );

    await tester.tap(schluessel('karto-spiel-standort-wiki'));
    await tester.pump();

    expect(
      geoeffnet.single.toString(),
      'https://de.wiki-aventurica.de/wiki/Gareth',
    );
  });

  testWidgets('Region hat Wiki-Link, aber keinen Kartenlink', (tester) async {
    await zeige(
      tester,
      standort: 'Albernia',
      gespeichert: [],
      orte: verzeichnis,
    );

    expect(schluessel('karto-spiel-standort-wiki'), findsOneWidget);
    expect(schluessel('karto-spiel-standort-karte'), findsNothing);
  });

  testWidgets('Freitext hat keinen Wiki-Link', (tester) async {
    await zeige(
      tester,
      standort: 'Auf der Reichsstraße',
      gespeichert: [],
      orte: verzeichnis,
    );

    expect(schluessel('karto-spiel-standort-wiki'), findsNothing);
    expect(schluessel('karto-spiel-standort-karte'), findsOneWidget);
  });

  group('Verweis am Standort', () {
    // Zwei gleichnamige Orte: nur die Auswahl unterscheidet sie.
    final doppelt = <OrtEintrag>[
      OrtEintrag(
        name: 'Kronling',
        art: OrtArt.siedlung,
        region: 'Garetien',
        ortId: 'kronling-garetien',
        kartenX: 520,
        kartenY: 510,
      ),
      OrtEintrag(
        name: 'Kronling',
        art: OrtArt.siedlung,
        region: 'Weiden',
        ortId: 'kronling-weiden',
        kartenX: 480,
        kartenY: 640,
      ),
    ];

    testWidgets('die Auswahl liefert die Kennung mit', (tester) async {
      final wahlen = <KartoStandortWahl>[];
      await zeige(tester, gespeichert: [], wahlen: wahlen, orte: doppelt);

      await tester.tap(schluessel('karto-spiel-standort-aendern'));
      await tester.pumpAndSettle();
      await tester.enterText(schluessel('karto-spiel-standort-feld'), 'kron');
      await tester.pumpAndSettle();
      await tester.tap(schluessel('karto-ort-vorschlag-1'));
      await tester.pumpAndSettle();
      await tester.tap(schluessel('karto-spiel-standort-speichern'));
      await tester.pumpAndSettle();

      expect(wahlen, hasLength(1));
      expect(wahlen.single.standort, 'Kronling');
      expect(<String>[
        'kronling-garetien',
        'kronling-weiden',
      ], contains(wahlen.single.ortId));
    });

    testWidgets('ein danach geänderter Text verliert die Kennung', (
      tester,
    ) async {
      final wahlen = <KartoStandortWahl>[];
      await zeige(tester, gespeichert: [], wahlen: wahlen, orte: doppelt);

      await tester.tap(schluessel('karto-spiel-standort-aendern'));
      await tester.pumpAndSettle();
      await tester.enterText(schluessel('karto-spiel-standort-feld'), 'kron');
      await tester.pumpAndSettle();
      await tester.tap(schluessel('karto-ort-vorschlag-0'));
      await tester.pumpAndSettle();
      await tester.enterText(
        schluessel('karto-spiel-standort-feld'),
        'Kronling am Fluss',
      );
      await tester.tap(schluessel('karto-spiel-standort-speichern'));
      await tester.pumpAndSettle();

      expect(wahlen.single, const KartoStandortWahl('Kronling am Fluss'));
    });

    testWidgets('der Kartenlink öffnet genau den verknüpften Ort', (
      tester,
    ) async {
      final geoeffnet = <Uri>[];
      await zeige(
        tester,
        standort: 'Kronling',
        standortOrtId: 'kronling-weiden',
        gespeichert: [],
        geoeffnet: geoeffnet,
        orte: doppelt,
      );

      await tester.tap(schluessel('karto-spiel-standort-karte'));
      await tester.pump();

      expect(
        geoeffnet.single.toString(),
        'https://avesmaps.de/?place=kronling-weiden',
      );
    });

    testWidgets('vor dem Laden der Avesmaps-Liste gilt der Verweis weiter', (
      tester,
    ) async {
      // Das Wiki-Verzeichnis allein kennt noch keine Kennungen.
      final geoeffnet = <Uri>[];
      await zeige(
        tester,
        standort: 'Kronling',
        standortOrtId: 'kronling-weiden',
        gespeichert: [],
        geoeffnet: geoeffnet,
        orte: <OrtEintrag>[
          OrtEintrag(name: 'Kronling', art: OrtArt.siedlung, region: 'Weiden'),
        ],
      );

      await tester.tap(schluessel('karto-spiel-standort-karte'));
      await tester.pump();

      expect(
        geoeffnet.single.toString(),
        'https://avesmaps.de/?place=kronling-weiden',
      );
    });

    testWidgets('ein Verweis, der nicht zum Namen passt, gilt nicht', (
      tester,
    ) async {
      // Etwa von einer älteren App, die den Text ohne den Verweis änderte.
      final geoeffnet = <Uri>[];
      await zeige(
        tester,
        standort: 'Gareth',
        standortOrtId: 'kronling-weiden',
        gespeichert: [],
        geoeffnet: geoeffnet,
        orte: <OrtEintrag>[...doppelt, ...verzeichnis],
      );

      await tester.tap(schluessel('karto-spiel-standort-karte'));
      await tester.pump();

      expect(
        geoeffnet.single.toString(),
        'https://avesmaps.de/?siedlung=Gareth',
      );
    });
  });
}
