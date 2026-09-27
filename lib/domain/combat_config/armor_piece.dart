/// Beschreibt ein einzelnes Ruestungsstueck des Helden.
///
/// Unveraenderlich; Aktualisierungen erfolgen ueber [copyWith].
class ArmorPiece {
  const ArmorPiece({
    this.id = '',
    this.name = '',
    this.isActive = false,
    this.rg1Active = false,
    this.rs = 0,
    this.be = 0,
    this.isArtifact = false,
    this.artifactDescription = '',
    this.isGeweiht = false,
    this.geweihtDescription = '',
  });

  /// Stabile Kennung des Ruestungsstuecks (siehe `CombatConfig.withStableIds`).
  final String id;

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

  /// Kennzeichnet das Ruestungsstueck als Artefakt.
  final bool isArtifact;

  /// Freitext-Beschreibung fuer das Artefakt.
  final String artifactDescription;

  /// Kennzeichnet das Ruestungsstueck als geweiht.
  final bool isGeweiht;

  /// Freitext-Beschreibung fuer den geweihten Gegenstand.
  final String geweihtDescription;

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  ArmorPiece copyWith({
    String? id,
    String? name,
    bool? isActive,
    bool? rg1Active,
    int? rs,
    int? be,
    bool? isArtifact,
    String? artifactDescription,
    bool? isGeweiht,
    String? geweihtDescription,
  }) {
    return ArmorPiece(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      rg1Active: rg1Active ?? this.rg1Active,
      rs: rs ?? this.rs,
      be: be ?? this.be,
      isArtifact: isArtifact ?? this.isArtifact,
      artifactDescription: artifactDescription ?? this.artifactDescription,
      isGeweiht: isGeweiht ?? this.isGeweiht,
      geweihtDescription: geweihtDescription ?? this.geweihtDescription,
    );
  }

  /// Serialisiert das Ruestungsstueck zu einem JSON-kompatiblen Map.
  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'isActive': isActive,
      'rg1Active': rg1Active,
      'rs': rs,
      'be': be,
      'isArtifact': isArtifact,
      'artifactDescription': artifactDescription,
      'isGeweiht': isGeweiht,
      'geweihtDescription': geweihtDescription,
    };
  }

  /// Deserialisiert ein [ArmorPiece] aus einem JSON-Map.
  ///
  /// Tolerant bei fehlenden Feldern (Standardwerte werden gesetzt).
  static ArmorPiece fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return ArmorPiece(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      isActive: (json['isActive'] as bool?) ?? false,
      rg1Active: (json['rg1Active'] as bool?) ?? false,
      rs: getInt('rs'),
      be: getInt('be'),
      isArtifact: (json['isArtifact'] as bool?) ?? false,
      artifactDescription: (json['artifactDescription'] as String?) ?? '',
      isGeweiht: (json['isGeweiht'] as bool?) ?? false,
      geweihtDescription: (json['geweihtDescription'] as String?) ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArmorPiece &&
          id == other.id &&
          name == other.name &&
          isActive == other.isActive &&
          rg1Active == other.rg1Active &&
          rs == other.rs &&
          be == other.be &&
          isArtifact == other.isArtifact &&
          artifactDescription == other.artifactDescription &&
          isGeweiht == other.isGeweiht &&
          geweihtDescription == other.geweihtDescription;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    isActive,
    rg1Active,
    rs,
    be,
    isArtifact,
    artifactDescription,
    isGeweiht,
    geweihtDescription,
  );
}
