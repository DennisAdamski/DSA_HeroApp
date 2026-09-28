/// Klassifiziert kampfrelevantes Nebenhand-Equipment.
enum OffhandEquipmentType {
  /// Parierwaffe in der Nebenhand.
  parryWeapon,

  /// Schild in der Nebenhand.
  shield,
}

/// Deserialisiert einen JSON-String zu einem [OffhandEquipmentType].
OffhandEquipmentType offhandEquipmentTypeFromJson(String value) {
  return offhandEquipmentTypeErkennen(value) ??
      OffhandEquipmentType.parryWeapon;
}

/// Erkennt einen [OffhandEquipmentType]; unbekannte Werte ergeben `null`.
OffhandEquipmentType? offhandEquipmentTypeErkennen(Object? value) {
  if (value is! String) return null;
  switch (value.trim()) {
    case 'shield':
      return OffhandEquipmentType.shield;
    case 'parryWeapon':
      return OffhandEquipmentType.parryWeapon;
    default:
      return null;
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
