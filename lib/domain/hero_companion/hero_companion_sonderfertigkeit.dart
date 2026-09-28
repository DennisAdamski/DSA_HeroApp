import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Sonderfertigkeit eines Begleiters.
class HeroCompanionSonderfertigkeit {
  const HeroCompanionSonderfertigkeit({
    this.name = '',
    this.beschreibung = '',
    this.unbekannteFelder = const <String, Object?>{},
  });

  final String name;
  final String beschreibung;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{'name', 'beschreibung'};

  HeroCompanionSonderfertigkeit copyWith({
    String? name,
    String? beschreibung,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroCompanionSonderfertigkeit(
      name: name ?? this.name,
      beschreibung: beschreibung ?? this.beschreibung,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  Map<String, dynamic> toJson() => mitUnbekanntenFeldern(<String, dynamic>{
    'name': name,
    'beschreibung': beschreibung,
  }, unbekannteFelder);

  static HeroCompanionSonderfertigkeit fromJson(Map<String, dynamic> json) {
    return HeroCompanionSonderfertigkeit(
      name: (json['name'] as String?) ?? '',
      beschreibung: (json['beschreibung'] as String?) ?? '',
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroCompanionSonderfertigkeit &&
          name == other.name &&
          beschreibung == other.beschreibung &&
          unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder);

  @override
  int get hashCode =>
      Object.hash(name, beschreibung, unbekannteFelderHash(unbekannteFelder));
}
