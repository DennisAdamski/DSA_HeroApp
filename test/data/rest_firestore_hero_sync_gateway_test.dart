import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dsa_heldenverwaltung/data/rest_firestore_hero_sync_gateway.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
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

  group('RestFirestoreHeroSyncGateway', () {
    test(
      'writes heroes to the authenticated Firestore REST document',
      () async {
        final requests = <http.Request>[];
        final remoteHero = hero('h-1', 'Alrik');
        final client = MockClient((request) async {
          requests.add(request);
          return http.Response(request.body, 200);
        });

        final record = await gateway(
          client: client,
        ).saveHero(remoteHero, previousRevision: null);

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

      final record = await gateway(
        client: client,
      ).saveHeroState('h-1', state, previousRevision: null);

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
        throwsA(isA<StateError>()),
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
