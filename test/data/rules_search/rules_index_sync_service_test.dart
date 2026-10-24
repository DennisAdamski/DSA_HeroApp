import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_remote_client.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_sync_service.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_types.dart';
import 'package:dsa_heldenverwaltung/domain/rules_index_remote_config.dart';

import 'rules_index_test_fixture.dart';

void main() {
  late Directory dataDirectory;

  setUp(() {
    dataDirectory = Directory.systemTemp.createTempSync('rules-index-sync-');
  });

  tearDown(() => dataDirectory.deleteSync(recursive: true));

  const config = RulesIndexRemoteConfig(
    serverUrl: 'https://example.myfritz.net/nas/index.sqlite',
    username: 'reader',
    password: 'secret',
  );

  test('downloads, validates and imports a valid index database', () async {
    final fixtureBytes = buildMinimalRulesIndexBytes();
    final httpClient = MockClient((request) async {
      return http.Response.bytes(fixtureBytes, 200);
    });
    final service = RulesIndexSyncService(
      remoteClient: RulesIndexRemoteClient(httpClient: httpClient),
      dataDirectory: dataDirectory.path,
    );

    final search = await service.syncFromServer(config);
    try {
      final hits = search.search(
        'Behinderung',
        categories: RulesSourceCategory.values.toSet(),
      );
      expect(hits, isNotEmpty);
    } finally {
      search.dispose();
    }
  });

  test('rejects a response that is not a SQLite file', () async {
    final httpClient = MockClient((request) async {
      return http.Response.bytes(utf8.encode('<html>not found</html>'), 200);
    });
    final service = RulesIndexSyncService(
      remoteClient: RulesIndexRemoteClient(httpClient: httpClient),
      dataDirectory: dataDirectory.path,
    );

    await expectLater(
      service.syncFromServer(config),
      throwsA(isA<FormatException>()),
    );
  });

  test('propagates download errors from the remote client', () async {
    final httpClient = MockClient((request) async {
      return http.Response('nope', 401);
    });
    final service = RulesIndexSyncService(
      remoteClient: RulesIndexRemoteClient(httpClient: httpClient),
      dataDirectory: dataDirectory.path,
    );

    await expectLater(
      service.syncFromServer(config),
      throwsA(isA<RulesIndexDownloadException>()),
    );
  });
}
