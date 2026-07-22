import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_search_io.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_types.dart';

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
}
