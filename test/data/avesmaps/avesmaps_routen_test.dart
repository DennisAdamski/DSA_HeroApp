import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_client.dart';
import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_routen_repository.dart';
import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_routen_speicher.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_route.dart';

// Antwortform von `GET /api/v1/route` (geprüft am 20.11.2026), mit
// erfundenen Zahlen und gekürzter Linie.
const String _gareth = '80558060-4299-54aa-b520-814b10819885';
const String _perricum = '194cd8ed-9aff-57af-b658-ff353ac883a7';

const Map<String, Object?> _routeAntwort = <String, Object?>{
  'vertrag': 1,
  'gefunden': true,
  'orte': <Object?>[
    <String, Object?>{'id': _gareth, 'name': 'Gareth'},
    <String, Object?>{'id': _perricum, 'name': 'Perricum'},
  ],
  'meilen': 341.45,
  'reisestunden': 68.39,
  'raststunden': 60.39,
  'gesamtstunden': 128.78,
  'reisetage': 5.78,
  'stundenProTag': 8,
  'etappen': <Object?>[
    <String, Object?>{
      'art': 'Strasse',
      'mittel': 'groupFoot',
      'wege': <Object?>[],
      'von': <String, Object?>{'x': 551.6, 'y': 532.9},
      'nach': <String, Object?>{'x': 552.5, 'y': 532.4},
      'meilen': 4.83,
      'reisestunden': 1.2,
      'raststunden': 0,
    },
    <String, Object?>{
      'art': 'Flussweg',
      'mittel': 'riverSailer',
      'wege': <Object?>['Gardel', 'Darpat'],
      'von': <String, Object?>{'x': 552.5, 'y': 532.4},
      'nach': <String, Object?>{'x': 631, 'y': 508},
      'meilen': 334.32,
      'reisestunden': 67,
      'raststunden': 60,
      'neuesFeld': true,
    },
    <String, Object?>{
      'art': 'Umsteigen',
      'mittel': 'groupFoot',
      'wege': <Object?>[],
      'von': <String, Object?>{'x': 631, 'y': 508},
      'nach': <String, Object?>{'x': 631.2, 'y': 507.3},
      'meilen': 2.3,
      'reisestunden': .2,
      'raststunden': 0,
    },
  ],
  'linie': <Object?>[
    <Object?>[551.6, 532.9],
    <Object?>[560, 530],
    <Object?>[631.2, 507.3],
  ],
  'hinweise': <Object?>['zukunftshinweis'],
};

http.Response _json(Object? inhalt, {int status = 200, String? warte}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(inhalt)),
      status,
      headers: <String, String>{
        'content-type': 'application/json; charset=utf-8',
        'retry-after': ?warte,
      },
    );

AvesmapsRoutenAnfrage _anfrage({
  List<String> wege = const <String>[],
  String optimierung = kReiseOptimierungSchnellste,
}) => AvesmapsRoutenAnfrage(
  vonId: _gareth,
  nachId: _perricum,
  wege: wege,
  optimierung: optimierung,
);

