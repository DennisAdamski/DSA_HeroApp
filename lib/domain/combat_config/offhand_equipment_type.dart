/// Klassifiziert kampfrelevantes Nebenhand-Equipment.
enum OffhandEquipmentType {
  /// Parierwaffe in der Nebenhand.
  parryWeapon,

  /// Schild in der Nebenhand.
  shield,
}

/// Deserialisiert einen JSON-String zu einem [OffhandEquipmentType].
OffhandEquipmentType offhandEquipmentTypeFromJson(String value) {
  switch (value.trim()) {
    case 'shield':
      return OffhandEquipmentType.shield;
    default:
      return OffhandEquipmentType.parryWeapon;
  }
}

/// Serialisiert einen [OffhandEquipmentType] zu einem JSON-String.
String offhandEquipmentTypeToJson(OffhandEquipmentType value) {
  switch (value) {
    case OffhandEquipmentType.parryWeapon:
      return 'parryWeapon';
    case OffhandEquipmentType.shield:
      return 'shield';
  }
}
