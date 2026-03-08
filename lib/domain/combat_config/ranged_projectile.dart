/// Ein konkreter Geschosstyp mit eigenem Bestand und Modifikatoren.
class RangedProjectile {
  const RangedProjectile({
    this.name = '',
    this.count = 0,
    this.tpMod = 0,
    this.iniMod = 0,
    this.atMod = 0,
    this.description = '',
  });

  /// Anzeigename des Geschosses.
  final String name;

  /// Persistenter Bestand fuer dieses Geschoss.
  final int count;

  /// TP-Modifikator dieses Geschosses.
  final int tpMod;

  /// INI-Modifikator dieses Geschosses.
  final int iniMod;

  /// AT-Modifikator dieses Geschosses.
  final int atMod;

  /// Freitextbeschreibung des Geschosses.
  final String description;

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  RangedProjectile copyWith({
    String? name,
    int? count,
    int? tpMod,
    int? iniMod,
    int? atMod,
    String? description,
  }) {
    return RangedProjectile(
      name: name ?? this.name,
      count: count ?? this.count,
      tpMod: tpMod ?? this.tpMod,
      iniMod: iniMod ?? this.iniMod,
      atMod: atMod ?? this.atMod,
      description: description ?? this.description,
    );
  }

  /// Serialisiert das Geschoss fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'count': count,
      'tpMod': tpMod,
      'iniMod': iniMod,
      'atMod': atMod,
      'description': description,
    };
  }

  /// Liest ein Geschoss tolerant aus JSON.
  static RangedProjectile fromJson(Map<String, dynamic> json) {
    final hasAtMod = json.containsKey('atMod') && json['atMod'] != null;
    return RangedProjectile(
      name: (json['name'] as String?) ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      tpMod: (json['tpMod'] as num?)?.toInt() ?? 0,
      iniMod: (json['iniMod'] as num?)?.toInt() ?? 0,
      atMod: hasAtMod
          ? (json['atMod'] as num?)?.toInt() ?? 0
          : (json['fkMod'] as num?)?.toInt() ?? 0,
      description: (json['description'] as String?) ?? '',
    );
  }
}
