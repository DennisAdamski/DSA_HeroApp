/// Strukturierte talentbezogene Sonderfertigkeit (Name + optionale Notiz).
class TalentSpecialAbility {
  /// Erzeugt eine persistierte Talent-Sonderfertigkeit.
  const TalentSpecialAbility({
    required this.name,
    this.note = '',
  });

  /// Anzeigename der Sonderfertigkeit.
  final String name;

  /// Optionale freie Zusatznotiz, z. B. Stufe oder Spezialisierung.
  final String note;

  /// Liefert eine gezielte immutable Aktualisierung.
  TalentSpecialAbility copyWith({
    String? name,
    String? note,
  }) {
    return TalentSpecialAbility(
      name: name ?? this.name,
      note: note ?? this.note,
    );
  }

  /// Serialisiert die Sonderfertigkeit in JSON.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'note': note,
    };
  }

  /// Liest eine Sonderfertigkeit robust aus JSON.
  static TalentSpecialAbility fromJson(Map<String, dynamic> json) {
    return TalentSpecialAbility(
      name: (json['name'] as String?) ?? '',
      note: (json['note'] as String?) ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TalentSpecialAbility &&
        other.name == name &&
        other.note == note;
  }

  @override
  int get hashCode => Object.hash(name, note);
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
