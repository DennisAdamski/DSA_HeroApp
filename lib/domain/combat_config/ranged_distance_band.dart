/// Eine frei benennbare Distanzstufe einer Fernkampfwaffe.
class RangedDistanceBand {
  const RangedDistanceBand({this.label = '', this.tpMod = 0});

  /// Anzeigename der Distanzstufe.
  final String label;

  /// TP-Modifikator fuer diese Distanzstufe.
  final int tpMod;

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  RangedDistanceBand copyWith({String? label, int? tpMod}) {
    return RangedDistanceBand(
      label: label ?? this.label,
      tpMod: tpMod ?? this.tpMod,
    );
  }

  /// Serialisiert die Distanzstufe fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return {'label': label, 'tpMod': tpMod};
  }

  /// Liest eine Distanzstufe tolerant aus JSON.
  static RangedDistanceBand fromJson(Map<String, dynamic> json) {
    return RangedDistanceBand(
      label: (json['label'] as String?) ?? '',
      tpMod: (json['tpMod'] as num?)?.toInt() ?? 0,
    );
  }
}
