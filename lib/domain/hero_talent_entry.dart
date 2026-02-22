class HeroTalentEntry {
  const HeroTalentEntry({
    this.talentValue = 0,
    this.modifier = 0,
    this.specialExperiences = 0,
    this.specializations = '',
    this.specialAbilities = '',
    this.ebe = 0,
  });

  final int talentValue;
  final int modifier;
  final int specialExperiences;
  final String specializations;
  final String specialAbilities;
  final int ebe;

  HeroTalentEntry copyWith({
    int? talentValue,
    int? modifier,
    int? specialExperiences,
    String? specializations,
    String? specialAbilities,
    int? ebe,
  }) {
    return HeroTalentEntry(
      talentValue: talentValue ?? this.talentValue,
      modifier: modifier ?? this.modifier,
      specialExperiences: specialExperiences ?? this.specialExperiences,
      specializations: specializations ?? this.specializations,
      specialAbilities: specialAbilities ?? this.specialAbilities,
      ebe: ebe ?? this.ebe,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'talentValue': talentValue,
      'modifier': modifier,
      'specialExperiences': specialExperiences,
      'specializations': specializations,
      'specialAbilities': specialAbilities,
      'ebe': ebe,
    };
  }

  static HeroTalentEntry fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    String getString(String key) => (json[key] as String?) ?? '';

    return HeroTalentEntry(
      talentValue: getInt('talentValue'),
      modifier: getInt('modifier'),
      specialExperiences: getInt('specialExperiences'),
      specializations: getString('specializations'),
      specialAbilities: getString('specialAbilities'),
      ebe: getInt('ebe'),
    );
  }
}
