import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_access_client.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_gunzip.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_proof.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_remote_client.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_sync_service.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_types.dart';

import 'rules_index_test_fixture.dart';

// SPIEL-04: Zugang zur Regel-Wissensbasis über die Cloud (Passwortnachweis,
// Zugangs-Client, Download von der signierten URL, Installation).

class _Gateway implements RulesIndexAccessGateway {
  _Gateway(this.release, {this.fehler});

  final RulesIndexRelease release;
  final Object? fehler;
  final List<String> nachweise = <String>[];

  @override
  Future<RulesIndexRelease> requestAccess({required String proof}) async {
    nachweise.add(proof);
    if (fehler != null) throw fehler!;
    return release;
  }
}

RulesIndexRelease _release(
  Uint8List entpackt, {
  String? sha,
  String? version,
}) => RulesIndexRelease(
  url: Uri.parse('https://storage.test/rules/index.sqlite.gz?sig=x'),
  version: version ?? '2026-10-23T12:00:00Z',
  sha256: sha ?? sha256Hex(entpackt),
  sizeBytes: entpackt.length,
);

void main() {
  group('rulesIndexProof', () {
    final salt = Uint8List.fromList(List<int>.generate(32, (i) => i));

    test('stimmt mit tool/rules_index_proof.py überein (Golden)', () {
      // Berechnet mit
      // `rules_index_proof('testpasswort', bytes(range(32)))`.
      expect(
        rulesIndexProof(password: 'testpasswort', salt: salt),
        '265b04b8273a639db346e8c5daec2fc840356986d6fdc095988b94d00ccb58d3',
      );
    });

    test('NFC und NFD desselben Passworts ergeben denselben Nachweis', () {
      const goldenUebung =
          '2af18829d43b57e3b1cf627acc99fbfdc257c02b2b89e3d23a7fdb76e24d0960';
      expect(rulesIndexProof(password: 'Übung', salt: salt), goldenUebung);
      expect(rulesIndexProof(password: 'Übung', salt: salt), goldenUebung);
    });

    test('anderes Passwort oder anderer Salt ändern den Nachweis', () {
      final basis = rulesIndexProof(password: 'testpasswort', salt: salt);
      expect(
        rulesIndexProof(password: 'Testpasswort', salt: salt),
        isNot(basis),
      );
      expect(
        rulesIndexProof(
          password: 'testpasswort',
          salt: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
        ),
        isNot(basis),
      );
      expect(basis, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('sha256Hex kennt den Standardwert', () {
      expect(
        sha256Hex(Uint8List.fromList(utf8.encode('abc'))),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });
  });

  group('RulesIndexAccessClient', () {
    const antwort = <String, Object?>{
      'url': 'https://storage.test/rules/index-0123456789ab.sqlite.gz?sig=x',
      'version': '2026-10-23T12:00:00Z',
      'sha256': 'ab',
      'sizeBytes': 117000000,
      'expiresInSeconds': 600,
    };

    RulesIndexAccessClient client(
      http.Client http, {
      String? idToken = 'id-token',
      String? appCheck = 'app-check',
    }) => RulesIndexAccessClient(
      endpoint: Uri.parse('https://api.test/rulesIndexApi'),
      idTokenProvider: () async => idToken,
      appCheckTokenProvider: () async => appCheck,
      httpClient: http,
    );

    Future<RulesIndexDownloadException> fehlschlag(
      int status,
      Map<String, Object?> body,
    ) async {
      final c = client(
        MockClient((_) async => http.Response(jsonEncode(body), status)),
      );
      try {
        await c.requestAccess(proof: 'a' * 64);
      } on RulesIndexDownloadException catch (error) {
        return error;
      }
      fail('Es hätte eine Ausnahme geben müssen.');
    }

    test(
      'sendet Token, App Check und Nachweis und liest die Antwort',
      () async {
        late http.Request gesehen;
        final c = client(
          MockClient((request) async {
            gesehen = request;
            return http.Response(jsonEncode(antwort), 200);
          }),
        );

        final release = await c.requestAccess(proof: 'f' * 64);

        expect(gesehen.method, 'POST');
        expect(gesehen.url.toString(), 'https://api.test/rulesIndexApi');
        expect(gesehen.headers['authorization'], 'Bearer id-token');
        expect(gesehen.headers['x-firebase-appcheck'], 'app-check');
        expect(jsonDecode(gesehen.body), <String, Object?>{'proof': 'f' * 64});
        expect(release.version, '2026-10-23T12:00:00Z');
        expect(release.sizeBytes, 117000000);
        expect(release.url.host, 'storage.test');
      },
    );

    test('ohne Anmeldung oder App Check wird nichts gesendet', () async {
      var aufrufe = 0;
      final zaehler = MockClient((_) async {
        aufrufe++;
        return http.Response('{}', 500);
      });

      await expectLater(
        client(zaehler, idToken: null).requestAccess(proof: 'a' * 64),
        throwsA(
          isA<RulesIndexDownloadException>().having(
            (e) => e.message,
            'message',
            contains('anmelden'),
          ),
        ),
      );
      await expectLater(
        client(zaehler, appCheck: '').requestAccess(proof: 'a' * 64),
        throwsA(
          isA<RulesIndexDownloadException>().having(
            (e) => e.message,
            'message',
            contains('App Check'),
          ),
        ),
      );
      expect(aufrufe, 0);
    });

    test('Fehler beim Holen eines Tokens zählen als fehlendes Token', () async {
      final c = RulesIndexAccessClient(
        endpoint: Uri.parse('https://api.test/x'),
        idTokenProvider: () async => throw StateError('kaputt'),
        appCheckTokenProvider: () async => 'x',
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      await expectLater(
        c.requestAccess(proof: 'a' * 64),
        throwsA(isA<RulesIndexDownloadException>()),
      );
    });

    test('übersetzt Serverfehler in verständliche Meldungen', () async {
      final auth = await fehlschlag(401, {'code': 'AUTH_INVALID'});
      expect(auth.kind, RulesIndexDownloadErrorKind.unauthorized);
      expect(auth.message, contains('anmelden'));

      final appCheck = await fehlschlag(401, {'code': 'APP_CHECK_INVALID'});
      expect(appCheck.message, contains('App Check'));

      final nachweis = await fehlschlag(403, {'code': 'PROOF_INVALID'});
      expect(nachweis.kind, RulesIndexDownloadErrorKind.unauthorized);
      expect(nachweis.message, contains('Katalogpasswort'));

      final keine = await fehlschlag(404, {'code': 'NO_RELEASE'});
      expect(keine.kind, RulesIndexDownloadErrorKind.notFound);

      final aus = await fehlschlag(503, {'code': 'SERVICE_DISABLED'});
      expect(aus.kind, RulesIndexDownloadErrorKind.other);
      expect(aus.message, contains('nicht verfügbar'));

      final sonst = await fehlschlag(500, {});
      expect(sonst.message, contains('500'));
    });

    test('eine unvollständige 200-Antwort ist kein Erfolg', () async {
      for (final body in <Map<String, Object?>>[
        {},
        {...antwort, 'url': ''},
        {...antwort, 'sizeBytes': 0},
        {...antwort}..remove('sha256'),
      ]) {
        final fehler = await fehlschlag(200, body);
        expect(
          fehler.message,
          contains('Unerwartete Antwort'),
          reason: '$body',
        );
      }
    });

    test('ein Netzfehler wird als Netzfehler gemeldet', () async {
      final c = client(
        MockClient((_) async => throw const SocketException('weg')),
      );
      await expectLater(
        c.requestAccess(proof: 'a' * 64),
        throwsA(
          isA<RulesIndexDownloadException>().having(
            (e) => e.kind,
            'kind',
            RulesIndexDownloadErrorKind.network,
          ),
        ),
      );
    });
  });

  group('downloadSigned', () {
    test('sendet keine Zugangsdaten und meldet den Fortschritt', () async {
      late http.BaseRequest gesehen;
      final remote = RulesIndexRemoteClient(
        httpClient: MockClient.streaming((request, _) async {
          gesehen = request;
          return http.StreamedResponse(
            Stream<List<int>>.fromIterable(<List<int>>[
              <int>[1, 2, 3],
              <int>[4, 5],
            ]),
            200,
          );
        }),
      );
      final fortschritt = <int>[];

      final bytes = await remote.downloadSigned(
        Uri.parse('https://storage.test/x?sig=1'),
        onProgress: fortschritt.add,
      );

      expect(bytes, <int>[1, 2, 3, 4, 5]);
      expect(fortschritt, <int>[3, 5]);
      expect(gesehen.headers.containsKey('authorization'), isFalse);
    });

    test('übersetzt abgelaufene und fehlende Adressen', () async {
      Future<RulesIndexDownloadException> mit(int status) async {
        final remote = RulesIndexRemoteClient(
          httpClient: MockClient((_) async => http.Response('', status)),
        );
        try {
          await remote.downloadSigned(Uri.parse('https://storage.test/x'));
        } on RulesIndexDownloadException catch (error) {
          return error;
        }
        fail('Es hätte eine Ausnahme geben müssen.');
      }

      expect((await mit(403)).message, contains('abgelaufen'));
      expect((await mit(404)).kind, RulesIndexDownloadErrorKind.notFound);
      expect((await mit(500)).kind, RulesIndexDownloadErrorKind.other);
    });

    test('ein abgebrochener Datenstrom ist ein Netzfehler', () async {
      final remote = RulesIndexRemoteClient(
        httpClient: MockClient.streaming((_, _) async {
          return http.StreamedResponse(
            Stream<List<int>>.error(const SocketException('abgebrochen')),
            200,
          );
        }),
      );
      await expectLater(
        remote.downloadSigned(Uri.parse('https://storage.test/x')),
        throwsA(
          isA<RulesIndexDownloadException>().having(
            (e) => e.kind,
            'kind',
            RulesIndexDownloadErrorKind.network,
          ),
        ),
      );
    });
  });

  group('gunzipIfNeeded', () {
    test('lässt ungepackte Bytes unverändert', () {
      final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
      expect(gunzipIfNeeded(bytes), bytes);
      expect(isGzip(bytes), isFalse);
    });

    test('entpackt gzip, wenn es noch gepackt ankommt', () {
      final original = Uint8List.fromList(
        List<int>.generate(500, (i) => i % 7),
      );
      final gepackt = Uint8List.fromList(gzip.encode(original));
      expect(isGzip(gepackt), isTrue);
      expect(gunzipIfNeeded(gepackt), original);
    });

    test('beschädigtes gzip ist ein Formatfehler', () {
      final kaputt = Uint8List.fromList(<int>[0x1f, 0x8b, 8, 0, 1, 2, 3]);
      expect(() => gunzipIfNeeded(kaputt), throwsFormatException);
    });
  });

  group('RulesIndexSyncService.syncFromCloud', () {
    late Directory dataDirectory;
    late String cache;

    setUp(() {
      dataDirectory = Directory.systemTemp.createTempSync('rules-index-cloud-');
      cache = p.join(dataDirectory.path, 'index_remote.sqlite');
    });

    tearDown(() => dataDirectory.deleteSync(recursive: true));

    RulesIndexSyncService dienst(
      RulesIndexAccessGateway gateway,
      http.Client client,
    ) => RulesIndexSyncService(
      remoteClient: RulesIndexRemoteClient(httpClient: client),
      accessGateway: gateway,
      dataDirectory: dataDirectory.path,
    );

    test('lädt, prüft und installiert eine ungepackte Datei', () async {
      final fixture = buildMinimalRulesIndexBytes();
      final gateway = _Gateway(_release(fixture));
      final fortschritt = <(int, int)>[];

      final ergebnis =
          await dienst(
            gateway,
            MockClient((_) async => http.Response.bytes(fixture, 200)),
          ).syncFromCloud(
            proof: 'a' * 64,
            onProgress: (received, total) => fortschritt.add((received, total)),
          );

      final search = ergebnis.search!;
      try {
        expect(
          search.search(
            'Behinderung',
            categories: RulesSourceCategory.values.toSet(),
          ),
          isNotEmpty,
        );
      } finally {
        search.dispose();
      }
      expect(ergebnis.version, '2026-10-23T12:00:00Z');
      expect(gateway.nachweise, <String>['a' * 64]);
      expect(fortschritt.last, (fixture.length, fixture.length));
      expect(File(cache).existsSync(), isTrue);
    });

    test('entpackt eine noch gepackte Antwort selbst', () async {
      final fixture = buildMinimalRulesIndexBytes();
      final gepackt = Uint8List.fromList(gzip.encode(fixture));

      final ergebnis = await dienst(
        _Gateway(_release(fixture)),
        MockClient((_) async => http.Response.bytes(gepackt, 200)),
      ).syncFromCloud(proof: 'a' * 64);

      expect(ergebnis.search, isNotNull);
      ergebnis.search!.dispose();
    });

    test('eine verfälschte Datei wird nie installiert', () async {
      final fixture = buildMinimalRulesIndexBytes();
      final verfaelscht = Uint8List.fromList(fixture)..[100] ^= 0xff;

      await expectLater(
        dienst(
          _Gateway(_release(fixture)),
          MockClient((_) async => http.Response.bytes(verfaelscht, 200)),
        ).syncFromCloud(proof: 'a' * 64),
        throwsA(isA<FormatException>()),
      );
      expect(File(cache).existsSync(), isFalse);
    });

    test('falsche Größe oder falsche Prüfsumme sind Formatfehler', () async {
      final fixture = buildMinimalRulesIndexBytes();
      for (final release in <RulesIndexRelease>[
        _release(fixture, sha: 'f' * 64),
        RulesIndexRelease(
          url: Uri.parse('https://storage.test/x'),
          version: 'v',
          sha256: sha256Hex(fixture),
          sizeBytes: fixture.length + 1,
        ),
      ]) {
        await expectLater(
          dienst(
            _Gateway(release),
            MockClient((_) async => http.Response.bytes(fixture, 200)),
          ).syncFromCloud(proof: 'a' * 64),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('ist die Version schon installiert, entfällt der Download', () async {
      final fixture = buildMinimalRulesIndexBytes();
      var downloads = 0;

      final ergebnis =
          await dienst(
            _Gateway(_release(fixture)),
            MockClient((_) async {
              downloads++;
              return http.Response.bytes(fixture, 200);
            }),
          ).syncFromCloud(
            proof: 'a' * 64,
            installedVersion: '2026-10-23T12:00:00Z',
            skipIfCurrent: true,
          );

      expect(ergebnis.search, isNull);
      expect(ergebnis.version, '2026-10-23T12:00:00Z');
      expect(downloads, 0);
    });

    test('eine andere Version wird auch mit skipIfCurrent geladen', () async {
      final fixture = buildMinimalRulesIndexBytes();
      final ergebnis =
          await dienst(
            _Gateway(_release(fixture, version: '2026-11-01T00:00:00Z')),
            MockClient((_) async => http.Response.bytes(fixture, 200)),
          ).syncFromCloud(
            proof: 'a' * 64,
            installedVersion: '2026-10-23T12:00:00Z',
            skipIfCurrent: true,
          );
      expect(ergebnis.search, isNotNull);
      ergebnis.search!.dispose();
    });

    test('Fehler des Zugangs erreichen den Aufrufer unverändert', () async {
      const fehler = RulesIndexDownloadException(
        RulesIndexDownloadErrorKind.unauthorized,
        'Das Katalogpasswort passt nicht zum Server.',
      );
      await expectLater(
        dienst(
          _Gateway(_release(Uint8List(1)), fehler: fehler),
          MockClient((_) async => http.Response('', 200)),
        ).syncFromCloud(proof: 'a' * 64),
        throwsA(same(fehler)),
      );
    });

    test('ohne Zugang im Build gibt es eine klare Meldung', () async {
      await expectLater(
        RulesIndexSyncService().syncFromCloud(proof: 'a' * 64),
        throwsA(
          isA<RulesIndexDownloadException>().having(
            (e) => e.message,
            'message',
            contains('kein Server'),
          ),
        ),
      );
    });
  });
}
