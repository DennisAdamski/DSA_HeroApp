import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_decrypt_runner.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';

Uint8List _randomSalt([int length = 32]) {
  final rng = Random.secure();
  return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
}

CatalogSourceData _sourceFrom({
  Map<CatalogSectionId, List<Map<String, dynamic>>> sections =
      const <CatalogSectionId, List<Map<String, dynamic>>>{},
  List<Map<String, dynamic>> reisebericht =
      const <Map<String, dynamic>>[],
}) {
  return CatalogSourceData(
    version: 'test',
    source: 'test',
    metadata: const <String, dynamic>{},
    sections: sections,
    reisebericht: reisebericht,
  );
}

void main() {
  const password = 'geheim123';

  group('decryptAllCatalogValues', () {
    test('v3-Werte werden mit globalem Salt entschluesselt', () async {
      final salt = _randomSalt();
      final key = deriveCatalogKey(password: password, salt: salt);
      final encrypted = encryptCatalogValueV3(
        plaintext: 'Geheime Wirkung',
        derivedKey: key,
      );

      final source = _sourceFrom(
        sections: <CatalogSectionId, List<Map<String, dynamic>>>{
          CatalogSectionId.spells: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'spell.foo',
              'name': 'Foo',
              'wirkung': encrypted,
            },
          ],
        },
      );

      final result = await decryptAllCatalogValues(
        encrypted: source,
        password: password,
        globalSaltV3: salt,
      );

      expect(
        result.entriesFor(CatalogSectionId.spells).single['wirkung'],
        'Geheime Wirkung',
      );
    });

    test('v2-Werte werden auch ohne globalSaltV3 entschluesselt', () async {
      final encrypted = encryptCatalogValue('Alter Inhalt', password);
      final source = _sourceFrom(
        sections: <CatalogSectionId, List<Map<String, dynamic>>>{
          CatalogSectionId.spells: <Map<String, dynamic>>[
            <String, dynamic>{'id': 'a', 'wirkung': encrypted},
          ],
        },
      );

      final result = await decryptAllCatalogValues(
        encrypted: source,
        password: password,
        globalSaltV3: null,
      );

      expect(
        result.entriesFor(CatalogSectionId.spells).single['wirkung'],
        'Alter Inhalt',
      );
    });

    test('Mischung aus v2 und v3 in derselben Sektion', () async {
      final salt = _randomSalt();
      final key = deriveCatalogKey(password: password, salt: salt);
      final v2 = encryptCatalogValue('v2-Inhalt', password);
      final v3 = encryptCatalogValueV3(plaintext: 'v3-Inhalt', derivedKey: key);

      final source = _sourceFrom(
        sections: <CatalogSectionId, List<Map<String, dynamic>>>{
          CatalogSectionId.spells: <Map<String, dynamic>>[
            <String, dynamic>{'id': 'a', 'wirkung': v2, 'modifications': v3},
          ],
        },
      );

      final result = await decryptAllCatalogValues(
        encrypted: source,
        password: password,
        globalSaltV3: salt,
      );

      final entry = result.entriesFor(CatalogSectionId.spells).single;
      expect(entry['wirkung'], 'v2-Inhalt');
      expect(entry['modifications'], 'v3-Inhalt');
    });

    test('Klartext-Werte bleiben unveraendert', () async {
      final source = _sourceFrom(
        sections: <CatalogSectionId, List<Map<String, dynamic>>>{
          CatalogSectionId.spells: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'a',
              'name': 'Klartextname',
              'count': 3,
              'enabled': true,
            },
          ],
        },
      );

      final result = await decryptAllCatalogValues(
        encrypted: source,
        password: password,
        globalSaltV3: null,
      );

      final entry = result.entriesFor(CatalogSectionId.spells).single;
      expect(entry['name'], 'Klartextname');
      expect(entry['count'], 3);
      expect(entry['enabled'], true);
    });

    test('Verschachtelte Listen werden rekursiv durchwandert', () async {
      final salt = _randomSalt();
      final key = deriveCatalogKey(password: password, salt: salt);
      final encA = encryptCatalogValueV3(plaintext: 'A', derivedKey: key);
      final encB = encryptCatalogValueV3(plaintext: 'B', derivedKey: key);

      final source = _sourceFrom(
        sections: <CatalogSectionId, List<Map<String, dynamic>>>{
          CatalogSectionId.spells: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'a',
              'variants': <dynamic>[encA, encB, 'klartext'],
            },
          ],
        },
      );

      final result = await decryptAllCatalogValues(
        encrypted: source,
        password: password,
        globalSaltV3: salt,
      );

      expect(
        result.entriesFor(CatalogSectionId.spells).single['variants'],
        <dynamic>['A', 'B', 'klartext'],
      );
    });

    test('Werte die nicht entschluesselt werden koennen bleiben unveraendert',
        () async {
      // v3-Wert mit falschem Salt -> Decrypt schlaegt fehl
      final saltA = _randomSalt();
      final saltB = _randomSalt();
      final keyA = deriveCatalogKey(password: password, salt: saltA);
      final encrypted = encryptCatalogValueV3(plaintext: 'X', derivedKey: keyA);

      final source = _sourceFrom(
        sections: <CatalogSectionId, List<Map<String, dynamic>>>{
          CatalogSectionId.spells: <Map<String, dynamic>>[
            <String, dynamic>{'id': 'a', 'wirkung': encrypted},
          ],
        },
      );

      final result = await decryptAllCatalogValues(
        encrypted: source,
        password: password,
        globalSaltV3: saltB,
      );

      // Bei Decrypt-Fehler bleibt der Originalwert erhalten.
      expect(
        result.entriesFor(CatalogSectionId.spells).single['wirkung'],
        encrypted,
      );
    });

    test('Listen-Felder werden nach Decrypt als List zurueckgeliefert', () async {
      // Schema wie magie.json `variants`: das ganze Feld ist ein einziger
      // enc:-String der eine JSON-Liste enthaelt.
      final salt = _randomSalt();
      final key = deriveCatalogKey(password: password, salt: salt);
      final encryptedListField = encryptCatalogListV3(
        values: const ['Variante A', 'Variante B', 'Variante C'],
        derivedKey: key,
      );

      final source = _sourceFrom(
        sections: <CatalogSectionId, List<Map<String, dynamic>>>{
          CatalogSectionId.spells: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'spell.x',
              'variants': encryptedListField,
            },
          ],
        },
      );

      final result = await decryptAllCatalogValues(
        encrypted: source,
        password: password,
        globalSaltV3: salt,
      );

      expect(
        result.entriesFor(CatalogSectionId.spells).single['variants'],
        <dynamic>['Variante A', 'Variante B', 'Variante C'],
      );
    });

    test('Reisebericht-Daten werden ebenfalls entschluesselt', () async {
      final salt = _randomSalt();
      final key = deriveCatalogKey(password: password, salt: salt);
      final encrypted = encryptCatalogValueV3(
        plaintext: 'Reise-Geheimnis',
        derivedKey: key,
      );

      final source = _sourceFrom(
        reisebericht: <Map<String, dynamic>>[
          <String, dynamic>{'id': 'r', 'beschreibung': encrypted},
        ],
      );

      final result = await decryptAllCatalogValues(
        encrypted: source,
        password: password,
        globalSaltV3: salt,
      );

      expect(
        result.reisebericht.single['beschreibung'],
        'Reise-Geheimnis',
      );
    });

    test('Metadaten und Version werden uebernommen', () async {
      final source = CatalogSourceData(
        version: 'v42',
        source: 'unit-test',
        metadata: const <String, dynamic>{'note': 'hello'},
        sections: const <CatalogSectionId, List<Map<String, dynamic>>>{},
        reisebericht: const <Map<String, dynamic>>[],
      );

      final result = await decryptAllCatalogValues(
        encrypted: source,
        password: password,
        globalSaltV3: null,
      );

      expect(result.version, 'v42');
      expect(result.source, 'unit-test');
      expect(result.metadata, const <String, dynamic>{'note': 'hello'});
    });
  });
}
