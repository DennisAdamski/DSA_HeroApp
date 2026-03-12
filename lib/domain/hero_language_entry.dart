/// Persistierter Spracheintrag eines Helden.
class HeroLanguageEntry {
  const HeroLanguageEntry({
    this.wert = 0,
    this.modifier = 0,
  });

  /// Aktueller Talentwert der Sprache.
  final int wert;

  /// Optionaler Netto-Modifikator (z. B. durch Ausrüstung oder Sonderfertigkeiten).
  final int modifier;

  HeroLanguageEntry copyWith({int? wert, int? modifier}) => HeroLanguageEntry(
        wert: wert ?? this.wert,
        modifier: modifier ?? this.modifier,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'wert': wert,
        'modifier': modifier,
      };

  factory HeroLanguageEntry.fromJson(Map<String, dynamic> json) =>
      HeroLanguageEntry(
        wert: (json['wert'] as int?) ?? 0,
        modifier: (json['modifier'] as int?) ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroLanguageEntry &&
          wert == other.wert &&
          modifier == other.modifier;

  @override
  int get hashCode => Object.hash(wert, modifier);
}

/// Persistierter Schrifteintrag eines Helden.
class HeroScriptEntry {
  const HeroScriptEntry({
    this.wert = 0,
    this.modifier = 0,
  });

  /// Aktueller Talentwert der Schrift.
  final int wert;

  /// Optionaler Netto-Modifikator.
  final int modifier;

  HeroScriptEntry copyWith({int? wert, int? modifier}) => HeroScriptEntry(
        wert: wert ?? this.wert,
        modifier: modifier ?? this.modifier,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'wert': wert,
        'modifier': modifier,
      };

  factory HeroScriptEntry.fromJson(Map<String, dynamic> json) =>
      HeroScriptEntry(
        wert: (json['wert'] as int?) ?? 0,
        modifier: (json['modifier'] as int?) ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroScriptEntry &&
          wert == other.wert &&
          modifier == other.modifier;

  @override
  int get hashCode => Object.hash(wert, modifier);
}
