import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointycastle/digests/sha256.dart';

import 'package:dsa_heldenverwaltung/data/freesound/freesound_client.dart';
import 'package:dsa_heldenverwaltung/data/freesound/freesound_oauth.dart';
import 'package:dsa_heldenverwaltung/data/freesound/freesound_zugang_ablage.dart';
import 'package:dsa_heldenverwaltung/data/freesound/klang_spieler.dart';
import 'package:dsa_heldenverwaltung/domain/klangstimmung.dart';
import 'package:dsa_heldenverwaltung/state/klangkulisse_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_klangkulisse.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

Map<String, Object?> _klang(
  int id, {
  String lizenz = 'http://creativecommons.org/publicdomain/zero/1.0/',
}) => {
  'id': id,
  'name': 'Klang $id',
  'username': 'urheber$id',
  'license': lizenz,
  'duration': 95.4,
  'url': 'https://freesound.org/people/u/sounds/$id/',
  'previews': {
    'preview-hq-mp3': 'https://cdn.freesound.org/previews/$id-hq.mp3',
  },
};

http.Response _json(Object wert, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(wert)), status);

http.Response _treffer(List<Object?> ergebnisse) =>
    _json({'count': ergebnisse.length, 'results': ergebnisse});

Map<String, Object?> _tokenAntwort(String access, String refresh) => {
  'access_token': access,
  'refresh_token': refresh,
  'expires_in': 86399,
  'scope': 'read write read+write',
};

FreesoundZugang _zugang({
  String access = 'a1',
  String refresh = 'r1',
  DateTime? ablauf,
}) => FreesoundZugang(
  accessToken: access,
  refreshToken: refresh,
  ablauf: ablauf ?? DateTime.now().toUtc().add(const Duration(hours: 12)),
);

