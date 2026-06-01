import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dsa_heldenverwaltung/data/firestore_secrets_repository.dart';
import 'package:dsa_heldenverwaltung/data/rest_firestore_secrets_repository.dart';

void main() {
  RestFirestoreSecretsRepository repository({required http.Client client}) {
    return RestFirestoreSecretsRepository(
      userId: 'user-1',
      projectId: 'test-project',
      httpClient: client,
      idTokenProvider: () async => 'token-1',
    );
  }

  group('RestFirestoreSecretsRepository', () {
    test('writes encrypted secrets through Firestore REST', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(request.body, 200);
      });

      await repository(client: client).save(
        RemoteSecrets(
          catalogPasswordCipher: Uint8List.fromList([1, 2]),
          catalogPasswordIv: Uint8List.fromList([3, 4]),
          catalogPasswordSet: true,
          apiKeyCipher: Uint8List.fromList([5, 6]),
          apiKeyIv: Uint8List.fromList([7, 8]),
          apiProvider: 'openai',
          cipherVersion: 1,
          lastModified: DateTime.utc(2026),
        ),
      );

      final request = requests.single;
      expect(request.method, 'PATCH');
      expect(request.headers['authorization'], 'Bearer token-1');
      expect(
        request.url.toString(),
        'https://firestore.googleapis.com/v1/projects/test-project/'
        'databases/(default)/documents/users/user-1/private/secrets',
      );

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final fields = body['fields'] as Map<String, dynamic>;
      expect(fields['catalogPasswordSet'], {'booleanValue': true});
      expect(fields['apiProvider'], {'stringValue': 'openai'});
      expect(fields['apiKeyCipher'], {
        'bytesValue': base64Encode([5, 6]),
      });
    });

    test('loads encrypted secrets from Firestore REST', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        return http.Response(
          jsonEncode({
            'name':
                'projects/test-project/databases/(default)/documents/'
                'users/user-1/private/secrets',
            'fields': {
              'catalogPasswordCipher': {
                'bytesValue': base64Encode([1, 2]),
              },
              'catalogPasswordIv': {
                'bytesValue': base64Encode([3, 4]),
              },
              'catalogPasswordSet': {'booleanValue': true},
              'apiKeyCipher': {
                'bytesValue': base64Encode([5, 6]),
              },
              'apiKeyIv': {
                'bytesValue': base64Encode([7, 8]),
              },
              'apiProvider': {'stringValue': 'openai'},
              'cipherVersion': {'integerValue': '2'},
              'lastModified': {'timestampValue': '2026-01-01T00:00:00Z'},
            },
          }),
          200,
        );
      });

      final secrets = await repository(client: client).load();

      expect(secrets?.apiKeyCipher, [5, 6]);
      expect(secrets?.apiKeyIv, [7, 8]);
      expect(secrets?.catalogPasswordSet, isTrue);
      expect(secrets?.apiProvider, 'openai');
      expect(secrets?.cipherVersion, 2);
      expect(secrets?.lastModified, DateTime.utc(2026));
    });
  });
}
