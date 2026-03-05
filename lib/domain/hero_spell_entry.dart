/// Speichert den Heldenwert in einem einzelnen Zauber (unveraenderlich).
///
/// Analog zu [HeroTalentEntry], aber fuer aktivierte Zauber.
/// [spellValue] entspricht dem ZfW (Zauberferttigkeitswert).
/// [hauszauber] markiert den Zauber als Hauszauber (reduziert Steigerung).
class HeroSpellEntry {
  const HeroSpellEntry({
    this.spellValue = 0,
    this.modifier = 0,
    this.hauszauber = false,
    this.specializations = '',
  });

  final int spellValue;
  final int modifier;
  final bool hauszauber;
  final String specializations;

  HeroSpellEntry copyWith({
    int? spellValue,
    int? modifier,
    bool? hauszauber,
    String? specializations,
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
    return HeroSpellEntry(
      spellValue: (json['spellValue'] as num?)?.toInt() ?? 0,
      modifier: (json['modifier'] as num?)?.toInt() ?? 0,
      hauszauber: json['hauszauber'] as bool? ?? false,
      specializations: (json['specializations'] as String?) ?? '',
    );
  }
}
