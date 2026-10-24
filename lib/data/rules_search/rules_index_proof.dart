import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';

/// Praefix der Nachweisbildung; muss mit `tool/rules_index_proof.py` und der
/// Cloud Function (`functions/src/rules_index/api.ts`) uebereinstimmen.
const String rulesIndexProofPrefix = 'rules-index-v1|';

/// Passwortnachweis fuer den Zugang zur Regel-Wissensbasis.
///
/// SHA-256 ueber [rulesIndexProofPrefix] und den v3-Katalogschluessel
/// (PBKDF2, globaler Katalog-Salt). Der Server kennt nur diesen Hash, nie das
/// Passwort, und der Katalogschluessel selbst verlaesst das Geraet nicht.
///
/// Die PBKDF2-Ableitung ist teuer (100000 Runden); der Aufruf gehoert in
/// einen Hintergrundlauf, nicht in den Bau eines Widgets.
String rulesIndexProof({required String password, required Uint8List salt}) {
  final key = deriveCatalogKey(password: password, salt: salt);
  return sha256Hex(
    Uint8List.fromList(<int>[
      ...utf8.encode(rulesIndexProofPrefix),
      ...key.bytes,
    ]),
  );
}

/// SHA-256 der [bytes] als Kleinbuchstaben-Hex.
String sha256Hex(Uint8List bytes) {
  final digest = SHA256Digest().process(bytes);
  final buffer = StringBuffer();
  for (final byte in digest) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
