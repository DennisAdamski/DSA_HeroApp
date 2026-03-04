/// Beschreibt ein einzelnes Ruestungsstueck des Helden.
///
/// Unveraenderlich; Aktualisierungen erfolgen ueber [copyWith].
class ArmorPiece {
  const ArmorPiece({
    this.name = '',
    this.isActive = false,
    this.rg1Active = false,
    this.rs = 0,
    this.be = 0,
  });

  /// Anzeigename des Ruestungsstuecks.
  final String name;

  /// Gibt an, ob das Ruestungsstueck aktuell angelegt ist.
  final bool isActive;

  /// Gibt an, ob Ruestungsgewoehnung Stufe 1 auf dieses Stueck angewendet wird.
  final bool rg1Active;

  /// Ruestungsschutz des Stuecks.
  final int rs;

  /// Behinderungswert des Stuecks.
  final int be;

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  ArmorPiece copyWith({
    String? name,
    bool? isActive,
    bool? rg1Active,
    int? rs,
    int? be,
  }) {
    return ArmorPiece(
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      rg1Active: rg1Active ?? this.rg1Active,
      rs: rs ?? this.rs,
      be: be ?? this.be,
    );
  }

  /// Serialisiert das Ruestungsstueck zu einem JSON-kompatiblen Map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'isActive': isActive,
      'rg1Active': rg1Active,
      'rs': rs,
      'be': be,
    };
  }

  /// Deserialisiert ein [ArmorPiece] aus einem JSON-Map.
  ///
  /// Tolerant bei fehlenden Feldern (Standardwerte werden gesetzt).
  static ArmorPiece fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return ArmorPiece(
      name: (json['name'] as String?) ?? '',
      isActive: (json['isActive'] as bool?) ?? false,
      rg1Active: (json['rg1Active'] as bool?) ?? false,
      rs: getInt('rs'),
      be: getInt('be'),
    );
  }
}