void main() {
  group('FreesoundClient', () {
    test(
      'sendet Bearer-Token und Filter, überspringt Klänge ohne Vorschau',
      () async {
        http.Request? gesendet;
        final client = FreesoundClient(
          token: ({erneuern = false}) async => 'abc',
          httpClient: MockClient((anfrage) async {
            gesendet = anfrage;
            return _treffer([
              _klang(1),
              {'id': 2, 'name': 'ohne Vorschau'},
              _klang(
                3,
                lizenz: 'https://creativecommons.org/licenses/by-nc/4.0/',
              ),
            ]);
          }),
        );
        final treffer = await client.suche(' rain ', mindestSekunden: 30);
        expect(gesendet!.headers['Authorization'], 'Bearer abc');
        expect(gesendet!.url.queryParameters['query'], 'rain');
        expect(gesendet!.url.queryParameters['filter'], 'duration:[30.0 TO *]');
        expect(treffer.map((k) => k.id), [1, 3]);
        expect(treffer.first.lizenzKurz, 'CC0');
        expect(treffer.last.lizenzKurz, 'CC BY-NC');
      },
    );

    test('Lizenzkurzname für CC BY', () {
      const klang = FreesoundKlang(
        id: 1,
        name: 'n',
        urheber: 'u',
        lizenz: 'https://creativecommons.org/licenses/by/4.0/',
        vorschauUrl: 'x',
        seite: 'y',
      );
      expect(klang.lizenzKurz, 'CC BY');
    });

    test('401 erneuert das Token einmal und wiederholt', () async {
      final tokens = <String>[];
      final erneuert = <bool>[];
      final client = FreesoundClient(
        token: ({erneuern = false}) async {
          erneuert.add(erneuern);
          return erneuern ? 'neu' : 'alt';
        },
        httpClient: MockClient((anfrage) async {
          tokens.add(anfrage.headers['Authorization']!);
          return tokens.length == 1
              ? http.Response('', 401)
              : _treffer([_klang(1)]);
        }),
      );
      expect(await client.suche('rain'), hasLength(1));
      expect(tokens, ['Bearer alt', 'Bearer neu']);
      expect(erneuert, [false, true]);
    });

    for (final (status, art) in [
      (401, FreesoundFehlerArt.anmeldung),
      (429, FreesoundFehlerArt.gedrosselt),
      (500, FreesoundFehlerArt.antwort),
    ]) {
      test('Status $status ergibt $art', () async {
        final client = FreesoundClient(
          token: ({erneuern = false}) async => 't',
          httpClient: MockClient((_) async => http.Response('', status)),
        );
        await expectLater(
          client.suche('rain'),
          throwsA(isA<FreesoundFehler>().having((f) => f.art, 'art', art)),
        );
      });
    }
  });

  group('FreesoundOAuth', () {
    test('Anmeldeadresse mit PKCE S256, Codetausch ohne Secret', () async {
      Map<String, String>? felder;
      final oauth = FreesoundOAuth(
        clientId: 'cid',
        zufall: Random(1),
        uhr: () => DateTime.utc(2026, 11, 26, 12),
        httpClient: MockClient((anfrage) async {
          felder = anfrage.bodyFields;
          expect(anfrage.url.path, '/apiv2/oauth2/access_token/');
          return _json(_tokenAntwort('acc', 'ref'));
        }),
      );
      final anmeldung = oauth.starte();
      final q = anmeldung.adresse.queryParameters;
      expect(anmeldung.adresse.path, '/apiv2/oauth2/authorize/');
      expect(q['client_id'], 'cid');
      expect(q['response_type'], 'code');
      expect(q['code_challenge_method'], 'S256');
      expect(q['state'], anmeldung.state);
      expect(q['redirect_uri'], kFreesoundRedirectUri);
      final erwartet = base64Url
          .encode(
            SHA256Digest().process(utf8.encoder.convert(anmeldung.verifier)),
          )
          .replaceAll('=', '');
      expect(q['code_challenge'], erwartet);

      final zugang = await oauth.tausche(' CODE123 ', anmeldung);
      expect(felder, {
        'client_id': 'cid',
        'grant_type': 'authorization_code',
        'code': 'CODE123',
        'code_verifier': anmeldung.verifier,
        'redirect_uri': kFreesoundRedirectUri,
      });
      expect(zugang.accessToken, 'acc');
      expect(zugang.ablauf, DateTime.utc(2026, 11, 27, 11, 59, 59));
    });

    test('leseCode nimmt Code aus der Adresse und prüft state', () {
      expect(
        leseCode('https://x.org/cb?code=abc&state=s1', erwarteterState: 's1'),
        'abc',
      );
      expect(leseCode('abc', erwarteterState: 's1'), 'abc');
      expect(
        () => leseCode(
          'https://x.org/cb?code=abc&state=fremd',
          erwarteterState: 's1',
        ),
        throwsA(isA<FreesoundFehler>()),
      );
      expect(
        () => leseCode(
          'https://x.org/cb?error=access_denied',
          erwarteterState: 's1',
        ),
        throwsA(isA<FreesoundFehler>()),
      );
      expect(
        () => leseCode('  ', erwarteterState: 's1'),
        throwsA(isA<FreesoundFehler>()),
      );
    });

    test('Zugang übersteht die Speicherform', () {
      final zugang = _zugang(ablauf: DateTime.utc(2026, 11, 27));
      final zurueck = FreesoundZugang.ausJson(
        jsonDecode(jsonEncode(zugang.toJson())),
      )!;
      expect(zurueck.accessToken, 'a1');
      expect(zurueck.refreshToken, 'r1');
      expect(zurueck.ablauf, DateTime.utc(2026, 11, 27));
      expect(FreesoundZugang.ausJson({'access': 1}), isNull);
    });
  });

  group('FreesoundZugangNotifier', () {
    ProviderContainer container(
      FluechtigeFreesoundZugangAblage ablage,
      MockClient netz,
    ) {
      final c = ProviderContainer(
        overrides: [
          freesoundZugangAblageProvider.overrideWithValue(ablage),
          freesoundOAuthProvider.overrideWithValue(
            FreesoundOAuth(clientId: 'cid', httpClient: netz),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('abgelaufenes Token wird erneuert und gespeichert; gleichzeitige '
        'Anfragen teilen eine Erneuerung', () async {
      var tausche = 0;
      final ablage = FluechtigeFreesoundZugangAblage(
        _zugang(ablauf: DateTime.utc(2000)),
      );
      final c = container(
        ablage,
        MockClient((anfrage) async {
          tausche++;
          expect(anfrage.bodyFields['grant_type'], 'refresh_token');
          expect(anfrage.bodyFields['refresh_token'], 'r1');
          return _json(_tokenAntwort('a2', 'r2'));
        }),
      );
      final zugang = c.read(freesoundZugangProvider.notifier);
      final tokens = await Future.wait([zugang.token(), zugang.token()]);
      expect(tokens, ['a2', 'a2']);
      expect(tausche, 1);
      expect(ablage.wert!.refreshToken, 'r2');
    });

    test('abgelehnte Erneuerung meldet ab', () async {
      final ablage = FluechtigeFreesoundZugangAblage(_zugang());
      final c = container(
        ablage,
        MockClient(
          (_) async => http.Response('{"error":"invalid_grant"}', 400),
        ),
      );
      await c.read(freesoundZugangProvider.future);
      await expectLater(
        c.read(freesoundZugangProvider.notifier).token(erneuern: true),
        throwsA(isA<FreesoundFehler>()),
      );
      expect(ablage.wert, isNull);
      expect(c.read(freesoundZugangProvider).asData?.value, isNull);
    });

    test('Anmeldung abschließen speichert den Zugang', () async {
      final ablage = FluechtigeFreesoundZugangAblage();
      final c = container(
        ablage,
        MockClient((_) async => _json(_tokenAntwort('acc', 'ref'))),
      );
      await c.read(freesoundZugangProvider.future);
      final zugang = c.read(freesoundZugangProvider.notifier);
      await expectLater(
        zugang.anmeldungAbschliessen('code'),
        throwsA(isA<FreesoundFehler>()),
      );
      zugang.anmeldungStarten();
      await zugang.anmeldungAbschliessen('code');
      expect(ablage.wert!.accessToken, 'acc');
      expect(c.read(freesoundClientProvider), isNotNull);
      await zugang.abmelden();
      expect(ablage.wert, isNull);
      expect(c.read(freesoundClientProvider), isNull);
    });
  });

  group('FreesoundClient Längenfilter', () {
    test('Höchstlänge ohne Mindestlänge', () async {
      http.Request? gesendet;
      final client = FreesoundClient(
        token: ({erneuern = false}) async => 't',
        httpClient: MockClient((anfrage) async {
          gesendet = anfrage;
          return _treffer([]);
        }),
      );
      await client.suche('door', hoechstSekunden: 6);
      expect(gesendet!.url.queryParameters['filter'], 'duration:[* TO 6.0]');
    });
  });

  group('KlangpultNotifier', () {
    late List<StummerKlangKanal> kanaele;
    late List<String> anfragen;

    ProviderContainer container({FreesoundZugang? zugang}) {
      kanaele = <StummerKlangKanal>[];
      anfragen = <String>[];
      final ids = <String, int>{};
      final c = ProviderContainer(
        overrides: [
          freesoundZugangAblageProvider.overrideWithValue(
            FluechtigeFreesoundZugangAblage(zugang),
          ),
          klangKanalFabrikProvider.overrideWithValue(() {
            final kanal = StummerKlangKanal();
            kanaele.add(kanal);
            return kanal;
          }),
          freesoundClientProvider.overrideWith((ref) {
            final da = ref.watch(
              freesoundZugangProvider.select((z) => z.asData?.value != null),
            );
            if (!da) return null;
            return FreesoundClient(
              token: ({erneuern = false}) async => 't',
              httpClient: MockClient((anfrage) async {
                final q = anfrage.url.queryParameters;
                anfragen.add('${q['query']} ${q['filter']}');
                // Jede Suche liefert eigene Kennungen, damit Kanäle
                // unterscheidbar bleiben.
                final basis = ids.putIfAbsent(q['query']!, () => ids.length);
                return _treffer([
                  _klang(basis * 10 + 1),
                  _klang(basis * 10 + 2),
                ]);
              }),
            );
          }),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Klangszene szene(String id) => kKlangszenen.firstWhere((s) => s.id == id);

    test('Szene startet je Ebene eine Schleife, Wechsel blendet aus, '
        'Rückkehr kommt aus dem Cache', () async {
      final c = container(zugang: _zugang());
      await c.read(freesoundZugangProvider.future);
      final pult = c.read(klangkulisseProvider.notifier);
      await pult.szeneWaehlen(szene('taverne'));
      expect(kanaele, hasLength(2));
      expect(kanaele.every((k) => k.schleife == true && k.url != null), isTrue);
      expect(kanaele.map((k) => k.lautstaerke), [
        closeTo(0.8 * 0.6, 1e-9),
        closeTo(0.8 * 0.4, 1e-9),
      ]);
      expect(anfragen.first, 'tavern ambience crowd duration:[30.0 TO *]');
      expect(c.read(klangkulisseProvider).laeuft, isTrue);

      await pult.szeneWaehlen(szene('wald'));
      expect(kanaele.take(2).every((k) => k.ausgeblendet), isTrue);
      expect(kanaele, hasLength(5));

      final bisher = anfragen.length;
      await pult.szeneWaehlen(szene('taverne'));
      expect(anfragen, hasLength(bisher));
      expect(kanaele, hasLength(7));
    });

    test('Musik blendet über, Sieg läuft einmal, Aus blendet aus', () async {
      final c = container(zugang: _zugang());
      await c.read(freesoundZugangProvider.future);
      final pult = c.read(klangkulisseProvider.notifier);
      await pult.szeneWaehlen(szene('taverne'));
      await pult.musik(Musiklage.erkunden);
      final erkunden = kanaele.last;
      expect(erkunden.schleife, isTrue);
      expect(anfragen.last, 'tavern music medieval duration:[30.0 TO *]');
      expect(erkunden.lautstaerke, closeTo(0.8 * 0.4, 1e-9));

      await pult.musik(Musiklage.sieg);
      expect(erkunden.ausgeblendet, isTrue);
      expect(kanaele.last.schleife, isFalse);
      expect(anfragen.last, 'victory fanfare duration:[* TO 20.0]');

      await pult.musik(null);
      expect(kanaele.last.ausgeblendet, isTrue);
      expect(c.read(klangkulisseProvider).musikKlang, isNull);
    });

    test('Effekt spielt einmal und steht in den Quellen', () async {
      final c = container(zugang: _zugang());
      await c.read(freesoundZugangProvider.future);
      final pult = c.read(klangkulisseProvider.notifier);
      final tuer = szene('taverne').effekte.first;
      await pult.effekt(tuer);
      expect(kanaele.single.schleife, isFalse);
      expect(anfragen.single, 'wooden door creak duration:[* TO 6.0]');
      expect(c.read(klangkulisseProvider).quellen, hasLength(1));
    });

    test(
      'Gesamt- und Ebenenstärke multiplizieren sich; Ebene aus und an',
      () async {
        final c = container(zugang: _zugang());
        await c.read(freesoundZugangProvider.future);
        final pult = c.read(klangkulisseProvider.notifier);
        await pult.szeneWaehlen(szene('taverne'));
        await pult.gesamtLautstaerke(0.5);
        expect(kanaele.first.lautstaerke, closeTo(0.5 * 0.6, 1e-9));
        await pult.ebenenStaerke('menge', 1);
        expect(kanaele.first.lautstaerke, closeTo(0.5, 1e-9));

        await pult.ebeneUmschalten('feuer');
        expect(kanaele[1].ausgeblendet, isTrue);
        expect(c.read(klangkulisseProvider).ebenen['feuer']!.an, isFalse);
        await pult.ebeneUmschalten('feuer');
        expect(kanaele, hasLength(3));
        expect(kanaele.last.ausgeblendet, isFalse);

        await pult.andererKlang('menge');
        expect(kanaele.first.ausgeblendet, isTrue);
        expect(kanaele.last.url, isNot(kanaele.first.url));
      },
    );

    test('Abmelden lässt das Pult verstummen', () async {
      final c = container(zugang: _zugang());
      await c.read(freesoundZugangProvider.future);
      await c
          .read(klangkulisseProvider.notifier)
          .szeneWaehlen(szene('taverne'));
      await c.read(freesoundZugangProvider.notifier).abmelden();
      await Future<void>.delayed(Duration.zero);
      expect(kanaele.every((k) => k.ausgeblendet), isTrue);
      expect(c.read(klangkulisseProvider).laeuft, isFalse);
      expect(c.read(klangkulisseProvider).szeneId, isNull);
    });

    test('ohne Anmeldung keine Anfrage, nur Hinweis', () async {
      final c = container();
      await c.read(freesoundZugangProvider.future);
      await c
          .read(klangkulisseProvider.notifier)
          .szeneWaehlen(szene('taverne'));
      expect(anfragen, isEmpty);
      expect(kanaele, isEmpty);
      expect(c.read(klangkulisseProvider).fehler, contains('anmelden'));
    });
  });

  Future<void> zeigeApp(
    WidgetTester tester,
    ProviderContainer container, {
    bool sichtbar = true,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildKartoTheme(
            brightness: Brightness.light,
            centerAppBarTitle: false,
          ),
          builder: (context, child) =>
              KartoKlangpultHuelle(sichtbar: sichtbar, child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('Gefecht')),
                  ),
                ),
                child: const Text('Zum Gefecht'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const lasche = ValueKey('karto-klangpult-lasche');

  testWidgets('ausgeblendet gibt es keine Lasche', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await zeigeApp(tester, container, sichtbar: false);
    expect(find.byKey(lasche), findsNothing);
  });

  testWidgets('Lasche bleibt auf neuen Routen; ohne Client-ID ein Hinweis', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await zeigeApp(tester, container);
    await tester.tap(find.text('Zum Gefecht'));
    await tester.pumpAndSettle();
    expect(find.text('Gefecht'), findsOneWidget);
    await tester.tap(find.byKey(lasche));
    await tester.pumpAndSettle();
    expect(find.textContaining('nicht eingerichtet'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('karto-klangpult-schliessen')));
    await tester.pumpAndSettle();
    expect(find.byKey(lasche), findsOneWidget);
  });

  testWidgets('angemeldet: Szene wählen zeigt Ebenen und Effekte', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        freesoundZugangAblageProvider.overrideWithValue(
          FluechtigeFreesoundZugangAblage(_zugang()),
        ),
        freesoundClientProvider.overrideWithValue(
          FreesoundClient(
            token: ({erneuern = false}) async => 't',
            httpClient: MockClient((_) async => _treffer([_klang(1)])),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await zeigeApp(tester, container);
    await tester.tap(find.byKey(lasche));
    await tester.pumpAndSettle();
    const menge = ValueKey('karto-klangpult-ebene-menge');
    expect(find.byKey(menge), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('karto-klangpult-szene-taverne')),
    );
    await tester.pumpAndSettle();
    expect(container.read(klangkulisseProvider).szeneId, 'taverne');
    await tester.scrollUntilVisible(find.byKey(menge), 200);
    expect(find.byKey(menge), findsOneWidget);
    const tuer = ValueKey('karto-klangpult-effekt-tuer');
    await tester.scrollUntilVisible(find.byKey(tuer), 200);
    expect(find.byKey(tuer), findsOneWidget);
    expect(container.read(klangkulisseProvider).laeuft, isTrue);
  });
}
