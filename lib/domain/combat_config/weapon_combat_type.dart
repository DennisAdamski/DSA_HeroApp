/// Klassifiziert einen Waffenslot als Nah- oder Fernkampfwaffe.
enum WeaponCombatType {
  /// Klassische Nahkampfwaffe mit AT/PA-Werten.
  melee,

  /// Fernkampfwaffe mit FK-Wert, Distanzstufen und Geschossen.
  ranged,
}

/// Liest einen [WeaponCombatType] tolerant aus persistierten Strings.
WeaponCombatType weaponCombatTypeFromJson(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'ranged':
    case 'fernkampf':
      return WeaponCombatType.ranged;
    case 'melee':
    case 'nahkampf':
    default:
      return WeaponCombatType.melee;
  }
}

/// Serialisiert einen [WeaponCombatType] stabil als JSON-String.
String weaponCombatTypeToJson(WeaponCombatType value) {
  return switch (value) {
    WeaponCombatType.melee => 'melee',
    WeaponCombatType.ranged => 'ranged',
  };
}
