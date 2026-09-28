import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Strukturierte magische Sonderfertigkeit mit Name und Beschreibung.
class MagicSpecialAbility {
  /// Erstellt eine persistierbare magische Sonderfertigkeit.
  const MagicSpecialAbility({
    required this.name,
    this.beschreibung = '',
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Sichtbarer Name der Sonderfertigkeit.
  final String name;

  /// Optionale Beschreibung oder heldenspezifische Ausprägung.
  final String beschreibung;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest, einschliesslich des Alias `note`.
  static const Set<String> jsonSchluessel = <String>{
    'name',
    'beschreibung',
    'note',
  };

  /// Legacy-Alias für ältere Aufrufer und Datenbestände.
  String get note => beschreibung;

  MagicSpecialAbility copyWith({
    String? name,
    String? beschreibung,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return MagicSpecialAbility(
      name: name ?? this.name,
      beschreibung: beschreibung ?? this.beschreibung,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'name': name,
      'beschreibung': beschreibung,
      'note': beschreibung,
    }, unbekannteFelder);
  }

  static MagicSpecialAbility fromJson(Map<String, dynamic> json) {
    final beschreibung =
        (json['beschreibung'] as String?) ?? (json['note'] as String?) ?? '';
    return MagicSpecialAbility(
      name: (json['name'] as String?) ?? '',
      beschreibung: beschreibung,
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}
