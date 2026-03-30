import 'dart:convert';

import 'package:dsa_heldenverwaltung/domain/gruppen_snapshot.dart';

/// Serialisiert und deserialisiert [GruppenSnapshot]-Objekte als JSON-Text.
///
/// Analog zu [HeroTransferCodec] fuer Gruppen-Sharing.
class GruppenSnapshotCodec {
  const GruppenSnapshotCodec();

  /// Serialisiert einen [GruppenSnapshot] zu einem formatierten JSON-String.
  String encode(GruppenSnapshot snapshot) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(snapshot.toJson());
  }

  /// Deserialisiert einen JSON-String zu einem [GruppenSnapshot].
  ///
  /// Wirft [FormatException] wenn der JSON-Text ungueltig ist oder
  /// das `kind`-Feld nicht `dsa.gruppe.snapshot` lautet.
  GruppenSnapshot decode(String rawJson) {
    late final dynamic decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException catch (error) {
      throw FormatException('JSON ungültig: ${error.message}');
    }

    if (decoded is! Map) {
      throw const FormatException(
        'Gruppendatei muss ein JSON-Objekt enthalten.',
      );
    }

    return GruppenSnapshot.fromJson(decoded.cast<String, dynamic>());
  }
}
