import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/excel_rounding.dart';

// REV-09: die Rundungsregel (Wege der Helden S. 6) an einer Stelle.
void main() {
  group('halbiertAufgerundet', () {
    test('halbiert und rundet auf, Werte bis 0 ergeben 0', () {
      expect(halbiertAufgerundet(7), 4);
      expect(halbiertAufgerundet(8), 4);
      expect(halbiertAufgerundet(1), 1);
      expect(halbiertAufgerundet(0), 0);
      expect(halbiertAufgerundet(-3), 0);
    });
  });

  group('echtGerundet', () {
    test('rundet ab ,5 auf', () {
      expect(echtGerundet(21, 2), 11);
      expect(echtGerundet(6, 4), 2);
      expect(echtGerundet(5, 4), 1);
      expect(echtGerundet(7, 4), 2);
      expect(echtGerundet(7, 3), 2);
      expect(echtGerundet(8, 3), 3);
      expect(echtGerundet(1, 3), 0);
      expect(echtGerundet(0, 4), 0);
    });

    test('rundet negative Werte symmetrisch weg von 0', () {
      expect(echtGerundet(-21, 2), -11);
      expect(echtGerundet(-5, 4), -1);
    });
  });
}
