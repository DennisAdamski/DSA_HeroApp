class HeroTalentEntry {
  const HeroTalentEntry({
    this.talentValue = 0,
    this.atValue = 0,
    this.paValue = 0,
    this.modifier = 0,
    this.specialExperiences = 0,
    this.specializations = '',
    this.combatSpecializations = const <String>[],
    this.specialAbilities = '',
    this.ebe = 0,
  });

  final int talentValue;
  final int atValue;
  final int paValue;
  final int modifier;
  final int specialExperiences;
  final String specializations;
  final List<String> combatSpecializations;
  final String specialAbilities;
  final int ebe;

  HeroTalentEntry copyWith({
    int? talentValue,
    int? atValue,
    int? paValue,
    int? modifier,
    int? specialExperiences,
    String? specializations,
    List<String>? combatSpecializations,
    String? specialAbilities,
    int? ebe,
  }) {
    final nextCombatSpecializations = _normalizeStringList(
      combatSpecializations ?? this.combatSpecializations,
    );
    final nextSpecializations =
        specializations ??
        (combatSpecializations != null
            ? nextCombatSpecializations.join(', ')
            : this.specializations);

    return HeroTalentEntry(
      talentValue: talentValue ?? this.talentValue,
      atValue: atValue ?? this.atValue,
      paValue: paValue ?? this.paValue,
      modifier: modifier ?? this.modifier,
      specialExperiences: specialExperiences ?? this.specialExperiences,
      specializations: nextSpecializations,
      combatSpecializations: nextCombatSpecializations,
      specialAbilities: specialAbilities ?? this.specialAbilities,
      ebe: ebe ?? this.ebe,
    );
  }

  Map<String, dynamic> toJson() {
    final normalizedCombatSpecializations = combatSpecializations.isEmpty
        ? _parseSpecializations(specializations)
        : _normalizeStringList(combatSpecializations);
    final serializedSpecializations = normalizedCombatSpecializations.isEmpty
        ? specializations
        : normalizedCombatSpecializations.join(', ');

    return {
      'talentValue': talentValue,
      'atValue': atValue,
      'paValue': paValue,
      'modifier': modifier,
      'specialExperiences': specialExperiences,
      'specializations': serializedSpecializations,
      'combatSpecializations': normalizedCombatSpecializations,
      'specialAbilities': specialAbilities,
      'ebe': ebe,
    };
  }

  static HeroTalentEntry fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    String getString(String key) => (json[key] as String?) ?? '';
    List<String> getStringList(String key) {
      final raw = json[key];
      if (raw is! List) {
        return const <String>[];
      }
      return raw.map((entry) => entry.toString()).toList(growable: false);
    }

    final legacySpecializations = getString('specializations');
    final parsedCombatSpecializations = _normalizeStringList(
      getStringList('combatSpecializations'),
    );
    final mergedCombatSpecializations = parsedCombatSpecializations.isEmpty
        ? _parseSpecializations(legacySpecializations)
        : parsedCombatSpecializations;
    final syncedSpecializations = mergedCombatSpecializations.isEmpty
        ? legacySpecializations
        : mergedCombatSpecializations.join(', ');

    return HeroTalentEntry(
      talentValue: getInt('talentValue'),
      atValue: getInt('atValue'),
      paValue: getInt('paValue'),
      modifier: getInt('modifier'),
      specialExperiences: getInt('specialExperiences'),
      specializations: syncedSpecializations,
      combatSpecializations: mergedCombatSpecializations,
      specialAbilities: getString('specialAbilities'),
      ebe: getInt('ebe'),
    );
  }
}

List<String> _parseSpecializations(String raw) {
  final tokens = raw.split(RegExp(r'[\n,;]+'));
  return _normalizeStringList(tokens);
}

List<String> _normalizeStringList(Iterable<String> values) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || seen.contains(trimmed)) {
      continue;
    }
    seen.add(trimmed);
    normalized.add(trimmed);
  }
  return List<String>.unmodifiable(normalized);
}
