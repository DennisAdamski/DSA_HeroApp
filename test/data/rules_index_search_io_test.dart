import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_search_io.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_types.dart';

import 'rules_search/rules_index_test_fixture.dart';

/// Löst denselben Remote-Cache-Pfad wie `rules_index_search_io.dart` auf
/// (Pfad-Auflösungsfunktion dort ist privat, daher hier dupliziert), damit
/// Tests die Datei nach dem Lauf wieder entfernen können.
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
  test('rulesIndexSearchSupported liefert auf dem Testrechner true', () {
    // flutter test laeuft auf der Dart-VM eines Desktop-Betriebssystems
    // (Windows/Linux/macOS), nie auf Mobile/Web.
    expect(rulesIndexSearchSupported(), isTrue);
  });

  test('openRulesIndexSearch loest asynchron auf und gibt frei', () async {
    final future = openRulesIndexSearch();
    expect(future, isA<Future<RulesIndexSearch?>>());

    final search = await future;
    // Ob eine echte Index-Datenbank auf dem Testrechner vorhanden ist,
    // haengt vom lokalen dsa-rules-mcp-Setup ab; der Test prueft nur den
    // asynchronen Vertrag, nicht das Vorhandensein der Datei.
    search?.dispose();
  });

  group('importRulesIndexDatabase (Remote-Cache-Pfad)', () {
    final remoteCachePath = _resolveRemoteCacheDbPathForCleanup();

    tearDown(() {
      for (final suffix in const ['', '.tmp']) {
        final file = File('$remoteCachePath$suffix');
        if (file.existsSync()) {
          file.deleteSync();
        }
      }
    });

    test('importiert eine gueltige Datenbank und macht sie durchsuchbar', () async {
      final bytes = buildMinimalRulesIndexBytes();

      final search = await importRulesIndexDatabase(bytes);
      try {
        expect(File(remoteCachePath).existsSync(), isTrue);
        final hits = search.search(
          'Behinderung',
          categories: RulesSourceCategory.values.toSet(),
        );
        expect(hits, isNotEmpty);
      } finally {
        search.dispose();
      }
    });

    test('oeffnet importierte Datenbank anschliessend ueber openRulesIndexSearch '
        'als Fallback, wenn keine lokale index.sqlite existiert', () async {
      final bytes = buildMinimalRulesIndexBytes();
      final imported = await importRulesIndexDatabase(bytes);
      imported.dispose();

      final search = await openRulesIndexSearch();
      expect(search, isNotNull);
      search?.dispose();
    });

    test('lehnt eine Datei ohne SQLite-Header ab und raeumt tmp-Datei auf', () async {
      final bytes = Uint8List.fromList('not a database'.codeUnits);

      await expectLater(
        importRulesIndexDatabase(bytes),
        throwsA(isA<FormatException>()),
      );
      expect(File('$remoteCachePath.tmp').existsSync(), isFalse);
      expect(File(remoteCachePath).existsSync(), isFalse);
    });

    test('ein fehlgeschlagener Import laesst einen zuvor funktionierenden '
        'Cache unangetastet', () async {
      final validBytes = buildMinimalRulesIndexBytes();
      final firstImport = await importRulesIndexDatabase(validBytes);
      firstImport.dispose();
      final workingBytesOnDisk = File(remoteCachePath).readAsBytesSync();

      final corruptBytes = Uint8List.fromList('not a database'.codeUnits);
      await expectLater(
        importRulesIndexDatabase(corruptBytes),
        throwsA(isA<FormatException>()),
      );

      expect(
        File(remoteCachePath).readAsBytesSync(),
        equals(workingBytesOnDisk),
      );
    });
  });
}
