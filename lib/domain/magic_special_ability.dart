/// Strukturierte magische Sonderfertigkeit mit Name und Beschreibung.
class MagicSpecialAbility {
  /// Erstellt eine persistierbare magische Sonderfertigkeit.
  const MagicSpecialAbility({required this.name, this.beschreibung = ''});

  /// Sichtbarer Name der Sonderfertigkeit.
  final String name;

  /// Optionale Beschreibung oder heldenspezifische Ausprägung.
  final String beschreibung;

  /// Legacy-Alias für ältere Aufrufer und Datenbestände.
  String get note => beschreibung;

  MagicSpecialAbility copyWith({String? name, String? beschreibung}) {
    return MagicSpecialAbility(
      name: name ?? this.name,
      beschreibung: beschreibung ?? this.beschreibung,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'beschreibung': beschreibung, 'note': beschreibung};
  }

  static MagicSpecialAbility fromJson(Map<String, dynamic> json) {
    final beschreibung =
        (json['beschreibung'] as String?) ?? (json['note'] as String?) ?? '';
    return MagicSpecialAbility(
      name: (json['name'] as String?) ?? '',
      beschreibung: beschreibung,
    );
  }
}
