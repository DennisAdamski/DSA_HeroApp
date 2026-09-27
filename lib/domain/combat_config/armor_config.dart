import 'package:dsa_heldenverwaltung/domain/combat_config/armor_piece.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Fasst alle Ruestungsstuecke und die globale Ruestungsgewoehnung zusammen.
///
/// Unveraenderlich; Aktualisierungen erfolgen ueber [copyWith].
/// Die Liste [pieces] ist immer unveraenderlich.
class ArmorConfig {
  const ArmorConfig({
    this.pieces = const <ArmorPiece>[],
    this.globalArmorTrainingLevel = 0,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Alle Ruestungsstuecke des Helden (ggf. leer).
  final List<ArmorPiece> pieces;

  /// Globale Ruestungsgewoehnung: erlaubte Werte sind 0, 1, 2 oder 3.
  final int globalArmorTrainingLevel;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'pieces',
    'globalArmorTrainingLevel',
  };

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  ArmorConfig copyWith({
    List<ArmorPiece>? pieces,
    int? globalArmorTrainingLevel,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return ArmorConfig(
      pieces: List<ArmorPiece>.unmodifiable(pieces ?? this.pieces),
      globalArmorTrainingLevel:
          globalArmorTrainingLevel ?? this.globalArmorTrainingLevel,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert die Ruestungskonfiguration zu einem JSON-kompatiblen Map.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'pieces': pieces.map((entry) => entry.toJson()).toList(growable: false),
      'globalArmorTrainingLevel': globalArmorTrainingLevel,
    }, unbekannteFelder);
  }

  /// Deserialisiert eine [ArmorConfig] aus einem JSON-Map.
  ///
  /// Normalisiert [globalArmorTrainingLevel] auf erlaubte Werte (0, 1, 2, 3).
  /// Tolerant bei fehlenden Feldern.
  static ArmorConfig fromJson(Map<String, dynamic> json) {
    final rawPieces = (json['pieces'] as List?) ?? const <dynamic>[];
    final parsedPieces = rawPieces
        .whereType<Map>()
        .map((entry) => ArmorPiece.fromJson(entry.cast<String, dynamic>()))
        .toList(growable: false);
    var normalizedTraining =
        (json['globalArmorTrainingLevel'] as num?)?.toInt() ?? 0;
    if (normalizedTraining != 0 &&
        normalizedTraining != 1 &&
        normalizedTraining != 2 &&
        normalizedTraining != 3) {
      normalizedTraining = 0;
    }
    return ArmorConfig(
      pieces: parsedPieces,
      globalArmorTrainingLevel: normalizedTraining,
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}
