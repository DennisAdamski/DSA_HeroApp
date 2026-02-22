import 'dart:convert';

import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';

class HeroTransferCodec {
  const HeroTransferCodec();

  String encode(HeroTransferBundle bundle) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(bundle.toJson());
  }

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
