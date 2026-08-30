// Golden-Fixture fuer SecretsCipher.
//
// ACHTUNG: Chiffrat und IV unten stammen aus der ausgelieferten
// Implementierung und stehen fuer die Geheimnisse, die bei Nutzern bereits in
// Firestore liegen. Sie duerfen NICHT angepasst werden, wenn der Test rot
// wird — dann waeren jene Bestandsdaten unlesbar.
//
// Format: AES-256-CBC, PKCS7, Key = PBKDF2-HMAC-SHA256(uid, AppSalt, 10k, 32),
// IV pro Aufruf frisch zufaellig und separat abgelegt.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/secrets_cipher.dart';

const goldenSecretUid = 'user-uid-golden';
const goldenSecretPlaintext = 'sk-test-1234567890-äöüß';
const goldenSecretCipherB64 = 'BEmX4nG0v3ixOccFnwPElz26SNIEvyv/tw7wu/Ymoxw=';
const goldenSecretIvB64 = 'n/hbCc0om0tuD+gf/4Wk6Q==';

void main() {
  group('Golden: SecretsCipher', () {
    test('Bestandsgeheimnis bleibt entschluesselbar', () {
      final cipher = SecretsCipher.forUser(goldenSecretUid);
      expect(
        cipher.decryptString(
          cipher: base64Decode(goldenSecretCipherB64),
          iv: base64Decode(goldenSecretIvB64),
        ),
        goldenSecretPlaintext,
      );
    });

    test('Anderer User kann das Bestandsgeheimnis nicht lesen', () {
      final fremd = SecretsCipher.forUser('user-uid-fremd');
      expect(
        () => fremd.decryptString(
          cipher: base64Decode(goldenSecretCipherB64),
          iv: base64Decode(goldenSecretIvB64),
        ),
        throwsA(anything),
      );
    });
  });
}
