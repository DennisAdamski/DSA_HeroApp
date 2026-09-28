import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Einzelner Angriffsmodus eines Begleiters (z.B. Beißen, Krallen, Sturzflug).
class HeroCompanionAttack {
  const HeroCompanionAttack({
    required this.id,
    this.name = '',
    this.dk = '',
    this.at,
    this.pa,
    this.tp = '',
    this.beschreibung = '',
    this.steigerungAt = 0,
    this.steigerungPa = 0,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Stabiler Schluessel des Angriffs.
  final String id;

  /// Name des Angriffsmodus (z.B. 'Beißen', 'Krallen').
  final String name;

  /// Distanzklasse (Freitext, z.B. 'H', 'A', 'S').
  final String dk;

  /// Attacke-Wert.
  final int? at;

  /// Parade-Wert (null = keine Parade moeglich).
  final int? pa;

  /// Trefferpunkte-Formel (Freitext, z.B. '1W6+3').
  final String tp;

  /// Optionale Beschreibung des Angriffsmodus.
  final String beschreibung;

  /// Gekaufte AT-Steigerungen (Komplexitaet F).
  final int steigerungAt;

  /// Gekaufte PA-Steigerungen (Komplexitaet F).
  final int steigerungPa;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'id',
    'name',
    'dk',
    'at',
    'pa',
    'tp',
    'beschreibung',
    'steigerungAt',
    'steigerungPa',
  };

  HeroCompanionAttack copyWith({
    String? id,
    String? name,
    String? dk,
    Object? at = _keepNull,
    Object? pa = _keepNull,
    String? tp,
    String? beschreibung,
    int? steigerungAt,
    int? steigerungPa,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroCompanionAttack(
      id: id ?? this.id,
      name: name ?? this.name,
      dk: dk ?? this.dk,
      at: identical(at, _keepNull) ? this.at : at as int?,
      pa: identical(pa, _keepNull) ? this.pa : pa as int?,
      tp: tp ?? this.tp,
      beschreibung: beschreibung ?? this.beschreibung,
      steigerungAt: steigerungAt ?? this.steigerungAt,
      steigerungPa: steigerungPa ?? this.steigerungPa,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  Map<String, dynamic> toJson() => mitUnbekanntenFeldern(<String, dynamic>{
    'id': id,
    'name': name,
    'dk': dk,
    if (at != null) 'at': at,
    if (pa != null) 'pa': pa,
    'tp': tp,
    'beschreibung': beschreibung,
    if (steigerungAt != 0) 'steigerungAt': steigerungAt,
    if (steigerungPa != 0) 'steigerungPa': steigerungPa,
  }, unbekannteFelder);

  static HeroCompanionAttack fromJson(Map<String, dynamic> json) {
    return HeroCompanionAttack(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      dk: (json['dk'] as String?) ?? '',
      at: (json['at'] as num?)?.toInt(),
      pa: (json['pa'] as num?)?.toInt(),
      tp: (json['tp'] as String?) ?? '',
      beschreibung: (json['beschreibung'] as String?) ?? '',
      steigerungAt: (json['steigerungAt'] as num?)?.toInt() ?? 0,
      steigerungPa: (json['steigerungPa'] as num?)?.toInt() ?? 0,
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroCompanionAttack &&
          id == other.id &&
          name == other.name &&
          dk == other.dk &&
          at == other.at &&
          pa == other.pa &&
          tp == other.tp &&
          beschreibung == other.beschreibung &&
          steigerungAt == other.steigerungAt &&
          steigerungPa == other.steigerungPa &&
          unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    dk,
    at,
    pa,
    tp,
    beschreibung,
    steigerungAt,
    steigerungPa,
    unbekannteFelderHash(unbekannteFelder),
  );
}

/// Sentinel-Wert fuer nullable copyWith-Felder.
const Object _keepNull = Object();
