import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';

/// AES-Primitiven auf Basis von `pointycastle`.
///
/// Bewusst ein blattartiges Modul ohne Abhaengigkeit auf `catalog` oder
/// `data`: beide Schichten brauchen dieselben Bausteine, und die bestehende
/// Richtung `data -> catalog` darf dafuer nicht umgedreht werden.
///
/// Das Wire-Format ist durch ausgelieferte Daten festgelegt und in
/// `test/catalog/catalog_crypto_golden_test.dart` sowie
/// `test/data/secrets_cipher_golden_test.dart` mit festen Chiffraten gepinnt.
/// Wer hier etwas aendert und dort einen Test brechen sieht, hat
/// Bestandsdaten unlesbar gemacht — nicht den Test veraltet.

/// Liefert [length] kryptografisch zufaellige Bytes.
Uint8List secureRandomBytes(int length) {
  final rng = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => rng.nextInt(256)),
  );
}

/// Laenge des GCM-Authentifizierungstags in Bit.
const int _gcmMacBits = 128;

/// Verschluesselt [plaintext] mit AES-256-GCM.
///
/// Der Rueckgabewert traegt das Authentifizierungstag in den letzten 16 Bytes
/// angehaengt — dasselbe Layout, das `tool/encrypt_catalog_fields.py` ueber
/// `AES.new(key, AES.MODE_GCM).encrypt_and_digest()` erzeugt.
Uint8List aesGcmEncrypt({
  required Uint8List key,
  required Uint8List nonce,
  required Uint8List plaintext,
}) {
  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      true,
      AEADParameters(KeyParameter(key), _gcmMacBits, nonce, Uint8List(0)),
    );
  return cipher.process(plaintext);
}

/// Entschluesselt einen AES-256-GCM-Block mit angehaengtem Tag.
///
/// Wirft bei falschem Schluessel oder manipulierten Daten eine
/// [InvalidCipherTextException]; die Aufrufer fangen das ab und liefern `null`.
Uint8List aesGcmDecrypt({
  required Uint8List key,
  required Uint8List nonce,
  required Uint8List cipherWithTag,
}) {
  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      false,
      AEADParameters(KeyParameter(key), _gcmMacBits, nonce, Uint8List(0)),
    );
  return cipher.process(cipherWithTag);
}

/// Verschluesselt [plaintext] mit AES-256-CBC und PKCS7-Padding.
Uint8List aesCbcEncrypt({
  required Uint8List key,
  required Uint8List iv,
  required Uint8List plaintext,
}) {
  return _cbc(forEncryption: true, key: key, iv: iv, input: plaintext);
}

/// Entschluesselt einen AES-256-CBC-Block mit PKCS7-Padding.
///
/// Wirft bei falschem Schluessel in aller Regel eine [ArgumentError] aus der
/// Padding-Pruefung — CBC kennt kein Authentifizierungstag, ein falscher
/// Schluessel faellt also nur ueber ungueltiges Padding auf.
Uint8List aesCbcDecrypt({
  required Uint8List key,
  required Uint8List iv,
  required Uint8List cipher,
}) {
  return _cbc(forEncryption: false, key: key, iv: iv, input: cipher);
}

Uint8List _cbc({
  required bool forEncryption,
  required Uint8List key,
  required Uint8List iv,
  required Uint8List input,
}) {
  final cipher =
      PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))..init(
        forEncryption,
        PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
          ParametersWithIV(KeyParameter(key), iv),
          null,
        ),
      );
  return cipher.process(input);
}
