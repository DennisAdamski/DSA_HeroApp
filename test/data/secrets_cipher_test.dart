import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/secrets_cipher.dart';

void main() {
  group('SecretsCipher', () {
    test('Round-Trip ASCII liefert urspruenglichen Text', () {
      final cipher = SecretsCipher.forUser('user-uid-1');
      final encrypted = cipher.encryptString('sk-test-1234567890');
      final decrypted = cipher.decryptString(
        cipher: encrypted.cipher,
        iv: encrypted.iv,
      );
      expect(decrypted, 'sk-test-1234567890');
    });

    test('Round-Trip mit Umlauten und Eszett funktioniert', () {
      final cipher = SecretsCipher.forUser('user-uid-1');
      const plaintext = 'mein-passwört-mit-üöä-und-ß';
      final encrypted = cipher.encryptString(plaintext);
      final decrypted = cipher.decryptString(
        cipher: encrypted.cipher,
        iv: encrypted.iv,
      );
      expect(decrypted, plaintext);
    });

    test('Round-Trip mit leerem String funktioniert', () {
      final cipher = SecretsCipher.forUser('user-uid-1');
      final encrypted = cipher.encryptString('');
      final decrypted = cipher.decryptString(
        cipher: encrypted.cipher,
        iv: encrypted.iv,
      );
      expect(decrypted, '');
    });

    test('Zwei encrypt-Aufrufe mit gleichem Plaintext liefern unterschiedliche IVs', () {
      final cipher = SecretsCipher.forUser('user-uid-1');
      final a = cipher.encryptString('sk-secret');
      final b = cipher.encryptString('sk-secret');
      expect(a.iv, isNot(equals(b.iv)),
          reason: 'IV muss pro Aufruf frisch zufaellig sein');
      expect(a.cipher, isNot(equals(b.cipher)),
          reason: 'Cipher unterscheidet sich aufgrund unterschiedlicher IVs');
    });

    test('IV ist 16 Byte lang (AES-Blockgroesse)', () {
      final cipher = SecretsCipher.forUser('user-uid-1');
      final encrypted = cipher.encryptString('foo');
      expect(encrypted.iv.length, 16);
    });

    test('Cipher-Bytes enthalten keinen Klartext', () {
      final cipher = SecretsCipher.forUser('user-uid-1');
      final encrypted = cipher.encryptString('PLAINTEXT_MARKER_XYZ');
      final asString = utf8.decode(encrypted.cipher, allowMalformed: true);
      expect(asString, isNot(contains('PLAINTEXT_MARKER_XYZ')));
    });

    test('Entschluesselung mit anderem User schlaegt fehl', () {
      final cipherA = SecretsCipher.forUser('user-uid-AAAA');
      final cipherB = SecretsCipher.forUser('user-uid-BBBB');

      final encrypted = cipherA.encryptString('hallo welt');
      expect(
        () => cipherB.decryptString(
          cipher: encrypted.cipher,
          iv: encrypted.iv,
        ),
        throwsA(anything),
      );
    });

    test('Gleicher User ergibt deterministischen Schluessel ueber Instanzen hinweg', () {
      final cipher1 = SecretsCipher.forUser('user-uid-1');
      final cipher2 = SecretsCipher.forUser('user-uid-1');

      final encrypted = cipher1.encryptString('persistiert');
      final decrypted = cipher2.decryptString(
        cipher: encrypted.cipher,
        iv: encrypted.iv,
      );
      expect(decrypted, 'persistiert');
    });
  });
}
