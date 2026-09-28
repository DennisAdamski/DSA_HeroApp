import 'package:dsa_heldenverwaltung/domain/copy_with_sentinel.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

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
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Aktueller Talentwert der Sprache, oder `null` vor der Aktivierung.
  final int? wert;

  /// Optionaler Netto-Modifikator (z. B. durch Ausrüstung oder Sonderfertigkeiten).
  final int modifier;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{'wert', 'modifier'};

  HeroLanguageEntry copyWith({
    Object? wert = keepFieldValue,
    int? modifier,
    Map<String, Object?>? unbekannteFelder,
  }) => HeroLanguageEntry(
    wert: identical(wert, keepFieldValue) ? this.wert : wert as int?,
    modifier: modifier ?? this.modifier,
    unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
  );

  Map<String, dynamic> toJson() => mitUnbekanntenFeldern(<String, dynamic>{
    'wert': wert,
    'modifier': modifier,
  }, unbekannteFelder);

  factory HeroLanguageEntry.fromJson(Map<String, dynamic> json) =>
      HeroLanguageEntry(
        wert: (json['wert'] as num?)?.toInt(),
        modifier: (json['modifier'] as int?) ?? 0,
        unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroLanguageEntry &&
          wert == other.wert &&
          modifier == other.modifier &&
          unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder);

  @override
  int get hashCode =>
      Object.hash(wert, modifier, unbekannteFelderHash(unbekannteFelder));
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
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Aktueller Talentwert der Schrift, oder `null` vor der Aktivierung.
  final int? wert;

  /// Optionaler Netto-Modifikator.
  final int modifier;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{'wert', 'modifier'};

  HeroScriptEntry copyWith({
    Object? wert = keepFieldValue,
    int? modifier,
    Map<String, Object?>? unbekannteFelder,
  }) => HeroScriptEntry(
    wert: identical(wert, keepFieldValue) ? this.wert : wert as int?,
    modifier: modifier ?? this.modifier,
    unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
  );

  Map<String, dynamic> toJson() => mitUnbekanntenFeldern(<String, dynamic>{
    'wert': wert,
    'modifier': modifier,
  }, unbekannteFelder);

  factory HeroScriptEntry.fromJson(Map<String, dynamic> json) =>
      HeroScriptEntry(
        wert: (json['wert'] as num?)?.toInt(),
        modifier: (json['modifier'] as int?) ?? 0,
        unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroScriptEntry &&
          wert == other.wert &&
          modifier == other.modifier &&
          unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder);

  @override
  int get hashCode =>
      Object.hash(wert, modifier, unbekannteFelderHash(unbekannteFelder));
}
