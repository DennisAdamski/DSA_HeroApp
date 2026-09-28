import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals/hero_ritual_field.dart';

/// Einzelnes Ritual innerhalb einer Ritualkategorie.
class HeroRitualEntry {
  /// Erzeugt einen unveraenderlichen Ritualeintrag.
  const HeroRitualEntry({
    required this.name,
    this.wirkung = '',
    this.kosten = '',
    this.wirkungsdauer = '',
    this.merkmale = '',
    this.zauberdauer = '',
    this.zielobjekt = '',
    this.reichweite = '',
    this.technik = '',
    this.additionalFieldValues = const <HeroRitualFieldValue>[],
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Anzeigename des Rituals.
  final String name;

  /// Wirkungsbeschreibung des Rituals.
  final String wirkung;

  /// Kosten des Rituals.
  final String kosten;

  /// Wirkungsdauer des Rituals.
  final String wirkungsdauer;

  /// Merkmale des Rituals.
  final String merkmale;

  /// Optionale Zauberdauer.
  final String zauberdauer;

  /// Optionales Zielobjekt.
  final String zielobjekt;

  /// Optionale Reichweite.
  final String reichweite;

  /// Optionale Technik.
  final String technik;

  /// Werte der frei konfigurierten Zusatzfelder.
  final List<HeroRitualFieldValue> additionalFieldValues;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'name',
    'wirkung',
    'kosten',
    'wirkungsdauer',
    'merkmale',
    'zauberdauer',
    'zielobjekt',
    'reichweite',
    'technik',
    'additionalFieldValues',
  };

  /// Erstellt eine Kopie mit geaenderten Feldern.
  HeroRitualEntry copyWith({
    String? name,
    String? wirkung,
    String? kosten,
    String? wirkungsdauer,
    String? merkmale,
    String? zauberdauer,
    String? zielobjekt,
    String? reichweite,
    String? technik,
    List<HeroRitualFieldValue>? additionalFieldValues,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroRitualEntry(
      name: name ?? this.name,
      wirkung: wirkung ?? this.wirkung,
      kosten: kosten ?? this.kosten,
      wirkungsdauer: wirkungsdauer ?? this.wirkungsdauer,
      merkmale: merkmale ?? this.merkmale,
      zauberdauer: zauberdauer ?? this.zauberdauer,
      zielobjekt: zielobjekt ?? this.zielobjekt,
      reichweite: reichweite ?? this.reichweite,
      technik: technik ?? this.technik,
      additionalFieldValues:
          additionalFieldValues ?? this.additionalFieldValues,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert das Ritual fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'name': name,
      'wirkung': wirkung,
      'kosten': kosten,
      'wirkungsdauer': wirkungsdauer,
      'merkmale': merkmale,
      'zauberdauer': zauberdauer,
      'zielobjekt': zielobjekt,
      'reichweite': reichweite,
      'technik': technik,
      'additionalFieldValues': additionalFieldValues
          .map((entry) => entry.toJson())
          .toList(growable: false),
    }, unbekannteFelder);
  }

  /// Liest ein Ritual tolerant aus JSON.
  static HeroRitualEntry fromJson(Map<String, dynamic> json) {
    final rawAdditionalFieldValues =
        (json['additionalFieldValues'] as List?) ?? const <dynamic>[];
    return HeroRitualEntry(
      name: (json['name'] as String?) ?? '',
      wirkung: (json['wirkung'] as String?) ?? '',
      kosten: (json['kosten'] as String?) ?? '',
      wirkungsdauer: (json['wirkungsdauer'] as String?) ?? '',
      merkmale: (json['merkmale'] as String?) ?? '',
      zauberdauer: (json['zauberdauer'] as String?) ?? '',
      zielobjekt: (json['zielobjekt'] as String?) ?? '',
      reichweite: (json['reichweite'] as String?) ?? '',
      technik: (json['technik'] as String?) ?? '',
      additionalFieldValues: rawAdditionalFieldValues
          .whereType<Map>()
          .map(
            (entry) =>
                HeroRitualFieldValue.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroRitualEntry &&
          name == other.name &&
          wirkung == other.wirkung &&
          kosten == other.kosten &&
          wirkungsdauer == other.wirkungsdauer &&
          merkmale == other.merkmale &&
          zauberdauer == other.zauberdauer &&
          zielobjekt == other.zielobjekt &&
          reichweite == other.reichweite &&
          technik == other.technik &&
          _ritualListEqual(
            additionalFieldValues,
            other.additionalFieldValues,
          ) &&
          unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder);

  @override
  int get hashCode => Object.hashAll([
    name,
    wirkung,
    kosten,
    wirkungsdauer,
    merkmale,
    zauberdauer,
    zielobjekt,
    reichweite,
    technik,
    ...additionalFieldValues,
    unbekannteFelderHash(unbekannteFelder),
  ]);
}

bool _ritualListEqual<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
