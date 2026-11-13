import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dsa_heldenverwaltung/catalog/ort_loader.dart';
import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_client.dart';
import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_orte_speicher.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/ortsfakten.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_lage_rules.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_providers.dart';
import 'package:dsa_heldenverwaltung/state/ort_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/standort/karto_standort_kachel.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

// Standort-Kachel nach dem Vorbild der Ortsansicht von Avesmaps. Das Netz
// ersetzt ein MockClient; jede Anfrage wird gezählt, damit vor dem Knopf
// keine entsteht.

const String _garethId = '80558060-4299-54aa-b520-814b10819885';

final OrtKatalog _wiki = OrtKatalog(
  orte: <OrtEintrag>[
    OrtEintrag(name: 'Gareth', art: OrtArt.siedlung, region: 'Garetien'),
    OrtEintrag(name: 'Garetien', art: OrtArt.region),
  ],
);

Map<String, Object?> _ort(
  String id,
  String name,
  String art,
  double x,
  double y,
) => <String, Object?>{'id': id, 'name': name, 'art': art, 'x': x, 'y': y};

// Gareth und zwölf Nachbarn; das Gebäude zählt nicht als Siedlung.
final List<Map<String, Object?>> _orte = <Map<String, Object?>>[
  _ort(_garethId, 'Gareth', 'metropole', 551.625, 532.969),
  _ort('fehring', 'Fehring', 'dorf', 551.625, 534.169),
  _ort('schloss', 'Schloss Schickelsfeld', 'gebaeude', 552.1, 532.969),
  _ort('kronling', 'Kronling', 'stadt', 549.6, 535),
  for (var i = 0; i < 10; i++)
    _ort('dorf$i', 'Dorf $i', 'dorf', 553.0 + i * 0.4, 531.0 - i * 0.2),
];

const Map<String, Object?> _details = <String, Object?>{
  'vertrag': 1,
  'id': _garethId,
  'name': 'Gareth',
  'art': 'metropole',
  'x': 551.625,
  'y': 532.969,
  'wiki': <String, Object?>{
    'url': 'https://de.wiki-aventurica.de/wiki/Gareth',
    'titel': 'Gareth',
  },
  'gebiete': <Object?>[
    <Object?>[
      <String, Object?>{'id': 'a', 'name': 'Heiliges Neues Kaiserreich'},
      <String, Object?>{'id': 'b', 'name': 'Königreich Garetien'},
      <String, Object?>{'id': 'c', 'name': 'Kaisermark Gareth'},
      <String, Object?>{'id': 'd', 'name': 'Alt-Gareth'},
    ],
  ],
};

http.Response _json(Object? inhalt) => http.Response.bytes(
  utf8.encode(jsonEncode(inhalt)),
  200,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);

class _Speicher implements AvesmapsOrteSpeicher {
  _Speicher([this.liste]);

  AvesmapsOrtsliste? liste;

  @override
  Future<AvesmapsOrtsliste?> lade() async => liste;

  @override
  Future<void> merke(AvesmapsOrtsliste neu) async => liste = neu;
}

class _Aufbau {
  final List<String> anfragen = <String>[];
  final List<String> gespeichert = <String>[];
  final List<Uri> geoeffnet = <Uri>[];
}

Finder k(String schluessel) => find.byKey(ValueKey<String>(schluessel));

