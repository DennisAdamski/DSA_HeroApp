import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_client.dart';

// Aufgezeichnete Antwortform der Entwickler-API v1 (12.11.2026), gekürzt.
const Map<String, Object?> _orteAntwort = <String, Object?>{
  'vertrag': 1,
  'anzahl': 3,
  'orte': <Object?>[
    <String, Object?>{
      'id': '80558060-4299-54aa-b520-814b10819885',
      'name': 'Gareth',
      'art': 'metropole',
      'x': 551.625,
      'y': 532.969,
    },
    <String, Object?>{
      'id': '5acdf435-80fc-4a34-980f-41020b31a8d3',
      'name': 'Felden (Gareth)',
      'art': 'dorf',
      'x': 553.928,
      'y': 528,
      'neuesFeld': <String, Object?>{'egal': true},
    },
    // Ohne Position nicht verknüpfbar: fällt weg.
    <String, Object?>{'id': 'ohne-position', 'name': 'Nirgendwo'},
  ],
};

http.Response _json(Object? inhalt, {int status = 200}) => http.Response.bytes(
  utf8.encode(jsonEncode(inhalt)),
  status,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('ladeOrte liest die Liste tolerant und setzt die Kennung', () async {
    late http.Request anfrage;
    final client = AvesmapsClient(
      kennung: kAvesmapsKennung,
      httpClient: MockClient((request) async {
        anfrage = request;
        return _json(_orteAntwort);
      }),
    );

    final orte = await client.ladeOrte();

    expect(anfrage.method, 'GET');
    expect('${anfrage.url}', 'https://avesmaps.de/api/v1/orte');
    expect(anfrage.headers['User-Agent'], kAvesmapsKennung);
    expect(orte.map((o) => o.name), <String>['Gareth', 'Felden (Gareth)']);
    expect(orte.first.id, '80558060-4299-54aa-b520-814b10819885');
    expect(orte.first.x, 551.625);
    expect(orte.first.y, 532.969);
    expect(orte.first.artBezeichnung, 'Metropole');
    // Ganzzahlige Koordinaten kommen als double an.
    expect(orte.last.y, 528.0);
  });

  test('ohne Kennung (Web) bleibt der User-Agent dem Browser', () async {
    late http.Request anfrage;
    final client = AvesmapsClient(
      httpClient: MockClient((request) async {
        anfrage = request;
        return _json(_orteAntwort);
      }),
    );

    await client.ladeOrte();

    expect(anfrage.headers.containsKey('User-Agent'), isFalse);
  });

  test('unbekannte Ortsklasse bleibt erhalten und heißt „Ort“', () async {
    final client = AvesmapsClient(
      httpClient: MockClient(
        (_) async => _json(<String, Object?>{
          'orte': <Object?>[
            <String, Object?>{
              'id': 'a',
              'name': 'Turm im Nebel',
              'art': 'landmarke',
              'x': 1,
              'y': 2,
            },
          ],
        }),
      ),
    );

    final ort = (await client.ladeOrte()).single;

    expect(ort.art, 'landmarke');
    expect(ort.artBezeichnung, 'Ort');
    expect(ort.toJson()['art'], 'landmarke');
  });

  test('suche übergibt Anfrage und begrenztes Limit', () async {
    late http.Request anfrage;
    final client = AvesmapsClient(
      httpClient: MockClient((request) async {
        anfrage = request;
        return _json(<String, Object?>{
          'vertrag': 1,
          'anfrage': 'Gareth',
          'treffer': _orteAntwort['orte'],
          'gekuerzt': true,
        });
      }),
    );

    final ergebnis = await client.suche('  Gareth ', limit: 99);

    expect(anfrage.url.path, '/api/v1/suche');
    expect(anfrage.url.queryParameters, <String, String>{
      'q': 'Gareth',
      'limit': '20',
    });
    expect(ergebnis.treffer, hasLength(2));
    expect(ergebnis.gekuerzt, isTrue);
  });

  test('suche unter zwei Zeichen fragt nicht an', () async {
    var anfragen = 0;
    final client = AvesmapsClient(
      httpClient: MockClient((_) async {
        anfragen++;
        return _json(<String, Object?>{});
      }),
    );

    final ergebnis = await client.suche(' G ');

    expect(anfragen, 0);
    expect(ergebnis.treffer, isEmpty);
  });

  test('429 meldet die Drossel mit Wartezeit', () async {
    final client = AvesmapsClient(
      httpClient: MockClient(
        (_) async => http.Response(
          '<html>Too Many Requests</html>',
          429,
          headers: <String, String>{'retry-after': '42'},
        ),
      ),
    );

    await expectLater(
      client.ladeOrte(),
      throwsA(
        isA<AvesmapsFehler>()
            .having((f) => f.art, 'art', AvesmapsFehlerArt.gedrosselt)
            .having(
              (f) => f.wartezeit,
              'wartezeit',
              const Duration(seconds: 42),
            ),
      ),
    );
  });

  test('503 meldet „nicht verfügbar“, auch ohne Retry-After', () async {
    final client = AvesmapsClient(
      httpClient: MockClient((_) async => http.Response('', 503)),
    );

    await expectLater(
      client.suche('Gareth'),
      throwsA(
        isA<AvesmapsFehler>()
            .having((f) => f.art, 'art', AvesmapsFehlerArt.nichtVerfuegbar)
            .having((f) => f.wartezeit, 'wartezeit', isNull),
      ),
    );
  });

  test(
    '410 der alten Schnittstelle und Unlesbares sind Antwortfehler',
    () async {
      for (final antwort in <http.Response>[
        _json(<String, Object?>{
          'error': <String, Object?>{'code': 'api_gone'},
        }, status: 410),
        http.Response('kein json', 200),
        _json(<Object?>[1, 2, 3]),
        _json(<String, Object?>{'vertrag': 1}),
      ]) {
        final client = AvesmapsClient(
          httpClient: MockClient((_) async => antwort),
        );
        await expectLater(
          client.ladeOrte(),
          throwsA(
            isA<AvesmapsFehler>().having(
              (f) => f.art,
              'art',
              AvesmapsFehlerArt.antwort,
            ),
          ),
        );
      }
    },
  );

  test('Verbindungsfehler wird zum Netzfehler', () async {
    final client = AvesmapsClient(
      httpClient: MockClient(
        (_) async => throw http.ClientException('keine Verbindung'),
      ),
    );

    await expectLater(
      client.ladeOrte(),
      throwsA(
        isA<AvesmapsFehler>().having(
          (f) => f.art,
          'art',
          AvesmapsFehlerArt.netz,
        ),
      ),
    );
  });

  group('ladeOrt', () {
    const id = '80558060-4299-54aa-b520-814b10819885';
    // Aufgezeichnete Antwort von `GET /api/v1/orte/{id}` (13.11.2026).
    const details = <String, Object?>{
      'vertrag': 1,
      'id': id,
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
          <String, Object?>{
            'id': '3359118f-bdfe-4569-8277-3f25c2d62463',
            'name': 'Heiliges Neues Kaiserreich vom Greifenthron zu Gareth',
            'art': 'Kaiserreich',
          },
          <String, Object?>{
            'id': '99dacb52-93f1-4698-8746-1dd9d4b55992',
            'name': 'Königreich Garetien',
            'art': 'Königreich',
          },
          <String, Object?>{
            'id': '159ad4fd-54de-4459-9e89-e0344fc7670c',
            'name': 'Kaisermark Gareth',
            'art': 'Kaisermark',
          },
          <String, Object?>{
            'id': 'b883cc39-969d-4991-bf6e-1f5427f9e117',
            'name': 'Alt-Gareth',
            'art': 'Herrschaftsgebiet',
          },
        ],
      ],
      'spaeterDazu': <String, Object?>{'egal': true},
    };

    test('liest Wiki-Artikel und Gebiete', () async {
      late http.Request anfrage;
      final client = AvesmapsClient(
        httpClient: MockClient((request) async {
          anfrage = request;
          return _json(details);
        }),
      );

      final ort = await client.ladeOrt(id);

      expect('${anfrage.url}', 'https://avesmaps.de/api/v1/orte/$id');
      expect(ort, isNotNull);
      expect(ort!.ort.artBezeichnung, 'Metropole');
      expect(ort.wikiTitel, 'Gareth');
      expect(
        ort.gebiete.single.map((g) => g.name),
        contains('Königreich Garetien'),
      );
    });

    test('404 und ungültige Kennung ergeben null, ohne Anfrage bei '
        'ungültiger Kennung', () async {
      var anfragen = 0;
      final client = AvesmapsClient(
        httpClient: MockClient((_) async {
          anfragen++;
          return _json(<String, Object?>{
            'error': <String, Object?>{'code': 'place_not_found'},
          }, status: 404);
        }),
      );

      expect(await client.ladeOrt(id), isNull);
      expect(anfragen, 1);
      expect(await client.ladeOrt('Gareth'), isNull);
      expect(await client.ladeOrt('../orte'), isNull);
      expect(anfragen, 1);
    });

    test('Drossel und unlesbare Details bleiben Fehler', () async {
      final gedrosselt = AvesmapsClient(
        httpClient: MockClient((_) async => http.Response('', 429)),
      );
      await expectLater(
        gedrosselt.ladeOrt(id),
        throwsA(
          isA<AvesmapsFehler>().having(
            (f) => f.art,
            'art',
            AvesmapsFehlerArt.gedrosselt,
          ),
        ),
      );
      final unlesbar = AvesmapsClient(
        httpClient: MockClient(
          (_) async => _json(<String, Object?>{'vertrag': 1, 'id': id}),
        ),
      );
      await expectLater(
        unlesbar.ladeOrt(id),
        throwsA(
          isA<AvesmapsFehler>().having(
            (f) => f.art,
            'art',
            AvesmapsFehlerArt.antwort,
          ),
        ),
      );
    });
  });
}
