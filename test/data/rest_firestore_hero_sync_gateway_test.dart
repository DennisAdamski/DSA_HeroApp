import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dsa_heldenverwaltung/data/rest_firestore_hero_sync_gateway.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

void main() {
  HeroSheet hero(String id, String name) {
    return HeroSheet(
      id: id,
      name: name,
      level: 1,
      attributes: const Attributes(
        mu: 8,
        kl: 8,
        inn: 8,
        ch: 8,
        ff: 8,
        ge: 8,
        ko: 8,
        kk: 8,
      ),
    );
  }

  RestFirestoreHeroSyncGateway gateway({
    required http.Client client,
    Future<String?> Function()? tokenProvider,
  }) {
    return RestFirestoreHeroSyncGateway(
      userId: 'user-1',
      projectId: 'test-project',
      httpClient: client,
      idTokenProvider: tokenProvider ?? () async => 'token-1',
    );
  }

  group('Beobachtung per Abfrage (SYNC-11)', () {
    String antwort(String lesezeit) => jsonEncode(<Map<String, dynamic>>[
      <String, dynamic>{'readTime': lesezeit},
    ]);

    test(
      'erst alles, dann nur Geändertes seit der Serverzeit minus Rand',
      () async {
        final abfragen = <Map<String, dynamic>>[];
        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/v1/projects/test-project/databases/(default)/documents/'
            'users/user-1:runQuery',
          );
          abfragen.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(antwort('2026-11-16T10:00:00Z'), 200);
        });
        final abo = RestFirestoreHeroSyncGateway(
          userId: 'user-1',
          projectId: 'test-project',
          httpClient: client,
          idTokenProvider: () async => 'token-1',
          pollInterval: const Duration(milliseconds: 5),
          vollabgleichAlle: const Duration(hours: 1),
          ueberlappung: const Duration(minutes: 5),
        ).watchHeroes().listen((_) {});
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await abo.cancel();

        expect(abfragen.length, greaterThan(1));
        final erste = abfragen.first['structuredQuery'] as Map<String, dynamic>;
        expect(erste.containsKey('where'), isFalse);
        expect(erste['from'], [
          {'collectionId': 'heroes'},
        ]);
        final zweite = abfragen[1]['structuredQuery'] as Map<String, dynamic>;
        final filter = (zweite['where'] as Map)['fieldFilter'] as Map;
        expect(filter['field'], {'fieldPath': 'lastModified'});
        expect(filter['op'], 'GREATER_THAN_OR_EQUAL');
        expect(
          DateTime.parse((filter['value'] as Map)['timestampValue']),
          DateTime.utc(2026, 11, 16, 9, 55),
        );
      },
    );

    test('ruht, solange die App nicht sichtbar ist', () async {
      var abfragen = 0;
      final client = MockClient((request) async {
        abfragen++;
        return http.Response(antwort('2026-11-16T10:00:00Z'), 200);
      });
      final sichtbar = ValueNotifier<bool>(false);
      final abo = RestFirestoreHeroSyncGateway(
        userId: 'user-1',
        projectId: 'test-project',
        httpClient: client,
        idTokenProvider: () async => 'token-1',
        pollInterval: const Duration(milliseconds: 5),
        aktiv: sichtbar,
      ).watchHeroStates().listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(abfragen, 1);

      sichtbar.value = true;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await abo.cancel();
      expect(abfragen, greaterThan(1));
    });

    Map<String, dynamic> tombstoneDokument(String revision) =>
        <String, dynamic>{
          'name':
              'projects/test-project/databases/(default)/documents/'
              'users/user-1/heroes/h-1',
          'updateTime': '2026-01-01T12:00:00Z',
          'fields': <String, dynamic>{
            'deleted': {'booleanValue': true},
            'revision': {'stringValue': revision},
            'lastModified': {'timestampValue': '2026-01-01T12:00:00Z'},
          },
        };

    test('entfernt einen unveränderten Tombstone mit Vorbedingung', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(jsonEncode(tombstoneDokument('r-7')), 200);
        }
        return http.Response('{}', 200);
      });
      await gateway(client: client)
          .entferneHeldenTombstone('h-1', revision: 'r-7');

      final loeschen = requests.singleWhere((r) => r.method == 'DELETE');
      expect(
        loeschen.url.queryParameters['currentDocument.updateTime'],
        '2026-01-01T12:00:00.000Z',
      );
    });

    test('lässt einen geänderten Tombstone stehen', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode(tombstoneDokument('r-8')), 200);
      });
      await gateway(client: client)
          .entferneHeldenTombstone('h-1', revision: 'r-7');

      expect(requests.where((r) => r.method == 'DELETE'), isEmpty);
    });
  });

  group('RestFirestoreHeroSyncGateway', () {
    test('watchHeroes überlebt einen Fehlschlag des ersten Abrufs '
        '(SYNC-05)', () async {
      var aufrufe = 0;
      final client = MockClient((request) async {
        aufrufe++;
        if (aufrufe == 1) {
          throw http.ClientException('offline');
        }
        return http.Response('{"documents": []}', 200);
      });
      final beobachtung = RestFirestoreHeroSyncGateway(
        userId: 'user-1',
        projectId: 'test-project',
        httpClient: client,
        idTokenProvider: () async => 'token-1',
        pollInterval: const Duration(milliseconds: 5),
      ).watchHeroes();

      var daten = 0;
      final fehler = <Object>[];
      var beendet = false;
      final abo = beobachtung.listen(
        (_) => daten++,
        onError: fehler.add,
        onDone: () => beendet = true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await abo.cancel();

      expect(fehler.single, isA<SyncNetworkException>());
      expect(daten, greaterThan(0));
      expect(beendet, isFalse);
    });

    test(
      'writes heroes to the authenticated Firestore REST document',
      () async {
        final requests = <http.Request>[];
        final remoteHero = hero('h-1', 'Alrik');
        final client = MockClient((request) async {
          requests.add(request);
          return http.Response(request.body, 200);
        });

        final record = await gateway(client: client)
            .saveHero(remoteHero, previousRevision: null);

        expect(record.hero?.name, 'Alrik');
        expect(record.revision, isNotEmpty);
        expect(record.contentHash, stableContentHash(remoteHero.toJson()));

        final request = requests.single;
        expect(request.method, 'PATCH');
        expect(request.headers['authorization'], 'Bearer token-1');
        expect(
          request.url.toString(),
          'https://firestore.googleapis.com/v1/projects/test-project/'
          'databases/(default)/documents/users/user-1/heroes/h-1',
        );

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final fields = body['fields'] as Map<String, dynamic>;
        expect(fields['deleted'], {'booleanValue': false});
        expect(_payloadName(fields), 'Alrik');
      },
    );

    test('loads heroes and tombstones from Firestore REST documents', () async {
      final remoteHero = hero('h-1', 'Remote Alrik');
      final contentHash = stableContentHash(remoteHero.toJson());
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.headers['authorization'], 'Bearer token-1');
        return http.Response(
          jsonEncode({
            'documents': [
              _document(
                'users/user-1/heroes/h-1',
                _heroFields(
                  payload: remoteHero.toJson(),
                  revision: 'r-1',
                  contentHash: contentHash,
                ),
              ),
              _document(
                'users/user-1/heroes/h-deleted',
                _deletedFields(revision: 'r-2'),
              ),
            ],
          }),
          200,
        );
      });

      final records = await gateway(client: client).loadAllHeroes();

      expect(records, hasLength(2));
      expect(records.first.id, 'h-1');
      expect(records.first.hero?.name, 'Remote Alrik');
      expect(records.first.revision, 'r-1');
      expect(records.first.contentHash, contentHash);
      expect(records.last.id, 'h-deleted');
      expect(records.last.isDeleted, isTrue);
    });

    test('roundtrips hero state records through the REST gateway', () async {
      final state = const HeroState.empty().copyWith(currentLep: 23);
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'PATCH') {
          return http.Response(request.body, 200);
        }
        return http.Response(request.body, 405);
      });

      final record = await gateway(client: client)
          .saveHeroState('h-1', state, previousRevision: null);

      expect(record.heroId, 'h-1');
      expect(record.state?.currentLep, 23);
      expect(requests.single.method, 'PATCH');
      expect(
        requests.single.url.toString(),
        'https://firestore.googleapis.com/v1/projects/test-project/'
        'databases/(default)/documents/users/user-1/hero_states/h-1',
      );
    });

    test('reports missing auth tokens before touching Firestore', () async {
      final client = MockClient((request) async {
        fail('Firestore must not be called without an ID token.');
      });

      await expectLater(
        gateway(
          client: client,
          tokenProvider: () async => null,
        ).loadAllHeroes(),
        throwsA(isA<SyncAuthException>()),
      );
    });

    test('maps 401 responses to SyncAuthException', () async {
      final client = MockClient((request) async {
        return http.Response('{"error": {"status": "UNAUTHENTICATED"}}', 401);
      });

      await expectLater(
        gateway(client: client).loadAllHeroes(),
        throwsA(isA<SyncAuthException>()),
      );
    });

    test('maps 5xx responses to SyncNetworkException', () async {
      final client = MockClient((request) async {
        return http.Response('{"error": {"status": "UNAVAILABLE"}}', 503);
      });

      await expectLater(
        gateway(client: client).loadAllHeroes(),
        throwsA(isA<SyncNetworkException>()),
      );
    });

    test('maps 409 responses to SyncPreconditionException', () async {
      final client = MockClient((request) async {
        return http.Response('{"error": {"status": "ABORTED"}}', 409);
      });

      await expectLater(
        gateway(client: client)
            .saveHero(hero('h-1', 'Alrik'), previousRevision: null),
        throwsA(isA<SyncPreconditionException>()),
      );
    });

    test(
      'enforces previousRevision via GET and updateTime precondition',
      () async {
        final requests = <http.Request>[];
        final remoteHero = hero('h-1', 'Alrik');
        final client = MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'name':
                    'projects/test-project/databases/(default)/documents/'
                    'users/user-1/heroes/h-1',
                'updateTime': '2026-01-01T12:00:00Z',
                'fields': _heroFields(
                  payload: remoteHero.toJson(),
                  revision: 'r-1',
                  contentHash: stableContentHash(remoteHero.toJson()),
                ),
              }),
              200,
            );
          }
          return http.Response(request.body, 200);
        });

        await gateway(client: client)
            .saveHero(hero('h-1', 'Alrik 2'), previousRevision: 'r-1');

        expect(requests, hasLength(2));
        expect(requests.first.method, 'GET');
        final patch = requests.last;
        expect(patch.method, 'PATCH');
        expect(
          patch.url.queryParameters['currentDocument.updateTime'],
          '2026-01-01T12:00:00.000Z',
        );
      },
    );

    // Altdokument ohne Revision und Zeitstempel: Lesen und Schreibvorbedingung
    // müssen dieselbe Rückfall-Revision bilden (REV-19).
    test('accepts the decoded legacy revision of an old document', () async {
      final requests = <http.Request>[];
      final remoteHero = hero('h-1', 'Alrik');
      final legacyDocument = {
        'name':
            'projects/test-project/databases/(default)/documents/'
            'users/user-1/heroes/h-1',
        'updateTime': '2026-01-01T12:00:00Z',
        'fields': {
          'deleted': {'booleanValue': false},
          'payload': _firestoreValue(remoteHero.toJson()),
        },
      };
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(jsonEncode(legacyDocument), 200);
        }
        return http.Response(request.body, 200);
      });
      final remote = await gateway(client: client).loadHero('h-1');
      requests.clear();

      await gateway(client: client)
          .saveHero(hero('h-1', 'Alrik 2'), previousRevision: remote!.revision);

      expect(remote.revision, 'legacy-${heroContentHash(remoteHero)}');
      expect(requests.map((r) => r.method), ['GET', 'PATCH']);
    });

    test('aborts the save without PATCH when the revision moved', () async {
      final requests = <http.Request>[];
      final remoteHero = hero('h-1', 'Alrik');
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'name':
                'projects/test-project/databases/(default)/documents/'
                'users/user-1/heroes/h-1',
            'updateTime': '2026-01-01T12:00:00Z',
            'fields': _heroFields(
              payload: remoteHero.toJson(),
              revision: 'r-2',
              contentHash: stableContentHash(remoteHero.toJson()),
            ),
          }),
          200,
        );
      });

      await expectLater(
        gateway(client: client)
            .saveHero(hero('h-1', 'Alrik 2'), previousRevision: 'r-1'),
        throwsA(
          isA<SyncPreconditionException>()
              .having((e) => e.expectedRevision, 'expectedRevision', 'r-1')
              .having((e) => e.actualRevision, 'actualRevision', 'r-2'),
        ),
      );

      expect(requests.where((r) => r.method == 'PATCH'), isEmpty);
    });

    test('writes blindly when no previousRevision is given', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(request.body, 200);
      });

      await gateway(client: client)
          .saveHero(hero('h-1', 'Alrik'), previousRevision: null);

      expect(requests.single.method, 'PATCH');
      expect(
        requests.single.url.queryParameters.containsKey(
          'currentDocument.updateTime',
        ),
        isFalse,
      );
    });

    test('maps connection errors to SyncNetworkException', () async {
      final client = MockClient((request) async {
        throw http.ClientException('Verbindung abgelehnt');
      });

      await expectLater(
        gateway(client: client).loadAllHeroes(),
        throwsA(isA<SyncNetworkException>()),
      );
    });
  });
}