Future<_Aufbau> _zeige(
  WidgetTester tester, {
  String standort = 'Gareth',
  bool abrufbar = true,
  bool lokal = false,
  double breite = 420,
  OrtsfaktenKatalog fakten = const OrtsfaktenKatalog(),
}) async {
  final aufbau = _Aufbau();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(breite, 2400);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final speicher = _Speicher(
    lokal
        ? AvesmapsOrtsliste(
            orte: leseAvesmapsOrte(_orte),
            abgerufen: DateTime.now().toUtc(),
          )
        : null,
  );
  final container = ProviderContainer(
    overrides: [
      ortKatalogProvider.overrideWith((ref) async => _wiki),
      ortsfaktenProvider.overrideWith((ref) async => fakten),
      if (abrufbar) ...[
        avesmapsAktivProvider.overrideWithValue(true),
        avesmapsOrteSpeicherProvider.overrideWith((ref) async => speicher),
        avesmapsClientProvider.overrideWithValue(
          AvesmapsClient(
            httpClient: MockClient((anfrage) async {
              aufbau.anfragen.add(anfrage.url.path);
              if (anfrage.url.path.endsWith('/orte')) {
                return _json(<String, Object?>{'vertrag': 1, 'orte': _orte});
              }
              if (anfrage.url.path.endsWith(_garethId)) return _json(_details);
              return http.Response('', 404);
            }),
          ),
        ),
      ],
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildKartoTheme(
          brightness: Brightness.light,
          centerAppBarTitle: false,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: KartoKachelSteuerung(
              kennung: 'standort',
              groesse: KartoKachelGroesse.fuerBreite(breite - 32),
              dicht: false,
              child: KartoStandortKachel(
                standort: standort,
                onSpeichern: (neu) async => aufbau.gespeichert.add(neu),
                oeffneLink: (uri) async {
                  aufbau.geoeffnet.add(uri);
                  return true;
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return aufbau;
}

String _text(WidgetTester tester, String schluessel) =>
    (tester.widget(k(schluessel)) as Text).data ?? '';

void main() {
  testWidgets('ohne Standort: Hinweis und Festhalten über den Dialog', (
    tester,
  ) async {
    final aufbau = await _zeige(tester, standort: '');

    expect(k('karto-standort-kachel-leer'), findsOneWidget);
    await tester.tap(k('karto-standort-kachel-festhalten'));
    await tester.pumpAndSettle();
    await tester.enterText(k('karto-spiel-standort-feld'), '  Gareth  ');
    await tester.tap(k('karto-spiel-standort-speichern'));
    await tester.pumpAndSettle();

    expect(aufbau.gespeichert, <String>['Gareth']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ohne Kartendaten: Wiki-Angaben und Knopf, keine Anfrage', (
    tester,
  ) async {
    final aufbau = await _zeige(tester);

    expect(_text(tester, 'karto-standort-kachel-name'), 'Gareth');
    expect(
      _text(tester, 'karto-standort-kachel-untertitel'),
      'Siedlung in Garetien',
    );
    expect(k('karto-standort-kachel-laden'), findsOneWidget);
    expect(k('karto-standort-skizze'), findsNothing);
    expect(k('karto-standort-kachel-wiki'), findsOneWidget);
    expect(aufbau.anfragen, isEmpty);
  });

  testWidgets('der Knopf lädt Liste und Details: Skizze, Gebiete, Nähe, '
      'genaue Links', (tester) async {
    final aufbau = await _zeige(tester);

    await tester.tap(k('karto-standort-kachel-laden'));
    await tester.pumpAndSettle();

    expect(aufbau.anfragen, <String>[
      '/api/v1/orte',
      '/api/v1/orte/$_garethId',
    ]);
    expect(k('karto-standort-skizze'), findsOneWidget);
    expect(
      _text(tester, 'karto-standort-kachel-untertitel'),
      'Metropole in Alt-Gareth',
    );
    expect(
      _text(tester, 'karto-standort-kachel-fakt-Lage'),
      'Alt-Gareth · Kaisermark Gareth · Königreich Garetien',
    );
    expect(
      _text(tester, 'karto-standort-kachel-fakt-Reich'),
      'Heiliges Neues Kaiserreich',
    );
    expect(k('karto-standort-kachel-laden'), findsNothing);
    expect(k('karto-standort-kachel-details'), findsNothing);

    // Schmal: fünf Nachbarn, das Gebäude nicht, Fehring zuerst.
    expect(k('karto-standort-kachel-nahe-fehring'), findsOneWidget);
    expect(k('karto-standort-kachel-nahe-schloss'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'karto-standort-kachel-nahe-',
            ),
      ),
      findsNWidgets(kNaheOrteKurz),
    );

    await tester.tap(k('karto-standort-kachel-karte'));
    await tester.tap(k('karto-standort-kachel-wiki'));
    await tester.tap(k('karto-standort-kachel-nahe-fehring'));
    await tester.pumpAndSettle();
    expect(aufbau.geoeffnet.map((u) => '$u'), <String>[
      'https://avesmaps.de/?siedlung=Gareth',
      'https://de.wiki-aventurica.de/wiki/Gareth',
      'https://avesmaps.de/?place=fehring',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Wiki-Fakten: Einwohner, Oberhaupt, Tempel und wichtige Orte', (
    tester,
  ) async {
    final aufbau = await _zeige(
      tester,
      lokal: true,
      fakten: const OrtsfaktenKatalog(
        siedlungen: <String, SiedlungsFakten>{
          'Gareth': SiedlungsFakten(
            einwohner: 170000,
            einwohnerText: '170000 (1040 BF)',
            oberhaupt: 'Kaiserin Rohaja von Gareth',
            verkehrswege: <String>['Reichsstraße 2', 'Gardel'],
          ),
        },
        bauwerke: <String, List<OrtsBauwerk>>{
          'Gareth': <OrtsBauwerk>[
            OrtsBauwerk(name: 'Wohnhaus Alrik', ort: 'Gareth', art: 'Wohnhaus'),
            OrtsBauwerk(
              name: 'Stadt des Lichts',
              ort: 'Gareth',
              art: 'Tempel',
              zugehoerigkeit: 'Praios-Kirche',
            ),
            OrtsBauwerk(
              name: 'Praios-Tempel in Alt-Gareth',
              ort: 'Gareth',
              art: 'Tempel',
              zugehoerigkeit: 'Praios-Kirche: Orden des Bannstrahls',
            ),
            OrtsBauwerk(
              name: 'Rondra-Tempel',
              ort: 'Gareth',
              art: 'Tempel',
              zugehoerigkeit: 'Rondra-Kirche',
            ),
            OrtsBauwerk(name: 'Neue Residenz', ort: 'Gareth', art: 'Palast'),
            OrtsBauwerk(name: 'Burg Gareth', ort: 'Gareth', art: 'Burg'),
          ],
        },
      ),
    );

    // Leitzeile: Zahl mit Tausenderpunkten, Zusatz ohne Klammern darunter.
    expect(
      find.textContaining('170.000 Einwohner', findRichText: true),
      findsOneWidget,
    );
    expect(_text(tester, 'karto-standort-kachel-einwohner-zusatz'), '1040 BF');
    expect(
      _text(tester, 'karto-standort-kachel-fakt-Oberhaupt'),
      'Kaiserin Rohaja von Gareth',
    );
    expect(
      find.textContaining('Reichsstraße 2', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Gardel', findRichText: true), findsOneWidget);

    // Tempel nach Gottheit: Praios zweimal, Rondra einmal.
    expect(k('karto-standort-kachel-tempel-Praios'), findsOneWidget);
    expect(k('karto-standort-kachel-tempel-Rondra'), findsOneWidget);
    // Wichtige Orte: Palast vor Burg, das Wohnhaus zuletzt.
    expect(
      tester.getTopLeft(k('karto-standort-kachel-bauwerk-Neue Residenz')).dy,
      lessThan(
        tester.getTopLeft(k('karto-standort-kachel-bauwerk-Burg Gareth')).dy,
      ),
    );

    // Ein Tempel öffnet direkt das Wiki, mehrere zeigen erst die Liste.
    await tester.tap(k('karto-standort-kachel-tempel-Rondra'));
    await tester.pumpAndSettle();
    await tester.tap(k('karto-standort-kachel-tempel-Praios'));
    await tester.pumpAndSettle();
    expect(find.text('Tempel: Praios'), findsOneWidget);
    await tester.tap(
      k('karto-standort-kachel-bauwerk-Praios-Tempel in Alt-Gareth'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tempel: Praios'), findsNothing);
    expect(aufbau.geoeffnet.map((u) => '$u'), <String>[
      'https://de.wiki-aventurica.de/wiki/Rondra-Tempel',
      'https://de.wiki-aventurica.de/wiki/Praios-Tempel_in_Alt-Gareth',
    ]);
    expect(aufbau.anfragen, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mit lokaler Liste: Skizze ohne Anfrage, Details per Knopf', (
    tester,
  ) async {
    final aufbau = await _zeige(tester, lokal: true);

    expect(k('karto-standort-skizze'), findsOneWidget);
    expect(k('karto-standort-kachel-nahe-fehring'), findsOneWidget);
    expect(k('karto-standort-kachel-fakt-Lage'), findsNothing);
    expect(aufbau.anfragen, isEmpty);

    await tester.tap(k('karto-standort-kachel-details'));
    await tester.pumpAndSettle();

    // Die lokale Liste ist frisch: nur die Details werden geladen.
    expect(aufbau.anfragen, <String>['/api/v1/orte/$_garethId']);
    expect(k('karto-standort-kachel-fakt-Lage'), findsOneWidget);
  });

  testWidgets('weit zeigt mehr Nachbarn', (tester) async {
    await _zeige(tester, lokal: true, breite: 1100);

    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'karto-standort-kachel-nahe-',
            ),
      ),
      findsNWidgets(kNaheOrteWeit),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Freitext steht nicht auf der Karte', (tester) async {
    await _zeige(tester, standort: 'Auf der Reichsstraße', lokal: true);

    expect(k('karto-standort-skizze'), findsNothing);
    expect(k('karto-standort-kachel-ohne-karte'), findsOneWidget);
    expect(k('karto-standort-kachel-wiki'), findsNothing);
  });

  testWidgets('ohne Abruf (Tests, Vorschau) gibt es keinen Ladeknopf', (
    tester,
  ) async {
    await _zeige(tester, abrufbar: false);

    expect(k('karto-standort-kachel-laden'), findsNothing);
    expect(k('karto-standort-kachel-ohne-karte'), findsOneWidget);
  });

  testWidgets('dunkles Theme zeichnet ohne Fehler', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ortKatalogProvider.overrideWith((ref) async => _wiki),
          avesmapsOrteProvider.overrideWith(
            (ref) async => leseAvesmapsOrte(_orte),
          ),
        ],
        child: MaterialApp(
          theme: buildKartoTheme(
            brightness: Brightness.dark,
            centerAppBarTitle: false,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: KartoStandortKachel(
                standort: 'Gareth',
                onSpeichern: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(k('karto-standort-skizze'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
