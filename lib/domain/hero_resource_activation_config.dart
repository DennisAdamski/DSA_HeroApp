import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Persistierte Aktivierungs-Overrides fuer magische und goettliche Ressourcen.
///
/// `null` bedeutet, dass der Wert automatisch aus den Herkunfts- und
/// Vorteil-Modifikatoren abgeleitet wird.
class HeroResourceActivationConfig {
  /// Erstellt die Aktivierungs-Konfiguration eines Helden.
  const HeroResourceActivationConfig({
    this.magicEnabledOverride,
    this.divineEnabledOverride,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Manueller Override fuer Magie.
  final bool? magicEnabledOverride;

  /// Manueller Override fuer goettliche Ressourcen.
  final bool? divineEnabledOverride;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest — einschliesslich der nur bedingt
  /// geschriebenen; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'magicEnabledOverride',
    'divineEnabledOverride',
  };

  /// Immutable Update fuer einzelne Override-Werte.
  HeroResourceActivationConfig copyWith({
    Object? magicEnabledOverride = _keepValue,
    Object? divineEnabledOverride = _keepValue,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroResourceActivationConfig(
      magicEnabledOverride: identical(magicEnabledOverride, _keepValue)
          ? this.magicEnabledOverride
          : magicEnabledOverride as bool?,
      divineEnabledOverride: identical(divineEnabledOverride, _keepValue)
          ? this.divineEnabledOverride
          : divineEnabledOverride as bool?,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert nur gesetzte Override-Werte.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      if (magicEnabledOverride != null)
        'magicEnabledOverride': magicEnabledOverride,
      if (divineEnabledOverride != null)
        'divineEnabledOverride': divineEnabledOverride,
    }, unbekannteFelder);
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
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}

const Object _keepValue = Object();