Map<String, dynamic> _document(String path, Map<String, dynamic> fields) {
  return {
    'name': 'projects/test-project/databases/(default)/documents/$path',
    'fields': fields,
  };
}

Map<String, dynamic> _heroFields({
  required Map<String, dynamic> payload,
  required String revision,
  required String contentHash,
}) {
  return {
    'deleted': {'booleanValue': false},
    'payload': _firestoreValue(payload),
    'revision': {'stringValue': revision},
    'contentHash': {'stringValue': contentHash},
    'lastModified': {'timestampValue': '2026-01-01T12:00:00Z'},
  };
}

Map<String, dynamic> _deletedFields({required String revision}) {
  return {
    'deleted': {'booleanValue': true},
    'payload': {'nullValue': null},
    'revision': {'stringValue': revision},
    'contentHash': {'stringValue': ''},
    'lastModified': {'timestampValue': '2026-01-01T12:00:00Z'},
  };
}

Map<String, dynamic> _firestoreValue(Object? value) {
  if (value == null) {
    return {'nullValue': null};
  }
  if (value is bool) {
    return {'booleanValue': value};
  }
  if (value is int) {
    return {'integerValue': value.toString()};
  }
  if (value is double) {
    return {'doubleValue': value};
  }
  if (value is String) {
    return {'stringValue': value};
  }
  if (value is Iterable) {
    return {
      'arrayValue': {
        'values': value.map(_firestoreValue).toList(growable: false),
      },
    };
  }
  if (value is Map) {
    return {
      'mapValue': {
        'fields': value.map(
          (key, entry) => MapEntry(key.toString(), _firestoreValue(entry)),
        ),
      },
    };
  }
  throw UnsupportedError('Unsupported Firestore test value: $value');
}

String? _payloadName(Map<String, dynamic> fields) {
  final payload = fields['payload'] as Map<String, dynamic>;
  final mapValue = payload['mapValue'] as Map<String, dynamic>;
  final payloadFields = mapValue['fields'] as Map<String, dynamic>;
  final name = payloadFields['name'] as Map<String, dynamic>;
  return name['stringValue'] as String?;
}
