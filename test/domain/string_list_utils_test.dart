import 'package:dsa_heldenverwaltung/domain/string_list_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeStringList', () {
    test('trimmt Werte und entfernt Leerstrings', () {
      expect(normalizeStringList(<String>[' a ', '', '  ', 'b']), <String>[
        'a',
        'b',
      ]);
    });

    test('entfernt Duplikate bei stabiler Reihenfolge', () {
      expect(normalizeStringList(<String>['b', 'a', 'b ', ' a']), <String>[
        'b',
        'a',
      ]);
    });

    test('verarbeitet dynamische Werte ueber toString', () {
      expect(normalizeStringList(<Object?>[1, ' zwei ', 1]), <String>[
        '1',
        'zwei',
      ]);
    });

    test('gibt eine unveraenderliche Liste zurueck', () {
      final result = normalizeStringList(<String>['a']);
      expect(() => result.add('b'), throwsUnsupportedError);
    });
  });
}
