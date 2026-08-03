import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_remote_client.dart';

void main() {
  RulesIndexRemoteClient client(http.Client httpClient) {
    return RulesIndexRemoteClient(httpClient: httpClient);
  }

  test('returns response bytes on 200', () async {
    final bytes = utf8.encode('fake-sqlite-bytes');
    final httpClient = MockClient((request) async {
      return http.Response.bytes(bytes, 200);
    });

    final result = await client(httpClient).download(
      serverUrl: 'https://example.myfritz.net/nas/index.sqlite',
      username: 'reader',
      password: 'secret',
    );

    expect(result, bytes);
  });

  test('sends Basic-Auth header derived from username/password', () async {
    String? capturedHeader;
    final httpClient = MockClient((request) async {
      capturedHeader = request.headers['Authorization'];
      return http.Response.bytes(const [], 200);
    });

    await client(httpClient).download(
      serverUrl: 'https://example.myfritz.net/nas/index.sqlite',
      username: 'reader',
      password: 'secret',
    );

    final expected =
        'Basic ${base64Encode(utf8.encode('reader:secret'))}';
    expect(capturedHeader, expected);
  });

  test('omits Authorization header without credentials', () async {
    String? capturedHeader;
    final httpClient = MockClient((request) async {
      capturedHeader = request.headers['Authorization'];
      return http.Response.bytes(const [], 200);
    });

    await client(httpClient).download(
      serverUrl: 'https://example.myfritz.net/nas/index.sqlite',
      username: '',
      password: '',
    );

    expect(capturedHeader, isNull);
  });

  test('maps 401 to unauthorized', () async {
    final httpClient = MockClient((request) async {
      return http.Response('nope', 401);
    });

    await expectLater(
      client(httpClient).download(
        serverUrl: 'https://example.myfritz.net/nas/index.sqlite',
        username: 'reader',
        password: 'wrong',
      ),
      throwsA(
        isA<RulesIndexDownloadException>().having(
          (e) => e.kind,
          'kind',
          RulesIndexDownloadErrorKind.unauthorized,
        ),
      ),
    );
  });

  test('maps 404 to notFound', () async {
    final httpClient = MockClient((request) async {
      return http.Response('missing', 404);
    });

    await expectLater(
      client(httpClient).download(
        serverUrl: 'https://example.myfritz.net/nas/index.sqlite',
        username: 'reader',
        password: 'secret',
      ),
      throwsA(
        isA<RulesIndexDownloadException>().having(
          (e) => e.kind,
          'kind',
          RulesIndexDownloadErrorKind.notFound,
        ),
      ),
    );
  });

  test('maps unexpected status codes to other', () async {
    final httpClient = MockClient((request) async {
      return http.Response('server error', 500);
    });

    await expectLater(
      client(httpClient).download(
        serverUrl: 'https://example.myfritz.net/nas/index.sqlite',
        username: 'reader',
        password: 'secret',
      ),
      throwsA(
        isA<RulesIndexDownloadException>().having(
          (e) => e.kind,
          'kind',
          RulesIndexDownloadErrorKind.other,
        ),
      ),
    );
  });

  test('maps transport failures to network', () async {
    final httpClient = MockClient((request) async {
      throw http.ClientException('connection refused');
    });

    await expectLater(
      client(httpClient).download(
        serverUrl: 'https://example.myfritz.net/nas/index.sqlite',
        username: 'reader',
        password: 'secret',
      ),
      throwsA(
        isA<RulesIndexDownloadException>().having(
          (e) => e.kind,
          'kind',
          RulesIndexDownloadErrorKind.network,
        ),
      ),
    );
  });
}
