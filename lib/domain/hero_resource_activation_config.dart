/// Persistierte Aktivierungs-Overrides fuer magische und goettliche Ressourcen.
///
/// `null` bedeutet, dass der Wert automatisch aus den Herkunfts- und
/// Vorteil-Modifikatoren abgeleitet wird.
class HeroResourceActivationConfig {
  /// Erstellt die Aktivierungs-Konfiguration eines Helden.
  const HeroResourceActivationConfig({
    this.magicEnabledOverride,
    this.divineEnabledOverride,
  });

  /// Manueller Override fuer Magie.
  final bool? magicEnabledOverride;

  /// Manueller Override fuer goettliche Ressourcen.
  final bool? divineEnabledOverride;

  /// Immutable Update fuer einzelne Override-Werte.
  HeroResourceActivationConfig copyWith({
    Object? magicEnabledOverride = _keepValue,
    Object? divineEnabledOverride = _keepValue,
  }) {
    return HeroResourceActivationConfig(
      magicEnabledOverride: identical(magicEnabledOverride, _keepValue)
          ? this.magicEnabledOverride
          : magicEnabledOverride as bool?,
      divineEnabledOverride: identical(divineEnabledOverride, _keepValue)
          ? this.divineEnabledOverride
          : divineEnabledOverride as bool?,
    );
  }

  /// Serialisiert nur gesetzte Override-Werte.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (magicEnabledOverride != null)
        'magicEnabledOverride': magicEnabledOverride,
      if (divineEnabledOverride != null)
        'divineEnabledOverride': divineEnabledOverride,
    };
  }

  /// Laedt die Konfiguration rueckwaertskompatibel aus JSON.
  static HeroResourceActivationConfig fromJson(Map<String, dynamic> json) {
    bool? readNullableBool(String key) {
      final value = json[key];
      return value is bool ? value : null;
    }

    return HeroResourceActivationConfig(
      magicEnabledOverride: readNullableBool('magicEnabledOverride'),
      divineEnabledOverride: readNullableBool('divineEnabledOverride'),
    );
  }
}

const Object _keepValue = Object();
