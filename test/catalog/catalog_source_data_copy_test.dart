import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';

void main() {
  test(
    'CatalogSourceData.copyWith behält den v3-Salt und alle übrigen Felder',
    () {
      final salt = Uint8List.fromList(<int>[1, 2, 3]);
      final daten = CatalogSourceData(
        version: '1',
        source: 'test',
        metadata: const <String, dynamic>{'k': 1},
        sections: const <CatalogSectionId, List<Map<String, dynamic>>>{},
        reisebericht: const <Map<String, dynamic>>[],
        spellEffects: const <Map<String, dynamic>>[
          <String, dynamic>{'id': 'a'},
        ],
        catalogSaltV3: salt,
      );

      final kopie = daten.copyWith(
        sections: <CatalogSectionId, List<Map<String, dynamic>>>{
          CatalogSectionId.values.first: const <Map<String, dynamic>>[
            <String, dynamic>{'id': 'x'},
          ],
        },
      );

      expect(kopie.catalogSaltV3, same(salt));
      expect(kopie.version, '1');
      expect(kopie.source, 'test');
      expect(kopie.metadata, {'k': 1});
      expect(kopie.spellEffects, daten.spellEffects);
      expect(kopie.entriesFor(CatalogSectionId.values.first), hasLength(1));
    },
  );
}
