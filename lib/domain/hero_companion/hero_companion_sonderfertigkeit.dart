import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Sonderfertigkeit eines Begleiters.
class HeroCompanionSonderfertigkeit {
  const HeroCompanionSonderfertigkeit({
    this.name = '',
    this.beschreibung = '',
    this.katalogId = '',
    this.unbekannteFelder = const <String, Object?>{},
  });

  final String name;
  final String beschreibung;

  /// Verweis auf den Pferde-SF-Katalog (`psf_…`); leer bei Freitext.
  ///
  /// Name und Beschreibung bleiben daneben gefüllt, damit ältere App-
  /// Versionen die Sonderfertigkeit weiter anzeigen.
  final String katalogId;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'name',
    'beschreibung',
    'katalogId',
  };

  HeroCompanionSonderfertigkeit copyWith({
    String? name,
    String? beschreibung,
    String? katalogId,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroCompanionSonderfertigkeit(
      name: name ?? this.name,
      beschreibung: beschreibung ?? this.beschreibung,
      katalogId: katalogId ?? this.katalogId,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  Map<String, dynamic> toJson() => mitUnbekanntenFeldern(<String, dynamic>{
    'name': name,
    'beschreibung': beschreibung,
    if (katalogId.isNotEmpty) 'katalogId': katalogId,
  }, unbekannteFelder);

  static HeroCompanionSonderfertigkeit fromJson(Map<String, dynamic> json) {
    return HeroCompanionSonderfertigkeit(
      name: (json['name'] as String?) ?? '',
      beschreibung: (json['beschreibung'] as String?) ?? '',
      katalogId: (json['katalogId'] as String?) ?? '',
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroCompanionSonderfertigkeit &&
          name == other.name &&
          beschreibung == other.beschreibung &&
          katalogId == other.katalogId &&
          unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder);

  @override
  int get hashCode => Object.hash(
    name,
    beschreibung,
    katalogId,
    unbekannteFelderHash(unbekannteFelder),
  );
}
