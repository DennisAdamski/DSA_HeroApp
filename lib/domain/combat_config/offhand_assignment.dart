/// Beschreibt, welcher Inventareintrag aktuell in der Nebenhand liegt.
class OffhandAssignment {
  const OffhandAssignment({
    this.weaponIndex = -1,
    this.equipmentIndex = -1,
  });

  /// Index einer Nebenhand-Waffe im Waffeninventar oder `-1`.
  final int weaponIndex;

  /// Index eines Schild-/Parierwaffen-Eintrags oder `-1`.
  final int equipmentIndex;

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
  }) {
    return OffhandAssignment(
      weaponIndex: weaponIndex ?? this.weaponIndex,
      equipmentIndex: equipmentIndex ?? this.equipmentIndex,
    );
  }

  /// Serialisiert die Auswahl zu einem JSON-kompatiblen Map.
  Map<String, dynamic> toJson() {
    return {
      'weaponIndex': weaponIndex,
      'equipmentIndex': equipmentIndex,
    };
  }

  /// Deserialisiert eine Auswahl aus einem JSON-Map.
  static OffhandAssignment fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? -1;
    return OffhandAssignment(
      weaponIndex: getInt('weaponIndex'),
      equipmentIndex: getInt('equipmentIndex'),
    );
  }
}
