import 'package:dsa_heldenverwaltung/domain/copy_with_sentinel.dart';

// [MermaidChart: ff341120-63ae-42dd-88e7-391a12fcef7f]
/// Einzelner Modifikatorbaustein eines Talents.
///
/// Die Beschreibung wird beim Erzeugen normalisiert und auf 60 Zeichen
/// begrenzt. Leere Beschreibungen werden bei der Listen-Normalisierung
/// verworfen.
class HeroTalentModifier {
  HeroTalentModifier({required this.modifier, required String description})
    : description = _normalizeModifierDescription(description);

  final int modifier;
  final String description;

  /// Erstellt eine Kopie mit geaendertem Wert oder Text.
  HeroTalentModifier copyWith({int? modifier, String? description}) {
    return HeroTalentModifier(
      modifier: modifier ?? this.modifier,
      description: description ?? this.description,
    );
  }

  /// Serialisiert den Modifikator fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return {'modifier': modifier, 'description': description};
  }

  /// Liest einen Modifikator robust aus JSON.
  static HeroTalentModifier? fromJson(Map<String, dynamic> json) {
    final description = _normalizeModifierDescription(
      (json['description'] as String?) ?? '',
    );
    if (description.isEmpty) {
      return null;
    }
    return HeroTalentModifier(
      modifier: (json['modifier'] as num?)?.toInt() ?? 0,
      description: description,
    );
  }
}

/// Speichert den Heldenwert in einem einzelnen Talent (unveraenderlich).
///
/// Fuer normale Talente werden [talentValue] und [talentModifiers] genutzt.
/// Die Gesamtsumme der Modifikatorbausteine ist ueber [modifier] verfuegbar.
/// Fuer Kampftalente kommen [atValue] und [paValue] hinzu.
///
/// [talentValue] ist nullable: `null` bedeutet, das Talent ist eingeblendet
/// aber noch nicht aktiviert (gelernt). `0` bedeutet aktiviert mit TaW 0.
///
/// [specializations] und [combatSpecializations] sind redundant gespeichert:
///   - [specializations]: Freitext-String fuer Anzeige und Legacy-Serialisierung
///   - [combatSpecializations]: normalisierte Liste fuer Programm-Logik
/// Beide werden beim Lesen und Schreiben synchron gehalten (siehe [copyWith],
/// [toJson], [fromJson]).
class HeroTalentEntry {
  const HeroTalentEntry({
    this.talentValue,
    this.atValue = 0,
    this.paValue = 0,
    int modifier = 0,
    this.talentModifiers = const <HeroTalentModifier>[],
    this.specialExperiences = 0,
    this.specializations = '',
    this.combatSpecializations = const <String>[],
    this.gifted = false,
    this.ebe = 0,
  }) : _legacyModifier = modifier;

  final int? talentValue;
  final int atValue;
  final int paValue;
  final int _legacyModifier;
  final List<HeroTalentModifier> talentModifiers;
  final int specialExperiences;
  final String specializations;
  final List<String> combatSpecializations;
  final bool gifted;
  final int ebe;

  /// Aggregierter Talentmodifikator aus allen Modifikatorbausteinen.
  int get modifier {
    if (talentModifiers.isEmpty) {
      return _legacyModifier;
    }
    return _sumTalentModifiers(talentModifiers);
  }

  /// Erstellt eine Kopie mit geaenderten Feldern.
  ///
  /// Wird [combatSpecializations] angegeben, wird [specializations] automatisch
  /// daraus als kommagetrennte Liste rekonstruiert, um beide Felder konsistent
  /// zu halten. Wird nur [specializations] angegeben, bleibt [combatSpecializations]
  /// unveraendert (kein automatisches Parsen – das obliegt [fromJson]).
  HeroTalentEntry copyWith({
    Object? talentValue = keepFieldValue,
    int? atValue,
    int? paValue,
    int? modifier,
    List<HeroTalentModifier>? talentModifiers,
    int? specialExperiences,
    String? specializations,
    List<String>? combatSpecializations,
    bool? gifted,
    int? ebe,
  }) {
    final nextTalentModifiers = _normalizeTalentModifiers(
      talentModifiers ?? this.talentModifiers,
    );
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
    final nextLegacyModifier = talentModifiers != null
        ? (modifier ?? 0)
        : (modifier ?? _legacyModifier);

    return HeroTalentEntry(
      talentValue: identical(talentValue, keepFieldValue)
          ? this.talentValue
          : talentValue as int?,
      atValue: atValue ?? this.atValue,
      paValue: paValue ?? this.paValue,
      modifier: nextLegacyModifier,
      talentModifiers: nextTalentModifiers,
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
    final normalizedTalentModifiers = _normalizeTalentModifiers(
      talentModifiers,
    );
    final serializedSpecializations = normalizedCombatSpecializations.isEmpty
        ? specializations
        : normalizedCombatSpecializations.join(', ');

    return {
      'talentValue': talentValue,
      'atValue': atValue,
      'paValue': paValue,
      'modifier': _sumTalentModifiers(normalizedTalentModifiers),
      'talentModifiers': normalizedTalentModifiers
          .map((entry) => entry.toJson())
          .toList(growable: false),
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

    List<HeroTalentModifier> getTalentModifiers(String key) {
      final raw = json[key];
      if (raw is! List) {
        return const <HeroTalentModifier>[];
      }
      final entries = <HeroTalentModifier>[];
      for (final value in raw) {
        if (value is! Map) {
          continue;
        }
        final parsed = HeroTalentModifier.fromJson(
          value.cast<String, dynamic>(),
        );
        if (parsed != null) {
          entries.add(parsed);
        }
      }
      return _normalizeTalentModifiers(entries);
    }

    final legacySpecializations = getString('specializations');
    final parsedCombatSpecializations = _normalizeStringList(
      getStringList('combatSpecializations'),
    );
    final talentModifiers = getTalentModifiers('talentModifiers');
    // Legacy-Fallback: combatSpecializations fehlt in Altschemata → aus
    // specializations-String parsen. Ziel: beide Felder immer synchron.
    final mergedCombatSpecializations = parsedCombatSpecializations.isEmpty
        ? _parseSpecializations(legacySpecializations)
        : parsedCombatSpecializations;
    final syncedSpecializations = mergedCombatSpecializations.isEmpty
        ? legacySpecializations
        : mergedCombatSpecializations.join(', ');

    return HeroTalentEntry(
      talentValue: (json['talentValue'] as num?)?.toInt(),
      atValue: getInt('atValue'),
      paValue: getInt('paValue'),
      talentModifiers: talentModifiers,
      specialExperiences: getInt('specialExperiences'),
      specializations: syncedSpecializations,
      combatSpecializations: mergedCombatSpecializations,
      gifted: json['gifted'] as bool? ?? false,
      ebe: getInt('ebe'),
    );
  }
}

String _normalizeModifierDescription(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  if (trimmed.length <= 60) {
    return trimmed;
  }
  return trimmed.substring(0, 60);
}

List<HeroTalentModifier> _normalizeTalentModifiers(
  Iterable<HeroTalentModifier> values,
) {
  final normalized = <HeroTalentModifier>[];
  for (final value in values) {
    final description = _normalizeModifierDescription(value.description);
    if (description.isEmpty) {
      continue;
    }
    normalized.add(
      HeroTalentModifier(modifier: value.modifier, description: description),
    );
  }
  return List<HeroTalentModifier>.unmodifiable(normalized);
}

int _sumTalentModifiers(Iterable<HeroTalentModifier> values) {
  var sum = 0;
  for (final value in values) {
    sum += value.modifier;
  }
  return sum;
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
