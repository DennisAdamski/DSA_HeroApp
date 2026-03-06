/// Heldenspezifische Text-Overrides fuer importierte Zauberdetails.
///
/// `null` bedeutet stets: Katalogwert verwenden. Leere Strings oder eine leere
/// Variantenliste sind dagegen explizite Overrides.
class HeroSpellTextOverrides {
  /// Erzeugt ein unveraenderliches Override-Objekt fuer Zauberdetails.
  const HeroSpellTextOverrides({
    this.aspCost,
    this.targetObject,
    this.range,
    this.duration,
    this.castingTime,
    this.wirkung,
    this.modifications,
    this.variants,
  });

  final String? aspCost;
  final String? targetObject;
  final String? range;
  final String? duration;
  final String? castingTime;
  final String? wirkung;
  final String? modifications;
  final List<String>? variants;

  /// Gibt `true` zurueck, wenn keinerlei heldenspezifische Werte gesetzt sind.
  bool get isEmpty {
    return aspCost == null &&
        targetObject == null &&
        range == null &&
        duration == null &&
        castingTime == null &&
        wirkung == null &&
        modifications == null &&
        variants == null;
  }

  /// Serialisiert nur die Override-Felder des aktivierten Zaubers.
  Map<String, dynamic> toJson() {
    return {
      'aspCost': aspCost,
      'targetObject': targetObject,
      'range': range,
      'duration': duration,
      'castingTime': castingTime,
      'wirkung': wirkung,
      'modifications': modifications,
      'variants': variants,
    };
  }

  /// Liest ein Override-Objekt rueckwaertskompatibel aus JSON.
  static HeroSpellTextOverrides? fromJsonValue(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final json = raw.cast<String, dynamic>();
    final overrides = HeroSpellTextOverrides(
      aspCost: _readNullableString(json, 'aspCost'),
      targetObject: _readNullableString(json, 'targetObject'),
      range: _readNullableString(json, 'range'),
      duration: _readNullableString(json, 'duration'),
      castingTime: _readNullableString(json, 'castingTime'),
      wirkung: _readNullableString(json, 'wirkung'),
      modifications: _readNullableString(json, 'modifications'),
      variants: _readNullableStringList(json, 'variants'),
    );
    return overrides.isEmpty ? null : overrides;
  }
}

/// Liest einen optionalen String-Override rueckwaertskompatibel aus JSON.
String? _readNullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  return value.toString();
}

/// Liest eine optionale Variantenliste rueckwaertskompatibel aus JSON.
List<String>? _readNullableStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! List) {
    return <String>[];
  }
  return value.map((entry) => entry.toString()).toList(growable: false);
}
