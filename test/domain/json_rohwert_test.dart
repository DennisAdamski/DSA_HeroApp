import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

void main() {
  group('jsonRohwertGleich', () {
    test('Map-Reihenfolge zählt nicht, Listen-Reihenfolge schon', () {
      expect(
        jsonRohwertGleich(
          {
            'a': 1,
            'b': [1, 2],
          },
          {
            'b': [1, 2],
            'a': 1,
          },
        ),
        isTrue,
      );
      expect(jsonRohwertGleich([1, 2], [2, 1]), isFalse);
    });

    test('verschachtelte Unterschiede und fehlende Schlüssel', () {
      expect(
        jsonRohwertGleich(
          {
            'a': {'b': 1},
          },
          {
            'a': {'b': 2},
          },
        ),
        isFalse,
      );
      expect(jsonRohwertGleich({'a': 1}, {'a': 1, 'b': null}), isFalse);
    });

    test('Zahlen vergleichen wie in Dart', () {
      expect(jsonRohwertGleich(1, 1.0), isTrue);
    });
  });

  group('kanonischeJsonForm', () {
    test('sortiert Schlüssel rekursiv, Listen behalten die Reihenfolge', () {
      final form = kanonischeJsonForm({
        'b': 1,
        'a': [
          {'y': 1, 'x': 2},
          3,
        ],
      });
      expect(jsonEncode(form), '{"a":[{"x":2,"y":1},3],"b":1}');
    });

    test('der stabile Hash hängt nicht von der Einfügereihenfolge ab', () {
      expect(
        stableContentHash({
          'a': 1,
          'b': {'c': 2, 'd': 3},
        }),
        stableContentHash({
          'b': {'d': 3, 'c': 2},
          'a': 1,
        }),
      );
    });
  });
}
