import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Einzelner Bewegungswert eines Begleiters (z.B. Schwimmen, Fliegen).
class HeroCompanionSpeed {
  const HeroCompanionSpeed({
    this.art = '',
    this.wert = 0,
    this.steigerung = 0,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Art der Bewegung (z.B. 'zu Fuß', 'Schwimmen', 'Fliegen').
  final String art;

  /// Geschwindigkeitswert.
  final int wert;

  /// Gekaufte GS-Steigerungen eines Vertrauten (Komplexitaet F, WdZ S. 125).
  final int steigerung;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'art',
    'wert',
    'steigerung',
  };

  HeroCompanionSpeed copyWith({
    String? art,
    int? wert,
    int? steigerung,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroCompanionSpeed(
      art: art ?? this.art,
      wert: wert ?? this.wert,
      steigerung: steigerung ?? this.steigerung,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  Map<String, dynamic> toJson() => mitUnbekanntenFeldern(<String, dynamic>{
    'art': art,
    'wert': wert,
    if (steigerung != 0) 'steigerung': steigerung,
  }, unbekannteFelder);

  static HeroCompanionSpeed fromJson(Map<String, dynamic> json) {
    return HeroCompanionSpeed(
      art: (json['art'] as String?) ?? '',
      wert: (json['wert'] as num?)?.toInt() ?? 0,
      steigerung: (json['steigerung'] as num?)?.toInt() ?? 0,
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroCompanionSpeed &&
          art == other.art &&
          wert == other.wert &&
          steigerung == other.steigerung &&
          unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder);

  @override
  int get hashCode => Object.hash(
    art,
    wert,
    steigerung,
    unbekannteFelderHash(unbekannteFelder),
  );
}
