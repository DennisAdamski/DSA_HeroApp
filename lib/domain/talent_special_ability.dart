import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Strukturierte talentbezogene Sonderfertigkeit (Name + optionale Notiz).
class TalentSpecialAbility {
  /// Erzeugt eine persistierte Talent-Sonderfertigkeit.
  const TalentSpecialAbility({
    required this.name,
    this.note = '',
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Anzeigename der Sonderfertigkeit.
  final String name;

  /// Optionale freie Zusatznotiz, z. B. Stufe oder Spezialisierung.
  final String note;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{'name', 'note'};

  /// Liefert eine gezielte immutable Aktualisierung.
  TalentSpecialAbility copyWith({
    String? name,
    String? note,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return TalentSpecialAbility(
      name: name ?? this.name,
      note: note ?? this.note,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert die Sonderfertigkeit in JSON.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'name': name,
      'note': note,
    }, unbekannteFelder);
  }

  /// Liest eine Sonderfertigkeit robust aus JSON.
  static TalentSpecialAbility fromJson(Map<String, dynamic> json) {
    return TalentSpecialAbility(
      name: (json['name'] as String?) ?? '',
      note: (json['note'] as String?) ?? '',
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TalentSpecialAbility &&
        other.name == name &&
        other.note == note &&
        unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder);
  }

  @override
  int get hashCode =>
      Object.hash(name, note, unbekannteFelderHash(unbekannteFelder));
}

/// Zerlegt Legacy-Freitext in strukturierte Talent-Sonderfertigkeiten.
List<TalentSpecialAbility> parseLegacyTalentSpecialAbilities(String raw) {
  final abilities = <TalentSpecialAbility>[];
  final seen = <String>{};
  final fragments = raw.split(RegExp(r'[\n,;]+'));
  for (final fragment in fragments) {
    final name = fragment.trim();
    if (name.isEmpty) {
      continue;
    }
    final key = name.toLowerCase();
    if (!seen.add(key)) {
      continue;
    }
    abilities.add(TalentSpecialAbility(name: name));
  }
  return List<TalentSpecialAbility>.unmodifiable(abilities);
}
