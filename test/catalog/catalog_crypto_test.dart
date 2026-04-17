import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';

void main() {
  const password = 'geheim123';
  const plaintext = 'Das Schwert des Dämons';

  group('encryptCatalogValue / decryptCatalogValue', () {
    test('Roundtrip liefert Originaltext zurück', () {
      final encrypted = encryptCatalogValue(plaintext, password);
      final decrypted = decryptCatalogValue(encrypted, password);
      expect(decrypted, plaintext);
    });

    test('Verschlüsselter Wert beginnt mit enc:2:', () {
      final encrypted = encryptCatalogValue(plaintext, password);
      expect(encrypted, startsWith('enc:2:'));
    });

    test('Zwei Verschlüsselungen desselben Texts sind unterschiedlich (zufälliges Salt)', () {
      final a = encryptCatalogValue(plaintext, password);
      final b = encryptCatalogValue(plaintext, password);
      expect(a, isNot(equals(b)));
    });
  });
}
