import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/string_normalize.dart';

void main() {
  group('suchFaltung (REV-08)', () {
    test('Umlaut, Umschreibung und Grundbuchstabe fallen zusammen', () {
      expect(suchFaltung('Betäubung'), 'betaubung');
      expect(suchFaltung('Betaeubung'), 'betaubung');
      expect(suchFaltung('Betaubung'), 'betaubung');
      expect(suchFaltung('Größe'), suchFaltung('groesse'));
      expect(suchFaltung('Übung'), suchFaltung('uebung'));
    });

    test('schneidet Randleerzeichen ab und lässt innere stehen', () {
      expect(suchFaltung('  Alte Brücke '), 'alte brucke');
    });
  });
}
