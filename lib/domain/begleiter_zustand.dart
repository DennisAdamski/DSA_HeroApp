import 'package:dsa_heldenverwaltung/domain/copy_with_sentinel.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Laufende Werte eines Begleiters (Vertraute, Reittiere, sonstige).
///
/// Liegt im `HeroState` unter der Begleiter-ID (`HeroState.begleiterZustaende`).
/// Ein Feld ist `null`, solange der Wert dem wirksamen Maximum entspricht
/// („voll“); so bleibt ein voller Begleiter ohne Eintrag, und ein Anstieg des
/// Maximums (Steigerung, Ausbildung) zieht den vollen Wert mit. Wunden kommen
/// später additiv als weitere optionale Felder dazu.
class BegleiterZustand {
  /// Erstellt einen Zustand; `null` heißt „voll“.
  const BegleiterZustand({
    this.currentLep,
    this.currentAsp,
    this.currentAup,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Aktuelle Lebenspunkte; `null` entspricht dem wirksamen Maximum.
  final int? currentLep;

  /// Aktuelle Astralpunkte; `null` entspricht dem wirksamen Maximum.
  final int? currentAsp;

  /// Aktuelle Ausdauer; `null` entspricht dem wirksamen Maximum.
  final int? currentAup;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten.
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schlüssel, die [fromJson] liest.
  static const Set<String> jsonSchluessel = <String>{
    'currentLep',
    'currentAsp',
    'currentAup',
  };

  /// `true`, wenn kein Wert und kein unbekanntes Feld gesetzt ist.
  bool get istLeer =>
      currentLep == null &&
      currentAsp == null &&
      currentAup == null &&
      unbekannteFelder.isEmpty;

  /// Kopie mit geänderten Feldern; `null` übergeben setzt auf „voll“.
  BegleiterZustand copyWith({
    Object? currentLep = keepFieldValue,
    Object? currentAsp = keepFieldValue,
    Object? currentAup = keepFieldValue,
  }) {
    return BegleiterZustand(
      currentLep: identical(currentLep, keepFieldValue)
          ? this.currentLep
          : currentLep as int?,
      currentAsp: identical(currentAsp, keepFieldValue)
          ? this.currentAsp
          : currentAsp as int?,
      currentAup: identical(currentAup, keepFieldValue)
          ? this.currentAup
          : currentAup as int?,
      unbekannteFelder: unbekannteFelder,
    );
  }

  /// Serialisiert nur belegte Werte.
  Map<String, dynamic> toJson() => mitUnbekanntenFeldern(<String, dynamic>{
    'currentLep': ?currentLep,
    'currentAsp': ?currentAsp,
    'currentAup': ?currentAup,
  }, unbekannteFelder);

  /// Liest einen Zustand; fehlende Werte bleiben `null`.
  static BegleiterZustand fromJson(Map<String, dynamic> json) {
    int? zahl(String schluessel) => (json[schluessel] as num?)?.toInt();
    return BegleiterZustand(
      currentLep: zahl('currentLep'),
      currentAsp: zahl('currentAsp'),
      currentAup: zahl('currentAup'),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BegleiterZustand &&
          currentLep == other.currentLep &&
          currentAsp == other.currentAsp &&
          currentAup == other.currentAup &&
          unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder);

  @override
  int get hashCode => Object.hash(
    currentLep,
    currentAsp,
    currentAup,
    unbekannteFelderHash(unbekannteFelder),
  );
}
