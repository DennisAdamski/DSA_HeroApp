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

  HeroCompanionAttack copyWith({
    String? id,
    String? name,
    String? dk,
    Object? at = _keepNull,
    Object? pa = _keepNull,
    String? tp,
    String? beschreibung,
  }) {
    return HeroCompanionAttack(
      id: id ?? this.id,
      name: name ?? this.name,
      dk: dk ?? this.dk,
      at: identical(at, _keepNull) ? this.at : at as int?,
      pa: identical(pa, _keepNull) ? this.pa : pa as int?,
      tp: tp ?? this.tp,
      beschreibung: beschreibung ?? this.beschreibung,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dk': dk,
    if (at != null) 'at': at,
    if (pa != null) 'pa': pa,
    'tp': tp,
    'beschreibung': beschreibung,
  };

  static HeroCompanionAttack fromJson(Map<String, dynamic> json) {
    return HeroCompanionAttack(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      dk: (json['dk'] as String?) ?? '',
      at: (json['at'] as num?)?.toInt(),
      pa: (json['pa'] as num?)?.toInt(),
      tp: (json['tp'] as String?) ?? '',
      beschreibung: (json['beschreibung'] as String?) ?? '',
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
          beschreibung == other.beschreibung;

  @override
  int get hashCode =>
      Object.hash(id, name, dk, at, pa, tp, beschreibung);
}

/// Sentinel-Wert fuer nullable copyWith-Felder.
const Object _keepNull = Object();
