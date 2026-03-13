import 'dart:convert';
import 'dart:io';

import 'package:dsa_heldenverwaltung/catalog/vertrautenmagie_preset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kVertrautenmagiePresetCategory', () {
    test('enthaelt alle 12 Vertrautenrituale mit Zusatzfeldern', () {
      final category = kVertrautenmagiePresetCategory;

      expect(category.id, 'vertrautenmagie');
      expect(category.additionalFieldDefs.length, 3);
      expect(category.rituals.length, 12);
      expect(
        category.rituals.map((entry) => entry.name),
        containsAll(<String>[
          'Dinge aufspüren',
          'Erster unter Gleichen',
          'Hexe finden',
          'Krötengift',
          'Krötenschlag',
          'Schlaf rauben',
          'Stimmungssinn',
          'Tarnung',
          'Tiersinne',
          'Ungesehener Beobachter',
          'Wachsame Augen',
          'Zwiegespräch',
        ]),
      );
    });

    test('spiegelt das JSON-Snippet unter assets/catalogs', () {
      final jsonFile = File(
        'assets/catalogs/house_rules_v1/vertrautenmagie_rituale.json',
      );
      final decoded =
          jsonDecode(jsonFile.readAsStringSync(encoding: utf8))
              as Map<String, dynamic>;

      expect(kVertrautenmagiePresetCategory.toJson(), decoded);
    });
  });
}
