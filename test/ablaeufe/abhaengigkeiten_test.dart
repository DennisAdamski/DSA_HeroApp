import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Importe, die Anwendungsabläufe nie ziehen dürfen: Sie sollen ohne
/// Oberfläche und ohne Riverpod prüfbar bleiben und ihre Abhängigkeiten
/// ausschließlich per Konstruktor bzw. Parameter bekommen.
const List<String> _verboteneBestandteile = <String>[
  'package:flutter/',
  'package:flutter_riverpod/',
  'package:riverpod/',
  'package:dsa_heldenverwaltung/state/',
  'package:dsa_heldenverwaltung/ui/',
  'package:dsa_heldenverwaltung/ui2/',
];

/// Aus der Datenschicht ist nur die Repository-Schnittstelle erlaubt.
const Set<String> _erlaubteDatenImporte = <String>{
  'package:dsa_heldenverwaltung/data/hero_repository.dart',
};

final RegExp _importMuster = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
);

void main() {
  test('lib/ablaeufe hängt nur von Domain, Regeln, Katalog und '
      'HeroRepository ab', () {
    final dateien = Directory('lib/ablaeufe')
        .listSync(recursive: true)
        .whereType<File>()
        .where((datei) => datei.path.endsWith('.dart'))
        .toList(growable: false);
    expect(dateien, isNotEmpty);

    final verstoesse = <String>[];
    for (final datei in dateien) {
      for (final zeile in datei.readAsLinesSync()) {
        final treffer = _importMuster.firstMatch(zeile);
        if (treffer == null) {
          continue;
        }
        final ziel = treffer.group(1)!;
        final verboten = _verboteneBestandteile.any(ziel.startsWith);
        final datenImport =
            ziel.startsWith('package:dsa_heldenverwaltung/data/') &&
            !_erlaubteDatenImporte.contains(ziel);
        if (verboten || datenImport) {
          verstoesse.add('${datei.path}: $ziel');
        }
      }
    }
    expect(verstoesse, isEmpty);
  });
}
