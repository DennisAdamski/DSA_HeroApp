import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_search_io.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_types.dart';

import 'rules_search/rules_index_test_fixture.dart';

void main() {
  test(
    'explizites Datenverzeichnis lässt benachbarte Benutzerdateien unberührt',
    () async {
      final basis = Directory.systemTemp.createTempSync(
        'rules-index-isolation-',
      );
      addTearDown(() => basis.deleteSync(recursive: true));
      final testDaten = Directory(p.join(basis.path, 'test-daten'));
      final benutzerDaten = Directory(p.join(basis.path, 'benutzer-daten'))
        ..createSync();
      final sentinel = File(p.join(benutzerDaten.path, 'index_remote.sqlite'))
        ..writeAsStringSync('nicht verändern');

      final search = await importRulesIndexDatabase(
        buildMinimalRulesIndexBytes(),
        dataDirectory: testDaten.path,
      );
      search.dispose();
      final reopened = await openRulesIndexSearch(
        dataDirectory: testDaten.path,
      );
      reopened?.dispose();

      expect(sentinel.readAsStringSync(), 'nicht verändern');
      expect(
        File(p.join(testDaten.path, 'index_remote.sqlite')).existsSync(),
        isTrue,
      );
    },
  );

  test('rulesIndexSearchSupported liefert auf dem Testrechner true', () {
    // flutter test laeuft auf der Dart-VM eines Desktop-Betriebssystems
    // (Windows/Linux/macOS), nie auf Mobile/Web.
    expect(rulesIndexSearchSupported(), isTrue);
  });

  test('openRulesIndexSearch loest asynchron auf und gibt frei', () async {
    final dataDirectory = Directory.systemTemp.createTempSync(
      'rules-index-open-',
    );
    addTearDown(() => dataDirectory.deleteSync(recursive: true));
    final future = openRulesIndexSearch(dataDirectory: dataDirectory.path);
    expect(future, isA<Future<RulesIndexSearch?>>());

    final search = await future;
    // Ob eine echte Index-Datenbank auf dem Testrechner vorhanden ist,
    // haengt vom lokalen dsa-rules-mcp-Setup ab; der Test prueft nur den
    // asynchronen Vertrag, nicht das Vorhandensein der Datei.
    search?.dispose();
  });

  group('importRulesIndexDatabase (Remote-Cache-Pfad)', () {
    late Directory dataDirectory;
    late String remoteCachePath;

    setUp(() {
      dataDirectory = Directory.systemTemp.createTempSync(
        'rules-index-import-',
      );
      remoteCachePath = p.join(dataDirectory.path, 'index_remote.sqlite');
    });

    tearDown(() => dataDirectory.deleteSync(recursive: true));

    test(
      'importiert eine gueltige Datenbank und macht sie durchsuchbar',
      () async {
        final bytes = buildMinimalRulesIndexBytes();

        final search = await importRulesIndexDatabase(
          bytes,
          dataDirectory: dataDirectory.path,
        );
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
      },
    );

    test(
      'oeffnet importierte Datenbank anschliessend ueber openRulesIndexSearch '
      'als Fallback, wenn keine lokale index.sqlite existiert',
      () async {
        final bytes = buildMinimalRulesIndexBytes();
        final imported = await importRulesIndexDatabase(
          bytes,
          dataDirectory: dataDirectory.path,
        );
        imported.dispose();

        final search = await openRulesIndexSearch(
          dataDirectory: dataDirectory.path,
        );
        expect(search, isNotNull);
        search?.dispose();
      },
    );

    test(
      'lehnt eine Datei ohne SQLite-Header ab und raeumt tmp-Datei auf',
      () async {
        final bytes = Uint8List.fromList('not a database'.codeUnits);

        await expectLater(
          importRulesIndexDatabase(bytes, dataDirectory: dataDirectory.path),
          throwsA(isA<FormatException>()),
        );
        expect(File('$remoteCachePath.tmp').existsSync(), isFalse);
        expect(File(remoteCachePath).existsSync(), isFalse);
      },
    );

    test('ein fehlgeschlagener Import laesst einen zuvor funktionierenden '
        'Cache unangetastet', () async {
      final validBytes = buildMinimalRulesIndexBytes();
      final firstImport = await importRulesIndexDatabase(
        validBytes,
        dataDirectory: dataDirectory.path,
      );
      firstImport.dispose();
      final workingBytesOnDisk = File(remoteCachePath).readAsBytesSync();

      final corruptBytes = Uint8List.fromList('not a database'.codeUnits);
      await expectLater(
        importRulesIndexDatabase(
          corruptBytes,
          dataDirectory: dataDirectory.path,
        ),
        throwsA(isA<FormatException>()),
      );

      expect(
        File(remoteCachePath).readAsBytesSync(),
        equals(workingBytesOnDisk),
      );
    });
  });
}
