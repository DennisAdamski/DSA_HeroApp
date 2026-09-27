import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Ein konkreter Geschosstyp mit eigenem Bestand und Modifikatoren.
class RangedProjectile {
  const RangedProjectile({
    this.id = '',
    this.name = '',
    this.count = 0,
    this.tpMod = 0,
    this.iniMod = 0,
    this.atMod = 0,
    this.description = '',
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Stabile Kennung des Geschosses innerhalb seiner Waffe.
  final String id;

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

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest — einschliesslich des
  /// Altschluessels `fkMod`, der beim Laden in [atMod] aufgeht und deshalb
  /// nicht als unbekannt zurueckgeschrieben werden darf.
  static const Set<String> jsonSchluessel = <String>{
    'id',
    'name',
    'count',
    'tpMod',
    'iniMod',
    'atMod',
    'fkMod',
    'description',
  };

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  RangedProjectile copyWith({
    String? id,
    String? name,
    int? count,
    int? tpMod,
    int? iniMod,
    int? atMod,
    String? description,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return RangedProjectile(
      id: id ?? this.id,
      name: name ?? this.name,
      count: count ?? this.count,
      tpMod: tpMod ?? this.tpMod,
      iniMod: iniMod ?? this.iniMod,
      atMod: atMod ?? this.atMod,
      description: description ?? this.description,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert das Geschoss fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'count': count,
      'tpMod': tpMod,
      'iniMod': iniMod,
      'atMod': atMod,
      'description': description,
    }, unbekannteFelder);
  }

  /// Liest ein Geschoss tolerant aus JSON.
  static RangedProjectile fromJson(Map<String, dynamic> json) {
    final hasAtMod = json.containsKey('atMod') && json['atMod'] != null;
    return RangedProjectile(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      tpMod: (json['tpMod'] as num?)?.toInt() ?? 0,
      iniMod: (json['iniMod'] as num?)?.toInt() ?? 0,
      atMod: hasAtMod
          ? (json['atMod'] as num?)?.toInt() ?? 0
          : (json['fkMod'] as num?)?.toInt() ?? 0,
      description: (json['description'] as String?) ?? '',
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}
