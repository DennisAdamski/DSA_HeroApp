import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Beschreibt, welcher Inventareintrag aktuell in der Nebenhand liegt.
class OffhandAssignment {
  const OffhandAssignment({
    this.weaponIndex = -1,
    this.equipmentIndex = -1,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Index einer Nebenhand-Waffe im Waffeninventar oder `-1`.
  final int weaponIndex;

  /// Index eines Schild-/Parierwaffen-Eintrags oder `-1`.
  final int equipmentIndex;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'weaponIndex',
    'equipmentIndex',
  };

  /// Gibt an, ob aktuell kein Nebenhand-Eintrag aktiv ist.
  bool get isNone => weaponIndex < 0 && equipmentIndex < 0;

  /// Gibt an, ob die Nebenhand auf eine Waffe verweist.
  bool get usesWeapon => weaponIndex >= 0;

  /// Gibt an, ob die Nebenhand auf Schild-/Parierwaffen-Equipment verweist.
  bool get usesEquipment => equipmentIndex >= 0;

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  OffhandAssignment copyWith({
    int? weaponIndex,
    int? equipmentIndex,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return OffhandAssignment(
      weaponIndex: weaponIndex ?? this.weaponIndex,
      equipmentIndex: equipmentIndex ?? this.equipmentIndex,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert die Auswahl zu einem JSON-kompatiblen Map.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'weaponIndex': weaponIndex,
      'equipmentIndex': equipmentIndex,
    }, unbekannteFelder);
  }

  /// Deserialisiert eine Auswahl aus einem JSON-Map.
  static OffhandAssignment fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? -1;
    return OffhandAssignment(
      weaponIndex: getInt('weaponIndex'),
      equipmentIndex: getInt('equipmentIndex'),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}
