import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Eine frei benennbare Distanzstufe einer Fernkampfwaffe.
class RangedDistanceBand {
  const RangedDistanceBand({
    this.label = '',
    this.tpMod = 0,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Anzeigename der Distanzstufe.
  final String label;

  /// TP-Modifikator fuer diese Distanzstufe.
  final int tpMod;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{'label', 'tpMod'};

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  RangedDistanceBand copyWith({
    String? label,
    int? tpMod,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return RangedDistanceBand(
      label: label ?? this.label,
      tpMod: tpMod ?? this.tpMod,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert die Distanzstufe fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'label': label,
      'tpMod': tpMod,
    }, unbekannteFelder);
  }

  /// Liest eine Distanzstufe tolerant aus JSON.
  static RangedDistanceBand fromJson(Map<String, dynamic> json) {
    return RangedDistanceBand(
      label: (json['label'] as String?) ?? '',
      tpMod: (json['tpMod'] as num?)?.toInt() ?? 0,
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}
