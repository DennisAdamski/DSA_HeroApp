/// Beschreibt die Groesse eines Schilds.
enum ShieldSize {
  /// Kleiner Schild.
  small,

  /// Grosser Schild.
  large,

  /// Sehr grosser Schild.
  veryLarge,
}

/// Deserialisiert einen JSON-String zu einer [ShieldSize].
ShieldSize shieldSizeFromJson(String value) {
  switch (value.trim()) {
    case 'large':
      return ShieldSize.large;
    case 'veryLarge':
      return ShieldSize.veryLarge;
    default:
      return ShieldSize.small;
  }
}

/// Serialisiert eine [ShieldSize] zu einem JSON-String.
String shieldSizeToJson(ShieldSize value) {
  switch (value) {
    case ShieldSize.small:
      return 'small';
    case ShieldSize.large:
      return 'large';
    case ShieldSize.veryLarge:
      return 'veryLarge';
  }
}
