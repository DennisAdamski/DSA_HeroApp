import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

// ── Legacy-Konstanten (v1: AES-CBC, festes Salt) ─────────────────────────────

final _legacySalt = Uint8List.fromList(
  'dsa_helden_catalog_salt_2026'.codeUnits,
);
const _legacyIvLength = 16;
const _legacyIterations = 10000;

// ── v2-Konstanten (AES-GCM, zufaelliges Salt) ────────────────────────────────

const _saltLength = 32;
const _nonceLength = 12;
const _v2Iterations = 100000;
const _v2Marker = '2:';

// ── Oeffentliche Konstanten ───────────────────────────────────────────────────

/// Praefix fuer verschluesselte Werte in Katalog-JSONs.
const encryptedPrefix = 'enc:';

// ── Interne Hilfsfunktionen ───────────────────────────────────────────────────

Uint8List _randomBytes(int length) {
  final rng = Random.secure();
  return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
}

Key _deriveKeyLegacy(String password) {
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(_legacySalt, _legacyIterations, 32));
  return Key(derivator.process(Uint8List.fromList(utf8.encode(password))));
}

Key _deriveKeyV2(String password, Uint8List salt) {
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, _v2Iterations, 32));
  return Key(derivator.process(Uint8List.fromList(utf8.encode(password))));
}

// ── Oeffentliche API ──────────────────────────────────────────────────────────

/// Prueft ob ein Wert verschluesselt ist (beginnt mit [encryptedPrefix]).
bool isEncryptedValue(dynamic value) =>
    value is String && value.startsWith(encryptedPrefix);

/// Verschluesselt einen Klartext-String mit AES-GCM und zufaelligem Salt.
///
/// Format: `enc:2:<base64(salt[32] + nonce[12] + ciphertext+tag)>`
String encryptCatalogValue(String plaintext, String password) {
  if (plaintext.isEmpty) return plaintext;
  final salt = _randomBytes(_saltLength);
  final nonce = IV(Uint8List.fromList(_randomBytes(_nonceLength)));
  final key = _deriveKeyV2(password, salt);
  final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
  final encrypted = encrypter.encrypt(plaintext, iv: nonce);
  final combined = Uint8List(_saltLength + _nonceLength + encrypted.bytes.length);
  combined.setAll(0, salt);
  combined.setAll(_saltLength, nonce.bytes);
  combined.setAll(_saltLength + _nonceLength, encrypted.bytes);
  return '$encryptedPrefix$_v2Marker${base64Encode(combined)}';
}

/// Entschluesselt einen `enc:`-praefixierten Wert.
///
/// Unterstuetzt v2 (GCM, zufaelliges Salt) und v1 (CBC, festes Salt).
/// Gibt `null` zurueck bei Fehler (falsches Passwort oder korrupte Daten).
String? decryptCatalogValue(String encryptedValue, String password) {
  if (!encryptedValue.startsWith(encryptedPrefix)) return encryptedValue;
  try {
    final payload = encryptedValue.substring(encryptedPrefix.length);
    if (payload.startsWith(_v2Marker)) {
      return _decryptV2(payload.substring(_v2Marker.length), password);
    } else {
      return _decryptLegacy(payload, password);
    }
  } catch (_) {
    return null;
  }
}

String? _decryptV2(String b64Payload, String password) {
  final combined = base64Decode(b64Payload);
  if (combined.length <= _saltLength + _nonceLength) return null;
  final salt = Uint8List.fromList(combined.sublist(0, _saltLength));
  final nonce = IV(Uint8List.fromList(
    combined.sublist(_saltLength, _saltLength + _nonceLength),
  ));
  final cipherBytes = Uint8List.fromList(
    combined.sublist(_saltLength + _nonceLength),
  );
  final key = _deriveKeyV2(password, salt);
  final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
  return encrypter.decrypt(Encrypted(cipherBytes), iv: nonce);
}

String? _decryptLegacy(String b64Payload, String password) {
  final combined = base64Decode(b64Payload);
  if (combined.length <= _legacyIvLength) return null;
  final iv = IV(Uint8List.fromList(combined.sublist(0, _legacyIvLength)));
  final cipherBytes = Uint8List.fromList(combined.sublist(_legacyIvLength));
  final key = _deriveKeyLegacy(password);
  final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
  return encrypter.decrypt(Encrypted(cipherBytes), iv: iv);
}

/// Verschluesselt eine String-Liste als einzelnen `enc:`-Wert.
String encryptCatalogList(List<String> values, String password) {
  if (values.isEmpty) return jsonEncode(values);
  return encryptCatalogValue(jsonEncode(values), password);
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
