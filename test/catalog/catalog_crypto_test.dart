import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc_pkg;
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/protected_content_helpers.dart';

// Repliziert den v1-Algorithmus aus catalog_crypto.dart für Test-Fixtures.
String _encryptV1(String plaintext, String password) {
  final salt = Uint8List.fromList('dsa_helden_catalog_salt_2026'.codeUnits);
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, 10000, 32));
  final keyBytes = derivator.process(Uint8List.fromList(utf8.encode(password)));
  final key = enc_pkg.Key(keyBytes);
  final rng = Random.secure();
  final ivBytes = Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
  final iv = enc_pkg.IV(ivBytes);
  final encrypter = enc_pkg.Encrypter(enc_pkg.AES(key, mode: enc_pkg.AESMode.cbc));
  final encrypted = encrypter.encrypt(plaintext, iv: iv);
  final combined = Uint8List(16 + encrypted.bytes.length);
  combined.setAll(0, ivBytes);
  combined.setAll(16, encrypted.bytes);
  return 'enc:${base64Encode(combined)}';
}

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

  group('Fehlerfälle', () {
    test('Falsches Passwort liefert null', () {
      final encrypted = encryptCatalogValue(plaintext, password);
      final result = decryptCatalogValue(encrypted, 'falsch!');
      expect(result, isNull);
    });

    test('Leerer Plaintext bleibt leer (kein enc:-Präfix)', () {
      final encrypted = encryptCatalogValue('', password);
      expect(encrypted, '');
    });

    test('Unverschlüsselter Wert wird unverändert zurückgegeben', () {
      const raw = 'kein enc: hier';
      expect(decryptCatalogValue(raw, password), raw);
    });
  });

  group('v1-Rückwärtskompatibilität (AES-CBC, fixes Salt)', () {
    test('v1-Wert wird korrekt entschlüsselt', () {
      final v1 = _encryptV1('Das Schwert des Dämons', password);
      expect(decryptCatalogValue(v1, password), 'Das Schwert des Dämons');
    });

    test('v1-Wert mit falschem Passwort liefert null', () {
      final v1 = _encryptV1('Das Schwert des Dämons', password);
      expect(decryptCatalogValue(v1, 'falsch!'), isNull);
    });
  });

  group('encryptCatalogList / decryptCatalogList', () {
    test('Roundtrip einer nicht-leeren Liste', () {
      const list = ['Stufe 1', 'Stufe 2', 'Stufe 3'];
      final encrypted = encryptCatalogList(list, password);
      final decrypted = decryptCatalogList(encrypted, password);
      expect(decrypted, list);
    });

    test('Leere Liste wird als JSON gespeichert, nicht als enc:-Wert', () {
      final encrypted = encryptCatalogList([], password);
      expect(encrypted, isNot(startsWith('enc:')));
    });

    test('Falsches Passwort liefert null', () {
      const list = ['a', 'b'];
      final encrypted = encryptCatalogList(list, password);
      expect(decryptCatalogList(encrypted, 'falsch'), isNull);
    });
  });

  group('resolveProtectedValue', () {
    test('Unverschlüsselter Wert wird direkt zurückgegeben', () {
      expect(
        resolveProtectedValue(raw: 'offen', unlocked: false, password: null),
        'offen',
      );
    });

    test('Verschlüsselt + gesperrt → null', () {
      final enc = encryptCatalogValue('geheim', password);
      expect(
        resolveProtectedValue(raw: enc, unlocked: false, password: password),
        isNull,
      );
    });

    test('Verschlüsselt + entsperrt → Klartext', () {
      final enc = encryptCatalogValue('geheim', password);
      expect(
        resolveProtectedValue(raw: enc, unlocked: true, password: password),
        'geheim',
      );
    });
  });

  group('resolveProtectedList', () {
    test('Klartextliste wird durchgereicht', () {
      expect(
        resolveProtectedList(raw: ['a', 'b'], unlocked: false, password: null),
        ['a', 'b'],
      );
    });

    test('Verschlüsselte Liste + entsperrt → entschlüsselt', () {
      const list = ['x', 'y'];
      final enc = encryptCatalogList(list, password);
      expect(
        resolveProtectedList(raw: enc, unlocked: true, password: password),
        list,
      );
    });

    test('Verschlüsselte Liste + gesperrt → null', () {
      const list = ['x', 'y'];
      final enc = encryptCatalogList(list, password);
      expect(
        resolveProtectedList(raw: enc, unlocked: false, password: null),
        isNull,
      );
    });
  });
}
