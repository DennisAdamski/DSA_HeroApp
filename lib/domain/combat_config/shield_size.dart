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
  return shieldSizeErkennen(value) ?? ShieldSize.small;
}

/// Erkennt eine [ShieldSize]; unbekannte Werte ergeben `null`.
ShieldSize? shieldSizeErkennen(Object? value) {
  if (value is! String) return null;
  switch (value.trim()) {
    case 'small':
      return ShieldSize.small;
    case 'large':
      return ShieldSize.large;
    case 'veryLarge':
      return ShieldSize.veryLarge;
    default:
      return null;
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
