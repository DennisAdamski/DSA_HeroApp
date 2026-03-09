import 'package:dsa_heldenverwaltung/domain/hero_spell_text_overrides.dart';

/// Speichert den Heldenwert in einem einzelnen Zauber (unveraenderlich).
///
/// Analog zu [HeroTalentEntry], aber fuer aktivierte Zauber.
/// [spellValue] entspricht dem ZfW (Zauberferttigkeitswert).
/// [hauszauber] markiert den Zauber als Hauszauber (reduziert Steigerung).
/// [gifted] markiert eine Begabung auf genau diesen Zauber.
/// [specializations] speichert aus Kompatibilitaetsgruenden die Varianten
/// eines Zaubers als Liste von Freitext-Eintraegen.
/// [textOverrides] speichert heldenspezifische Korrekturen fuer importierte
/// Zauberdetails.
class HeroSpellEntry {
  /// Erzeugt einen unveraenderlichen Heldeneintrag fuer einen Zauber.
  const HeroSpellEntry({
    this.spellValue = 0,
    this.modifier = 0,
    this.hauszauber = false,
    this.gifted = false,
    this.learnedRepresentation,
    this.learnedTradition,
    this.specializations = const [],
    this.textOverrides,
  });

  final int spellValue;
  final int modifier;
  final bool hauszauber;
  final bool gifted;
  final String? learnedRepresentation;
  final String? learnedTradition;
  final List<String> specializations;
  final HeroSpellTextOverrides? textOverrides;

  /// Liefert eine gezielte, immutable Aktualisierung des Zaubereintrags.
  HeroSpellEntry copyWith({
    int? spellValue,
    int? modifier,
    bool? hauszauber,
    bool? gifted,
    Object? learnedRepresentation = _keepFieldValue,
    Object? learnedTradition = _keepFieldValue,
    List<String>? specializations,
    Object? textOverrides = _keepFieldValue,
  }) {
    return HeroSpellEntry(
      spellValue: spellValue ?? this.spellValue,
      modifier: modifier ?? this.modifier,
      hauszauber: hauszauber ?? this.hauszauber,
      gifted: gifted ?? this.gifted,
      learnedRepresentation: identical(learnedRepresentation, _keepFieldValue)
          ? this.learnedRepresentation
          : learnedRepresentation as String?,
      learnedTradition: identical(learnedTradition, _keepFieldValue)
          ? this.learnedTradition
          : learnedTradition as String?,
      specializations: specializations ?? this.specializations,
      textOverrides: identical(textOverrides, _keepFieldValue)
          ? this.textOverrides
          : textOverrides as HeroSpellTextOverrides?,
    );
  }

  /// Serialisiert den Zaubereintrag fuer lokale Persistenz und Export.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'spellValue': spellValue,
      'modifier': modifier,
      'hauszauber': hauszauber,
      'gifted': gifted,
      'specializations': specializations,
    };
    if (learnedRepresentation != null && learnedRepresentation!.isNotEmpty) {
      json['learnedRepresentation'] = learnedRepresentation;
    }
    if (learnedTradition != null && learnedTradition!.isNotEmpty) {
      json['learnedTradition'] = learnedTradition;
    }
    final overrides = textOverrides;
    if (overrides != null && !overrides.isEmpty) {
      json['textOverrides'] = overrides.toJson();
    }
    return json;
  }

  /// Liest einen Zaubereintrag rueckwaertskompatibel aus JSON.
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
      gifted: json['gifted'] as bool? ?? false,
      learnedRepresentation: _readNullableString(
        json['learnedRepresentation'],
      ),
      learnedTradition: _readNullableString(json['learnedTradition']),
      specializations: specs,
      textOverrides: HeroSpellTextOverrides.fromJsonValue(
        json['textOverrides'],
      ),
    );
  }
}

const Object _keepFieldValue = Object();

String? _readNullableString(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
