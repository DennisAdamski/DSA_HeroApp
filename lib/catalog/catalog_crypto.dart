import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

/// Festes Salt fuer die PBKDF2-Key-Derivation.
/// Reicht fuer Content-Schutz; kein kryptographisches Geheimnis.
final _salt = Uint8List.fromList(
  'dsa_helden_catalog_salt_2026'.codeUnits,
);

/// Laenge des zufaelligen IV in Bytes (AES-CBC Standard).
const _ivLength = 16;

/// PBKDF2-Iterationen fuer die Key-Derivation.
const _pbkdf2Iterations = 10000;

/// Leitet aus einem Passwort einen 256-Bit AES-Schluessel ab.
Key _deriveKey(String password) {
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(_salt, _pbkdf2Iterations, 32));
  final keyBytes = derivator.process(Uint8List.fromList(utf8.encode(password)));
  return Key(keyBytes);
}

/// Praefix fuer verschluesselte Werte in Katalog-JSONs.
const encryptedPrefix = 'enc:';

/// Prueft ob ein Wert verschluesselt ist (beginnt mit [encryptedPrefix]).
bool isEncryptedValue(dynamic value) =>
    value is String && value.startsWith(encryptedPrefix);

/// Verschluesselt einen Klartext-String.
///
/// Gibt einen `enc:`-praefixierten Base64-String zurueck, der IV + Ciphertext
/// enthaelt.
String encryptCatalogValue(String plaintext, String password) {
  if (plaintext.isEmpty) return plaintext;
  final key = _deriveKey(password);
  final iv = IV.fromSecureRandom(_ivLength);
  final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
  final encrypted = encrypter.encrypt(plaintext, iv: iv);
  // IV + Ciphertext zusammen als Base64 kodieren.
  final combined = Uint8List(iv.bytes.length + encrypted.bytes.length);
  combined.setAll(0, iv.bytes);
  combined.setAll(iv.bytes.length, encrypted.bytes);
  return '$encryptedPrefix${base64Encode(combined)}';
}

/// Entschluesselt einen `enc:`-praefixierten Wert.
///
/// Gibt den Klartext zurueck oder `null` bei Fehler (falsches Passwort).
String? decryptCatalogValue(String encryptedValue, String password) {
  if (!encryptedValue.startsWith(encryptedPrefix)) return encryptedValue;
  try {
    final payload = encryptedValue.substring(encryptedPrefix.length);
    final combined = base64Decode(payload);
    if (combined.length <= _ivLength) return null;
    final iv = IV(Uint8List.fromList(combined.sublist(0, _ivLength)));
    final cipherBytes = combined.sublist(_ivLength);
    final key = _deriveKey(password);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    return encrypter.decrypt(
      Encrypted(Uint8List.fromList(cipherBytes)),
      iv: iv,
    );
  } catch (_) {
    return null;
  }
}

/// Verschluesselt eine String-Liste als einzelnen `enc:`-Wert.
///
/// Die Liste wird als JSON-Array serialisiert und dann verschluesselt.
String encryptCatalogList(List<String> values, String password) {
  if (values.isEmpty) return jsonEncode(values);
  final jsonString = jsonEncode(values);
  return encryptCatalogValue(jsonString, password);
}

/// Entschluesselt einen `enc:`-Wert zurueck in eine String-Liste.
///
/// Gibt `null` bei Fehler zurueck.
List<String>? decryptCatalogList(String encryptedValue, String password) {
  final decrypted = decryptCatalogValue(encryptedValue, password);
  if (decrypted == null) return null;
  try {
    final decoded = jsonDecode(decrypted);
    if (decoded is List) {
      return decoded.map((e) => e.toString()).toList(growable: false);
    }
    return null;
  } catch (_) {
    return null;
  }
}
