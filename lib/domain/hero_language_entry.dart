import 'package:dsa_heldenverwaltung/domain/copy_with_sentinel.dart';

/// Persistierter Spracheintrag eines Helden.
///
/// [wert] ist nullable: `null` bedeutet, die Sprache ist im Katalog
/// ausgewaehlt, aber noch nicht ueber den Steigerungsdialog aktiviert
/// worden (analog zu `HeroTalentEntry.talentValue`). Erst der erste
/// Steigern-Aufruf verrechnet die Aktivierungskosten und setzt einen
/// konkreten Wert (mindestens 0).
class HeroLanguageEntry {
  const HeroLanguageEntry({
    this.wert,
    this.modifier = 0,
  });

  /// Aktueller Talentwert der Sprache, oder `null` vor der Aktivierung.
  final int? wert;

  /// Optionaler Netto-Modifikator (z. B. durch Ausrüstung oder Sonderfertigkeiten).
  final int modifier;

  HeroLanguageEntry copyWith({Object? wert = keepFieldValue, int? modifier}) =>
      HeroLanguageEntry(
        wert: identical(wert, keepFieldValue) ? this.wert : wert as int?,
        modifier: modifier ?? this.modifier,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'wert': wert,
        'modifier': modifier,
      };

  factory HeroLanguageEntry.fromJson(Map<String, dynamic> json) =>
      HeroLanguageEntry(
        wert: (json['wert'] as num?)?.toInt(),
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
///
/// [wert] ist nullable: `null` bedeutet, die Schrift ist im Katalog
/// ausgewaehlt, aber noch nicht ueber den Steigerungsdialog aktiviert
/// worden (analog zu `HeroTalentEntry.talentValue`).
class HeroScriptEntry {
  const HeroScriptEntry({
    this.wert,
    this.modifier = 0,
  });

  /// Aktueller Talentwert der Schrift, oder `null` vor der Aktivierung.
  final int? wert;

  /// Optionaler Netto-Modifikator.
  final int modifier;

  HeroScriptEntry copyWith({Object? wert = keepFieldValue, int? modifier}) =>
      HeroScriptEntry(
        wert: identical(wert, keepFieldValue) ? this.wert : wert as int?,
        modifier: modifier ?? this.modifier,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'wert': wert,
        'modifier': modifier,
      };

  factory HeroScriptEntry.fromJson(Map<String, dynamic> json) =>
      HeroScriptEntry(
        wert: (json['wert'] as num?)?.toInt(),
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
