import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_remote_client.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_sync_service.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_types.dart';
import 'package:dsa_heldenverwaltung/domain/rules_index_remote_config.dart';

import 'rules_index_test_fixture.dart';

/// Löst denselben Remote-Cache-Pfad wie `rules_index_search_io.dart` auf,
/// damit der Test die dort erzeugte Datei nach dem Lauf wieder entfernen
/// kann. Der Pfad ist bewusst dupliziert statt importiert, da die
/// Auflösungsfunktion in der Produktionsdatei privat ist.
String _resolveRemoteCacheDbPathForCleanup() {
  final override = Platform.environment['DSA_MCP_DATA_DIR'];
  final String dataDir;
  if (override != null && override.isNotEmpty) {
    dataDir = override;
  } else {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      dataDir = p.join(localAppData, 'dsa-rules-mcp');
    } else {
      final home = Platform.environment['HOME'] ?? '';
      dataDir = p.join(home, '.local', 'share', 'dsa-rules-mcp');
    }
  }
  return p.join(dataDir, 'index_remote.sqlite');
}

void main() {
  final remoteCachePath = _resolveRemoteCacheDbPathForCleanup();

  tearDown(() {
    for (final suffix in const ['', '.tmp']) {
      final file = File('$remoteCachePath$suffix');
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  });

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
    );

    await expectLater(
      service.syncFromServer(config),
      throwsA(isA<RulesIndexDownloadException>()),
    );
  });
}
