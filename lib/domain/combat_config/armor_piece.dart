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
    this.isArtifact = false,
    this.artifactDescription = '',
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

  /// Kennzeichnet das Ruestungsstueck als Artefakt.
  final bool isArtifact;

  /// Freitext-Beschreibung fuer das Artefakt.
  final String artifactDescription;

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  ArmorPiece copyWith({
    String? name,
    bool? isActive,
    bool? rg1Active,
    int? rs,
    int? be,
    bool? isArtifact,
    String? artifactDescription,
  }) {
    return ArmorPiece(
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      rg1Active: rg1Active ?? this.rg1Active,
      rs: rs ?? this.rs,
      be: be ?? this.be,
      isArtifact: isArtifact ?? this.isArtifact,
      artifactDescription: artifactDescription ?? this.artifactDescription,
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
      'isArtifact': isArtifact,
      'artifactDescription': artifactDescription,
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
      isArtifact: (json['isArtifact'] as bool?) ?? false,
      artifactDescription: (json['artifactDescription'] as String?) ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArmorPiece &&
          name == other.name &&
          isActive == other.isActive &&
          rg1Active == other.rg1Active &&
          rs == other.rs &&
          be == other.be &&
          isArtifact == other.isArtifact &&
          artifactDescription == other.artifactDescription;

  @override
  int get hashCode => Object.hash(
    name,
    isActive,
    rg1Active,
    rs,
    be,
    isArtifact,
    artifactDescription,
  );
}
