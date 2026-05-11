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

// ── v3-Konstanten (AES-GCM, globaler Salt, pre-derived Key) ──────────────────

const _v3Iterations = 100000;
const _v3Marker = '3:';

/// Empfohlene Salt-Laenge fuer v3 (entspricht v2-Salt-Laenge).
const catalogSaltLengthV3 = _saltLength;

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
/// Unterstuetzt v3 (GCM, globaler Salt — benoetigt [saltV3]), v2 (GCM,
/// per-Wert Salt) und v1 (CBC, festes Salt). Gibt `null` zurueck bei
/// Fehler (falsches Passwort, fehlender Salt fuer v3, oder korrupte Daten).
String? decryptCatalogValue(
  String encryptedValue,
  String password, {
  Uint8List? saltV3,
}) {
  if (!encryptedValue.startsWith(encryptedPrefix)) return encryptedValue;
  try {
    final payload = encryptedValue.substring(encryptedPrefix.length);
    if (payload.startsWith(_v3Marker)) {
      if (saltV3 == null) return null;
      final key = deriveCatalogKey(password: password, salt: saltV3);
      return decryptCatalogValueV3(
        encryptedValue: encryptedValue,
        derivedKey: key,
      );
    }
    if (payload.startsWith(_v2Marker)) {
      return _decryptV2(payload.substring(_v2Marker.length), password);
    }
    return _decryptLegacy(payload, password);
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

// ── v3-API ────────────────────────────────────────────────────────────────────

/// Leitet aus Passwort + Salt einen AES-256-Key via PBKDF2-HMAC-SHA256 ab.
///
/// In v3 wird der Salt einmal pro Katalog (nicht pro Wert) verwendet, sodass
/// diese Ableitung pro Passwort+Katalog nur ein einziges Mal noetig ist.
Key deriveCatalogKey({required String password, required Uint8List salt}) {
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, _v3Iterations, 32));
  return Key(derivator.process(Uint8List.fromList(utf8.encode(password))));
}

/// Verschluesselt einen Klartext-String mit AES-GCM und einem bereits
/// abgeleiteten Schluessel (v3-Format).
///
/// Format: `enc:3:<base64(nonce[12] + ciphertext+tag)>`
/// Leere Strings werden unveraendert zurueckgegeben.
String encryptCatalogValueV3({
  required String plaintext,
  required Key derivedKey,
}) {
  if (plaintext.isEmpty) return plaintext;
  final nonce = IV(Uint8List.fromList(_randomBytes(_nonceLength)));
  final encrypter = Encrypter(AES(derivedKey, mode: AESMode.gcm));
  final encrypted = encrypter.encrypt(plaintext, iv: nonce);
  final combined = Uint8List(_nonceLength + encrypted.bytes.length);
  combined.setAll(0, nonce.bytes);
  combined.setAll(_nonceLength, encrypted.bytes);
  return '$encryptedPrefix$_v3Marker${base64Encode(combined)}';
}

/// Entschluesselt einen v3-`enc:3:`-Wert mit einem bereits abgeleiteten Key.
///
/// Liefert `null` bei Fehler (falscher Key, korrupte Daten, oder kein
/// v3-Wert).
String? decryptCatalogValueV3({
  required String encryptedValue,
  required Key derivedKey,
}) {
  if (!encryptedValue.startsWith(encryptedPrefix)) return encryptedValue;
  try {
    final payload = encryptedValue.substring(encryptedPrefix.length);
    if (!payload.startsWith(_v3Marker)) return null;
    final b64 = payload.substring(_v3Marker.length);
    final combined = base64Decode(b64);
    if (combined.length <= _nonceLength) return null;
    final nonce = IV(Uint8List.fromList(combined.sublist(0, _nonceLength)));
    final cipherBytes = Uint8List.fromList(combined.sublist(_nonceLength));
    final encrypter = Encrypter(AES(derivedKey, mode: AESMode.gcm));
    return encrypter.decrypt(Encrypted(cipherBytes), iv: nonce);
  } catch (_) {
    return null;
  }
}

/// Verschluesselt eine String-Liste als einzelnen v3-`enc:`-Wert.
///
/// Leere Listen werden als JSON `[]` (ohne `enc:`-Praefix) zurueckgegeben.
String encryptCatalogListV3({
  required List<String> values,
  required Key derivedKey,
}) {
  if (values.isEmpty) return jsonEncode(values);
  return encryptCatalogValueV3(
    plaintext: jsonEncode(values),
    derivedKey: derivedKey,
  );
}

/// Entschluesselt einen v3-`enc:`-Wert zurueck in eine String-Liste.
List<String>? decryptCatalogListV3({
  required String encryptedValue,
  required Key derivedKey,
}) {
  final decrypted = decryptCatalogValueV3(
    encryptedValue: encryptedValue,
    derivedKey: derivedKey,
  );
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

// ── Legacy-Listen-API (v1 / v2) ──────────────────────────────────────────────

/// Verschluesselt eine String-Liste als einzelnen `enc:`-Wert.
String encryptCatalogList(List<String> values, String password) {
  if (values.isEmpty) return jsonEncode(values);
  return encryptCatalogValue(jsonEncode(values), password);
}

/// Entschluesselt einen `enc:`-Wert zurueck in eine String-Liste.
///
/// Gibt `null` bei Fehler zurueck. Fuer v3-Werte muss [saltV3] mitgegeben
/// werden.
List<String>? decryptCatalogList(
  String encryptedValue,
  String password, {
  Uint8List? saltV3,
}) {
  final decrypted = decryptCatalogValue(
    encryptedValue,
    password,
    saltV3: saltV3,
  );
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
