/// Speichert den Heldenwert in einem einzelnen Zauber (unveraenderlich).
///
/// Analog zu [HeroTalentEntry], aber fuer aktivierte Zauber.
/// [spellValue] entspricht dem ZfW (Zauberferttigkeitswert).
/// [hauszauber] markiert den Zauber als Hauszauber (reduziert Steigerung).
/// [specializations] ist eine Liste von Spezialisierungen des Zaubers.
class HeroSpellEntry {
  const HeroSpellEntry({
    this.spellValue = 0,
    this.modifier = 0,
    this.hauszauber = false,
    this.specializations = const [],
  });

  final int spellValue;
  final int modifier;
  final bool hauszauber;
  final List<String> specializations;

  HeroSpellEntry copyWith({
    int? spellValue,
    int? modifier,
    bool? hauszauber,
    List<String>? specializations,
  }) {
    return HeroSpellEntry(
      spellValue: spellValue ?? this.spellValue,
      modifier: modifier ?? this.modifier,
      hauszauber: hauszauber ?? this.hauszauber,
      specializations: specializations ?? this.specializations,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'spellValue': spellValue,
      'modifier': modifier,
      'hauszauber': hauszauber,
      'specializations': specializations,
    };
  }

  static HeroSpellEntry fromJson(Map<String, dynamic> json) {
    final raw = json['specializations'];
    final List<String> specs;
    if (raw is List) {
      specs = List<String>.from(raw.whereType<String>());
    } else if (raw is String && raw.isNotEmpty) {
      specs = [raw];
    } else {
      specs = <String>[];
    }
    return HeroSpellEntry(
      spellValue: (json['spellValue'] as num?)?.toInt() ?? 0,
      modifier: (json['modifier'] as num?)?.toInt() ?? 0,
      hauszauber: json['hauszauber'] as bool? ?? false,
      specializations: specs,
    );
  }
}
