import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/pointycastle.dart' show Pbkdf2Parameters;

/// AES-256-CBC Verschluesselung fuer pro-User-Geheimnisse, die in Firestore
/// als Defense-in-Depth-Schicht zusaetzlich zu den Auth-Rules abgelegt werden.
///
/// Schluessel-Ableitung: PBKDF2-HMAC-SHA256(password=uid, salt=AppSalt,
/// iterations=10000, keyLen=32). Der AppSalt ist eine Compile-Time-Konstante,
/// die als Obfuscation-Layer wirkt — die eigentliche Sicherheit liefern die
/// Firestore Security Rules. IV ist pro Aufruf frisch zufaellig.
class SecretsCipher {
  SecretsCipher._(this._encrypter);

  static const List<int> _appSalt = <int>[
    0x4d, 0x70, 0x53, 0x37, 0x9c, 0xa1, 0xb2, 0xe4,
    0x18, 0x6f, 0x05, 0x91, 0xd3, 0x2a, 0xc8, 0x76,
    0x3b, 0xee, 0x49, 0x12, 0x84, 0xfa, 0x60, 0x07,
    0xab, 0x55, 0x1d, 0xc3, 0x6e, 0x29, 0x77, 0xf0,
  ];
  static const int _iterations = 10000;
  static const int _keyLength = 32;
  static const int _ivLength = 16;

  final Encrypter _encrypter;

  /// Erstellt eine Cipher-Instanz fuer den angegebenen User.
  factory SecretsCipher.forUser(String uid) {
    final keyBytes = _deriveKey(uid);
    final encrypter = Encrypter(AES(Key(keyBytes), mode: AESMode.cbc));
    return SecretsCipher._(encrypter);
  }

  /// Verschluesselt einen Klartext mit frischem zufaelligen IV.
  ///
  /// Leere Strings werden als leerer Cipher mit zufaelligem IV abgelegt —
  /// der CBC-Block-Cipher kann mit Null-Byte-Input nicht umgehen.
  EncryptedSecret encryptString(String plaintext) {
    final iv = IV.fromSecureRandom(_ivLength);
    if (plaintext.isEmpty) {
      return EncryptedSecret(
        cipher: Uint8List(0),
        iv: Uint8List.fromList(iv.bytes),
      );
    }
    final encrypted = _encrypter.encrypt(plaintext, iv: iv);
    return EncryptedSecret(
      cipher: Uint8List.fromList(encrypted.bytes),
      iv: Uint8List.fromList(iv.bytes),
    );
  }

  /// Entschluesselt einen Cipher-Bytes-Block mit zugehoerigem IV.
  String decryptString({
    required Uint8List cipher,
    required Uint8List iv,
  }) {
    if (cipher.isEmpty) {
      return '';
    }
    return _encrypter.decrypt(
      Encrypted(cipher),
      iv: IV(iv),
    );
  }

  static Uint8List _deriveKey(String uid) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(
        Pbkdf2Parameters(
          Uint8List.fromList(_appSalt),
          _iterations,
          _keyLength,
        ),
      );
    return derivator.process(Uint8List.fromList(utf8.encode(uid)));
  }
}

/// Ergebnis einer Verschluesselung: Cipher-Bytes plus zugehoerigem IV.
class EncryptedSecret {
  const EncryptedSecret({required this.cipher, required this.iv});

  final Uint8List cipher;
  final Uint8List iv;
}
