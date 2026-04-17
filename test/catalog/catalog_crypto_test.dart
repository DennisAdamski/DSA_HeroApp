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
  });
}
