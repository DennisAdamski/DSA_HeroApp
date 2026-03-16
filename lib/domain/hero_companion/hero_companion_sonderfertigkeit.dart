/// Sonderfertigkeit eines Begleiters.
class HeroCompanionSonderfertigkeit {
  const HeroCompanionSonderfertigkeit({this.name = '', this.beschreibung = ''});

  final String name;
  final String beschreibung;

  HeroCompanionSonderfertigkeit copyWith({String? name, String? beschreibung}) {
    return HeroCompanionSonderfertigkeit(
      name: name ?? this.name,
      beschreibung: beschreibung ?? this.beschreibung,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'beschreibung': beschreibung,
  };

  static HeroCompanionSonderfertigkeit fromJson(Map<String, dynamic> json) {
    return HeroCompanionSonderfertigkeit(
      name: (json['name'] as String?) ?? '',
      beschreibung: (json['beschreibung'] as String?) ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroCompanionSonderfertigkeit &&
          name == other.name &&
          beschreibung == other.beschreibung;

  @override
  int get hashCode => Object.hash(name, beschreibung);
}
