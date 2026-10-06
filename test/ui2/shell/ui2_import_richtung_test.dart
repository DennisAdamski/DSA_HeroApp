import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Der Neubau importiert aus dem Bestand ausschließlich an seinem einzigen
// Verdrahtungspunkt; alles Weitere läuft über die Adapterschnittstellen.
// Richtung: lib/ui → lib/ui2, nie umgekehrt.
const _erlaubt = {'lib/ui2/shell/karto_app_root.dart'};

void main() {
  test('lib/ui2 importiert lib/ui nur in karto_app_root.dart', () {
    final verstoesse = <String>[];
    final dateien = Directory('lib/ui2')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final datei in dateien) {
      final pfad = datei.path.replaceAll(r'\', '/');
      if (_erlaubt.contains(pfad)) continue;
      for (final zeile in datei.readAsLinesSync()) {
        final import = zeile.trimLeft();
        if ((import.startsWith('import ') || import.startsWith('export ')) &&
            import.contains('package:dsa_heldenverwaltung/ui/')) {
          verstoesse.add('$pfad: $import');
        }
      }
    }
    expect(verstoesse, isEmpty);
  });
}
