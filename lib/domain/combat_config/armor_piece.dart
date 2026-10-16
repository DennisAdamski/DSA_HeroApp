import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Beschreibt ein einzelnes Ruestungsstueck des Helden.
///
/// Unveraenderlich; Aktualisierungen erfolgen ueber [copyWith].
class ArmorPiece {
  const ArmorPiece({
    this.id = '',
    this.inventarInstanzId = '',
    this.name = '',
    this.isActive = false,
    this.rg1Active = false,
    this.rs = 0,
    this.be = 0,
    this.isArtifact = false,
    this.artifactDescription = '',
    this.isGeweiht = false,
    this.geweihtDescription = '',
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Stabile Kennung des Ruestungsstuecks (siehe `CombatConfig.withStableIds`).
  final String id;

  /// Instanz-ID des Inventareintrags, der dieses Exemplar ist (ARCH-03).
  ///
  /// Verweis Slot → Instanz; leer, bis `HeroActions.saveHero` ihn aus dem
  /// verknuepften Eintrag setzt (`bindeSlotsAnInstanzen`). Abgeleitet, nie
  /// von der Bedienung geschrieben; nur geschrieben, wenn belegt.
  final String inventarInstanzId;

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

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'id',
    'inventarInstanzId',
    'name',
    'isActive',
    'rg1Active',
    'rs',
    'be',
    'isArtifact',
    'artifactDescription',
    'isGeweiht',
    'geweihtDescription',
  };

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  ArmorPiece copyWith({
    String? id,
    String? inventarInstanzId,
    String? name,
    bool? isActive,
    bool? rg1Active,
    int? rs,
    int? be,
    bool? isArtifact,
    String? artifactDescription,
    bool? isGeweiht,
    String? geweihtDescription,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return ArmorPiece(
      id: id ?? this.id,
      inventarInstanzId: inventarInstanzId ?? this.inventarInstanzId,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      rg1Active: rg1Active ?? this.rg1Active,
      rs: rs ?? this.rs,
      be: be ?? this.be,
      isArtifact: isArtifact ?? this.isArtifact,
      artifactDescription: artifactDescription ?? this.artifactDescription,
      isGeweiht: isGeweiht ?? this.isGeweiht,
      geweihtDescription: geweihtDescription ?? this.geweihtDescription,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert das Ruestungsstueck zu einem JSON-kompatiblen Map.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      if (id.isNotEmpty) 'id': id,
      if (inventarInstanzId.isNotEmpty) 'inventarInstanzId': inventarInstanzId,
      'name': name,
      'isActive': isActive,
      'rg1Active': rg1Active,
      'rs': rs,
      'be': be,
      'isArtifact': isArtifact,
      'artifactDescription': artifactDescription,
      'isGeweiht': isGeweiht,
      'geweihtDescription': geweihtDescription,
    }, unbekannteFelder);
  }

  /// Deserialisiert ein [ArmorPiece] aus einem JSON-Map.
  ///
  /// Tolerant bei fehlenden Feldern (Standardwerte werden gesetzt).
  static ArmorPiece fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return ArmorPiece(
      id: (json['id'] as String?) ?? '',
      inventarInstanzId: (json['inventarInstanzId'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      isActive: (json['isActive'] as bool?) ?? false,
      rg1Active: (json['rg1Active'] as bool?) ?? false,
      rs: getInt('rs'),
      be: getInt('be'),
      isArtifact: (json['isArtifact'] as bool?) ?? false,
      artifactDescription: (json['artifactDescription'] as String?) ?? '',
      isGeweiht: (json['isGeweiht'] as bool?) ?? false,
      geweihtDescription: (json['geweihtDescription'] as String?) ?? '',
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArmorPiece &&
          id == other.id &&
          inventarInstanzId == other.inventarInstanzId &&
          name == other.name &&
          isActive == other.isActive &&
          rg1Active == other.rg1Active &&
          rs == other.rs &&
          be == other.be &&
          isArtifact == other.isArtifact &&
          artifactDescription == other.artifactDescription &&
          isGeweiht == other.isGeweiht &&
          geweihtDescription == other.geweihtDescription &&
          unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder);

  @override
  int get hashCode => Object.hash(
    id,
    inventarInstanzId,
    name,
    isActive,
    rg1Active,
    rs,
    be,
    isArtifact,
    artifactDescription,
    isGeweiht,
    geweihtDescription,
    unbekannteFelderHash(unbekannteFelder),
  );
}
