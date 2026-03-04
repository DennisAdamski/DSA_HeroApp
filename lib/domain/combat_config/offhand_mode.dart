/// Beschreibt, welches Objekt die Nebenhand des Helden haelt.
enum OffhandMode {
  /// Keine Nebenhand-Ausruestung aktiv.
  none,

  /// Schild in der Nebenhand.
  shield,

  /// Parierwaffe in der Nebenhand.
  parryWeapon,

  /// Linkhaendiger Modus (zweite Waffe in der Nebenhand).
  linkhand,
}

/// Deserialisiert einen JSON-String zu einem [OffhandMode].
///
/// Gibt [OffhandMode.none] zurueck, wenn der Wert unbekannt ist.
OffhandMode offhandModeFromJson(String value) {
  switch (value.trim()) {
    case 'shield':
      return OffhandMode.shield;
    case 'parryWeapon':
      return OffhandMode.parryWeapon;
    case 'linkhand':
      return OffhandMode.linkhand;
    default:
      return OffhandMode.none;
  }
}

/// Serialisiert einen [OffhandMode] zu einem JSON-String.
String offhandModeToJson(OffhandMode value) {
  switch (value) {
    case OffhandMode.none:
      return 'none';
    case OffhandMode.shield:
      return 'shield';
    case OffhandMode.parryWeapon:
      return 'parryWeapon';
    case OffhandMode.linkhand:
      return 'linkhand';
  }
}
