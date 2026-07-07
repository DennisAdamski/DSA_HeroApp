import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dsa_heldenverwaltung/data/firestore_rest_client.dart';
import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';

void main() {
  FirestoreRestClient client(http.Client httpClient) {
    return FirestoreRestClient(
      projectId: 'test-project',
      idTokenProvider: () async => 'token-1',
      httpClient: httpClient,
    );
  }

  group('FirestoreRestClient', () {
    test('getDocument parses fields and updateTime', () async {
      final httpClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'name':
                'projects/test-project/databases/(default)/documents/'
                'users/user-1/heroes/h-1',
            'updateTime': '2026-01-02T08:30:00Z',
            'fields': {
              'revision': {'stringValue': 'r-1'},
              'deleted': {'booleanValue': false},
            },
          }),
          200,
        );
      });

      final document = await client(
        httpClient,
      ).getDocument('users/user-1/heroes/h-1');

      expect(document, isNotNull);
      expect(document!.id, 'h-1');
      expect(document.updateTime, DateTime.utc(2026, 1, 2, 8, 30));
      expect(document.fields['revision'], 'r-1');
      expect(document.fields['deleted'], isFalse);
    });

    test('getDocument returns null for 404', () async {
      final httpClient = MockClient((request) async {
        return http.Response('not found', 404);
      });

      final document = await client(
        httpClient,
      ).getDocument('users/user-1/heroes/missing');

      expect(document, isNull);
    });

    test('patchDocumentFields encodes preconditions as query params', () async {
      late http.Request captured;
      final httpClient = MockClient((request) async {
        captured = request;
        return http.Response(request.body, 200);
      });

      await client(httpClient).patchDocumentFields(
        'users/user-1/heroes/h-1',
        <String, dynamic>{'deleted': false},
        updateTimePrecondition: DateTime.utc(2026, 1, 2, 8, 30),
        existsPrecondition: true,
      );

      expect(
        captured.url.queryParameters['currentDocument.updateTime'],
        '2026-01-02T08:30:00.000Z',
      );
      expect(captured.url.queryParameters['currentDocument.exists'], 'true');
    });

    test('patchDocumentFields omits query params without preconditions',
        () async {
      late http.Request captured;
      final httpClient = MockClient((request) async {
        captured = request;
        return http.Response(request.body, 200);
      });

      await client(httpClient).patchDocumentFields(
        'users/user-1/heroes/h-1',
        <String, dynamic>{'deleted': false},
      );

      expect(captured.url.queryParameters, isEmpty);
    });

    test('maps failed preconditions in the body to a typed error', () async {
      final httpClient = MockClient((request) async {
        return http.Response(
          '{"error": {"status": "FAILED_PRECONDITION"}}',
          400,
        );
      });

      await expectLater(
        client(httpClient).patchDocumentFields(
          'users/user-1/heroes/h-1',
          <String, dynamic>{'deleted': false},
        ),
        throwsA(isA<SyncPreconditionException>()),
      );
    });

    test('keeps a generic error for unclassified 4xx responses', () async {
      final httpClient = MockClient((request) async {
        return http.Response('{"error": {"status": "INVALID_ARGUMENT"}}', 400);
      });

      await expectLater(
        client(httpClient).getDocument('users/user-1/heroes/h-1'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
