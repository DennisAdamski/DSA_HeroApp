// Golden-Fixtures fuer die Katalog-Krypto.
//
// ACHTUNG: Die Chiffrate unten sind mit der ausgelieferten Implementierung
// erzeugt und beschreiben das Format, das in `assets/catalogs/` und in den
// Katalogen der Nutzer bereits auf Platte liegt. Sie duerfen NICHT angepasst
// werden, wenn ein Test rot wird — dann ist die Implementierung inkompatibel
// geworden und Bestandsdaten waeren unlesbar.
//
// Die uebrigen Krypto-Tests pruefen nur Round-Trips (verschluesseln,
// entschluesseln, vergleichen). Die wuerden eine formatveraendernde
// Neuimplementierung geschlossen bestehen. Diese Datei ist das Gegengewicht.
//
// Wire-Format (identisch mit `tool/encrypt_catalog_fields.py`):
//   v1  `enc:<base64(iv[16] + ciphertext)>`            AES-CBC,  10k PBKDF2
//   v2  `enc:2:<base64(salt[32] + nonce[12] + ct+tag)>` AES-GCM, 100k PBKDF2
//   v3  `enc:3:<base64(nonce[12] + ct+tag)>`            AES-GCM, 100k PBKDF2
// Das GCM-Tag sind immer die letzten 16 Bytes des Ciphertexts.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';

// ── v1 (AES-CBC, festes Legacy-Salt) ──
const goldenV1Password = 'geheim123';
const goldenV1Plaintext = 'Das Schwert des Dämons';
const goldenV1Cipher =
    'enc:wDg+wVgcZrUIZvL9RPtFQwrEFKLekxGu8sqdZzwdYXdI55/nEsoSLCndzajEfVKm';

// ── v2 (AES-GCM, Salt pro Wert) ──
const goldenV2Password = 'geheim123';
const goldenV2Plaintext = 'Das Schwert des Dämons';
const goldenV2Cipher =
    'enc:2:RZNlcCh6jvhsdzqHkAH1OJCrDJ4Pa6s5j2C95AcxCrJ5OXwPqZNFRGlZUQOYbSZzc4s6YTmr9ukDFuxnKabvE2mMx4hpF3U5xHSHoz8zEXFKwAQ=';

// ── v2 mit Umlaut-Passwort (haengt an der NFC-Normalisierung) ──
const goldenV2UmlautPassword = 'N\u00FCrnberg2026!';
const goldenV2UmlautCipher =
    'enc:2:7U3vvRYEclNDsANEjUQ2lZWnfz/iKlkRMz71EbgtDwwZQe47BNw60xKppLxc6sPzeHdLeR+e45pXCo+WLQCn4zsepGangKRLLaiX6S7pHtNyAHw=';

// ── v3 (AES-GCM, globaler Salt, pre-derived Key) ──
const goldenV3Password = 'geheim123';
const goldenV3SaltB64 = '6+70z9LzwtXFDNb/I8zr+WIpGldMVAhqUr5wZ6bzjLo=';
const goldenV3KeyB64 = 'bDkINlK63M3N6uBUbB4225+Xc64uGyZ7ssTK0VQtTgI=';
const goldenV3Plaintext = 'Das Schwert des Dämons';
const goldenV3Cipher =
    'enc:3:wKwwrAeadLetbOw95Iy6nfDPCLUF4g8YGxN7tPV2+acYkfGTNjTXVZwywOEDPZRzvoWv';
const goldenV3ListCipher =
    'enc:3:UYYelo/ZsIvMjY8vyGBg3MZpbj0DS5N9U8zMoIs1H9dVqwDBFhMAmF3uiQWiRqHDQeOvBAX4NRUWCAg=';
const goldenV3List = <String>['Stufe 1', 'Stufe 2', 'Stufe 3'];

void main() {
  group('Golden: v1 (AES-CBC, Legacy)', () {
    test('Bestandschiffrat bleibt entschluesselbar', () {
      expect(
        decryptCatalogValue(goldenV1Cipher, goldenV1Password),
        goldenV1Plaintext,
      );
    });

    test('Falsches Passwort liefert null statt Muell', () {
      expect(decryptCatalogValue(goldenV1Cipher, 'falsch!'), isNull);
    });
  });

  group('Golden: v2 (AES-GCM, Salt pro Wert)', () {
    test('Bestandschiffrat bleibt entschluesselbar', () {
      expect(
        decryptCatalogValue(goldenV2Cipher, goldenV2Password),
        goldenV2Plaintext,
      );
    });

    test('Falsches Passwort liefert null (GCM-Tag schlaegt fehl)', () {
      expect(decryptCatalogValue(goldenV2Cipher, 'falsch!'), isNull);
    });

    test('Umlaut-Passwort in NFC-Form entschluesselt', () {
      expect(
        decryptCatalogValue(goldenV2UmlautCipher, goldenV2UmlautPassword),
        goldenV2Plaintext,
      );
    });

    test('Dasselbe Passwort in NFD-Form entschluesselt ebenfalls', () {
      // 'u' + U+0308 statt U+00FC — visuell gleich, andere UTF-8-Bytes.
      const nfd = 'Nu\u0308rnberg2026!';
      expect(nfd, isNot(goldenV2UmlautPassword));
      expect(
        decryptCatalogValue(goldenV2UmlautCipher, nfd),
        goldenV2Plaintext,
        reason: 'NFC-Normalisierung in _passwordBytes muss erhalten bleiben',
      );
    });
  });

  group('Golden: v3 (globaler Salt, pre-derived Key)', () {
    test('PBKDF2 liefert exakt den festgeschriebenen Key', () {
      final key = deriveCatalogKey(
        password: goldenV3Password,
        salt: base64Decode(goldenV3SaltB64),
      );
      expect(
        base64Encode(key.bytes),
        goldenV3KeyB64,
        reason:
            'Aenderung an PBKDF2 (Iterationen, Hash, Keylaenge) '
            'macht jeden ausgelieferten enc:3:-Wert unlesbar',
      );
    });

    test('Bestandschiffrat bleibt mit abgeleitetem Key entschluesselbar', () {
      final key = deriveCatalogKey(
        password: goldenV3Password,
        salt: base64Decode(goldenV3SaltB64),
      );
      expect(
        decryptCatalogValueV3(encryptedValue: goldenV3Cipher, derivedKey: key),
        goldenV3Plaintext,
      );
    });

    test('Dispatcher entschluesselt v3 ueber Passwort plus saltV3', () {
      expect(
        decryptCatalogValue(
          goldenV3Cipher,
          goldenV3Password,
          saltV3: base64Decode(goldenV3SaltB64),
        ),
        goldenV3Plaintext,
      );
    });

    test('Listen-Chiffrat bleibt entschluesselbar', () {
      final key = deriveCatalogKey(
        password: goldenV3Password,
        salt: base64Decode(goldenV3SaltB64),
      );
      expect(
        decryptCatalogListV3(
          encryptedValue: goldenV3ListCipher,
          derivedKey: key,
        ),
        goldenV3List,
      );
    });
  });
}
