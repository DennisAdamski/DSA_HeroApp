import 'dart:convert';

import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';

/// Serialisiert und deserialisiert [HeroTransferBundle]-Objekte als JSON-Text.
///
/// Wird fuer den Import und Export von Helden als Datei oder Clipboard-Text
/// genutzt. Die Ausgabe ist menschenlesbar (2-Leerzeichen-Einrueckung).
class HeroTransferCodec {
  const HeroTransferCodec();

  /// Serialisiert ein [HeroTransferBundle] zu einem formatierten JSON-String.
  ///
  /// Nutzt [JsonEncoder.withIndent] fuer lesbares Format (2 Leerzeichen).
  String encode(HeroTransferBundle bundle) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(bundle.toJson());
  }

  /// Deserialisiert einen JSON-String zu einem [HeroTransferBundle].
  ///
  /// Wirft [FormatException] wenn:
  /// - der JSON-Text ungueltig ist
  /// - das JSON-Dokument kein Objekt (Map) ist
  HeroTransferBundle decode(String rawJson) {
    late final dynamic decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException catch (error) {
      throw FormatException('JSON ungueltig: ${error.message}');
    }

    if (decoded is! Map) {
      throw const FormatException(
        'Exportdatei muss ein JSON-Objekt enthalten.',
      );
    }

    return HeroTransferBundle.fromJson(decoded.cast<String, dynamic>());
  }
}
