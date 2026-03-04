/// Speichert den Heldenwert in einem einzelnen Talent (unveraenderlich).
///
/// Fuer normale Talente werden nur [talentValue] und [modifier] genutzt.
/// Fuer Kampftalente kommen [atValue] und [paValue] hinzu.
///
/// [specializations] und [combatSpecializations] sind redundant gespeichert:
///   - [specializations]: Freitext-String fuer Anzeige und Legacy-Serialisierung
///   - [combatSpecializations]: normalisierte Liste fuer Programm-Logik
/// Beide werden beim Lesen und Schreiben synchron gehalten (siehe [copyWith],
/// [toJson], [fromJson]).
class HeroTalentEntry {
  const HeroTalentEntry({
    this.talentValue = 0,
    this.atValue = 0,
    this.paValue = 0,
    this.modifier = 0,
    this.specialExperiences = 0,
    this.specializations = '',
    this.combatSpecializations = const <String>[],
    this.gifted = false,
    this.ebe = 0,
  });

  final int talentValue;
  final int atValue;
  final int paValue;
  final int modifier;
  final int specialExperiences;
  final String specializations;
  final List<String> combatSpecializations;
  final bool gifted;
  final int ebe;

  /// Erstellt eine Kopie mit geaenderten Feldern.
  ///
  /// Wird [combatSpecializations] angegeben, wird [specializations] automatisch
  /// daraus als kommagetrennte Liste rekonstruiert, um beide Felder konsistent
  /// zu halten. Wird nur [specializations] angegeben, bleibt [combatSpecializations]
  /// unveraendert (kein automatisches Parsen – das obliegt [fromJson]).
  HeroTalentEntry copyWith({
    int? talentValue,
    int? atValue,
    int? paValue,
    int? modifier,
    int? specialExperiences,
    String? specializations,
    List<String>? combatSpecializations,
    bool? gifted,
    int? ebe,
  }) {
    final nextCombatSpecializations = _normalizeStringList(
      combatSpecializations ?? this.combatSpecializations,
    );
    // Wenn combatSpecializations explizit gesetzt wurde, specializations
    // als Join rekonstruieren – sonst den bestehenden Freitext beibehalten.
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
      gifted: gifted ?? this.gifted,
      ebe: ebe ?? this.ebe,
    );
  }

  /// Serialisiert den Eintrag als JSON-Map.
  ///
  /// combatSpecializations wird normalisiert: falls die Liste leer ist, wird
  /// sie aus [specializations] (Legacy-Format) geparst. [specializations]
  /// wird anschliessend als Join der normalisierten Liste gespeichert, um
  /// Konsistenz beim naechsten Laden zu gewaehrleisten.
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
      'gifted': gifted,
      'ebe': ebe,
    };
  }

  /// Laedt einen Eintrag aus einer JSON-Map (rueckwaertskompatibel).
  ///
  /// Migrationslogik fuer [combatSpecializations]:
  ///   Existiert der Schluessel 'combatSpecializations' noch nicht (aeltere
  ///   Schemata), wird die Liste aus dem [specializations]-Freitext geparst.
  ///   So bleibt der AT/PA-Anzeigemodus bei importierten Althelden erhalten.
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
    // Legacy-Fallback: combatSpecializations fehlt in Altschemata → aus
    // specializations-String parsen. Ziel: beide Felder immer synchron.
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
      gifted: json['gifted'] as bool? ?? false,
      ebe: getInt('ebe'),
    );
  }
}

// Teilt einen Freitext-Spezialisierungsstring an Newlines, Kommas und
// Semikolons in einzelne Eintraege auf.
List<String> _parseSpecializations(String raw) {
  final tokens = raw.split(RegExp(r'[\n,;]+'));
  return _normalizeStringList(tokens);
}

// Normalisiert eine String-Liste: trimmt Whitespace, entfernt Leerstrings
// und Duplikate und gibt eine unveraenderliche Liste zurueck.
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