void main() {
  group('AvesmapsRoutenAnfrage', () {
    test('bereinigt Wege, alle drei gelten als Vorgabe', () {
      expect(_anfrage(wege: <String>['see', 'land', 'see', 'mond']).wege, [
        'land',
        'see',
      ]);
      expect(_anfrage(wege: kReiseWegArten).alleWege, isTrue);
      expect(_anfrage(), _anfrage(wege: kReiseWegArten));
      expect(
        _anfrage(optimierung: 'irgendwas').optimierung,
        kReiseOptimierungSchnellste,
      );
      expect(
        _anfrage(wege: <String>['land']).schluessel,
        '$_gareth|$_perricum|land|schnellste',
      );
    });
  });

  group('AvesmapsClient.route', () {
    test('übergibt Parameter und liest die Antwort tolerant', () async {
      late Uri adresse;
      final client = AvesmapsClient(
        httpClient: MockClient((request) async {
          adresse = request.url;
          return _json(_routeAntwort);
        }),
      );

      final route = await client.route(
        _anfrage(wege: <String>['land', 'fluss'], optimierung: 'kuerzeste'),
      );

      expect(adresse.path, '/api/v1/route');
      expect(adresse.queryParameters, <String, String>{
        'von': _gareth,
        'nach': _perricum,
        'optimierung': 'kuerzeste',
        'wege': 'land,fluss',
      });
      expect(route.gefunden, isTrue);
      expect(route.meilen, 341.45);
      expect(route.reisetage, 5.78);
      expect(route.etappen.map((e) => e.art), [
        'Strasse',
        'Flussweg',
        'Umsteigen',
      ]);
      expect(route.etappen[1].wege, <String>['Gardel', 'Darpat']);
      expect(route.linie, hasLength(3));
      expect(route.hinweise, <String>['zukunftshinweis']);

      // Zwischenspeicherform liest sich zurück.
      final zurueck = AvesmapsRoute.ausJson(
        jsonDecode(jsonEncode(route.toJson())),
      )!;
      expect(zurueck.meilen, route.meilen);
      expect(zurueck.linie, route.linie);
      expect(zurueck.etappen.length, 3);
    });

    test('alle Wege ohne Parameter `wege`', () async {
      late Uri adresse;
      final client = AvesmapsClient(
        httpClient: MockClient((request) async {
          adresse = request.url;
          return _json(_routeAntwort);
        }),
      );
      await client.route(_anfrage());
      expect(adresse.queryParameters.containsKey('wege'), isFalse);
    });

    test('kein Weg und unbekannter Ort sind Antworten, kein Fehler', () async {
      var antwort = _json(<String, Object?>{
        'vertrag': 1,
        'gefunden': false,
        'grund': 'kein_zusammenhang',
      });
      final client = AvesmapsClient(
        httpClient: MockClient((_) async => antwort),
      );
      final ohne = await client.route(_anfrage());
      expect(ohne.gefunden, isFalse);
      expect(ohne.grund, 'kein_zusammenhang');

      antwort = _json(<String, Object?>{
        'error': <String, Object?>{'code': 'place_not_found'},
      }, status: 404);
      final unbekannt = await client.route(_anfrage());
      expect(unbekannt.grund, AvesmapsRoute.grundOrtUnbekannt);
    });

    test('ungültige Kennung fragt nicht an', () async {
      var anfragen = 0;
      final client = AvesmapsClient(
        httpClient: MockClient((_) async {
          anfragen++;
          return _json(_routeAntwort);
        }),
      );
      final route = await client.route(
        AvesmapsRoutenAnfrage(vonId: 'gareth', nachId: _perricum),
      );
      expect(route.gefunden, isFalse);
      expect(anfragen, 0);
    });
  });

  group('AvesmapsRoutenRepository', () {
    late DateTime jetzt;
    late int anfragen;
    late http.Response Function() antwort;
    late FluechtigerAvesmapsRoutenSpeicher speicher;
    late AvesmapsRoutenRepository repository;

    setUp(() {
      jetzt = DateTime.utc(2026, 11, 20, 12);
      anfragen = 0;
      antwort = () => _json(_routeAntwort);
      speicher = FluechtigerAvesmapsRoutenSpeicher();
      repository = AvesmapsRoutenRepository(
        client: AvesmapsClient(
          httpClient: MockClient((_) async {
            anfragen++;
            return antwort();
          }),
        ),
        speicher: speicher,
        jetzt: () => jetzt,
      );
    });

    test('hole merkt den Weg; gemerkt liest ohne Netz', () async {
      final anfrage = _anfrage();
      await repository.hole(anfrage);
      final gemerkt = await repository.gemerkt();
      expect(anfragen, 1);
      expect(gemerkt[anfrage.schluessel]!.meilen, 341.45);
    });

    test('abgelaufene Wege verschwinden: 30 Tage, ohne Weg 1 Tag', () async {
      await repository.hole(_anfrage());
      antwort = () => _json(<String, Object?>{'gefunden': false});
      await repository.hole(_anfrage(wege: <String>['see']));

      jetzt = jetzt.add(const Duration(days: 2));
      expect((await repository.gemerkt()).keys, [_anfrage().schluessel]);

      jetzt = jetzt.add(const Duration(days: 29));
      expect(await repository.gemerkt(), isEmpty);
      expect(await speicher.alle(), isEmpty);
    });

    test('nach 429 fragt es bis zur Wartezeit nicht erneut', () async {
      antwort = () => _json(null, status: 429, warte: '30');
      await expectLater(
        repository.hole(_anfrage()),
        throwsA(
          isA<AvesmapsFehler>()
              .having((f) => f.art, 'art', AvesmapsFehlerArt.gedrosselt)
              .having((f) => f.wartezeit, 'wartezeit', Duration(seconds: 30)),
        ),
      );
      antwort = () => _json(_routeAntwort);
      await expectLater(
        repository.hole(_anfrage()),
        throwsA(isA<AvesmapsFehler>()),
      );
      expect(anfragen, 1);

      jetzt = jetzt.add(const Duration(seconds: 31));
      await repository.hole(_anfrage());
      expect(anfragen, 2);
    });
  });
}
