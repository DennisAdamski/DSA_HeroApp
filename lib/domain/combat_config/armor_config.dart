import 'package:dsa_heldenverwaltung/domain/combat_config/armor_piece.dart';

/// Fasst alle Ruestungsstuecke und die globale Ruestungsgewoehnung zusammen.
///
/// Unveraenderlich; Aktualisierungen erfolgen ueber [copyWith].
/// Die Liste [pieces] ist immer unveraenderlich.
class ArmorConfig {
  const ArmorConfig({
    this.pieces = const <ArmorPiece>[],
    this.globalArmorTrainingLevel = 0,
  });

  /// Alle Ruestungsstuecke des Helden (ggf. leer).
  final List<ArmorPiece> pieces;

  /// Globale Ruestungsgewoehnung: erlaubte Werte sind 0, 2 oder 3.
  final int globalArmorTrainingLevel;

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  ArmorConfig copyWith({
    List<ArmorPiece>? pieces,
    int? globalArmorTrainingLevel,
  }) {
    return ArmorConfig(
      pieces: List<ArmorPiece>.unmodifiable(pieces ?? this.pieces),
      globalArmorTrainingLevel:
          globalArmorTrainingLevel ?? this.globalArmorTrainingLevel,
    );
  }

  /// Serialisiert die Ruestungskonfiguration zu einem JSON-kompatiblen Map.
  Map<String, dynamic> toJson() {
    return {
      'pieces': pieces.map((entry) => entry.toJson()).toList(growable: false),
      'globalArmorTrainingLevel': globalArmorTrainingLevel,
    };
  }

  /// Deserialisiert eine [ArmorConfig] aus einem JSON-Map.
  ///
  /// Normalisiert [globalArmorTrainingLevel] auf erlaubte Werte (0, 2, 3).
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
        normalizedTraining != 2 &&
        normalizedTraining != 3) {
      normalizedTraining = 0;
    }
    return ArmorConfig(
      pieces: parsedPieces,
      globalArmorTrainingLevel: normalizedTraining,
    );
  }
}
