import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Manuell eingegebene Kampfmodifikatoren fuer den laufenden Kampf.
///
/// Wird vom Spieler zur Laufzeit gesetzt, z. B. fuer situative AT/PA-Boni
/// oder den Ergebnis des Ini-Wurfs.
/// Unveraenderlich; Aktualisierungen erfolgen ueber [copyWith].
class CombatManualMods {
  const CombatManualMods({
    this.iniMod = 0,
    this.ausweichenMod = 0,
    this.atMod = 0,
    this.paMod = 0,
    this.iniWurf = 0,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Manueller Initiativmodifikator.
  final int iniMod;

  /// Manueller Ausweichen-Modifikator.
  final int ausweichenMod;

  /// Manueller Attacke-Modifikator.
  final int atMod;

  /// Manueller Parade-Modifikator.
  final int paMod;

  /// Ergebnis des physischen W6/2W6-Wurfs zu Kampfrundenbeginn.
  final int iniWurf;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest — einschliesslich des
  /// Altschluessels `fkMod`, der beim Laden in [atMod] aufgeht.
  static const Set<String> jsonSchluessel = <String>{
    'iniMod',
    'ausweichenMod',
    'atMod',
    'paMod',
    'iniWurf',
    'fkMod',
  };

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  CombatManualMods copyWith({
    int? iniMod,
    int? ausweichenMod,
    int? atMod,
    int? paMod,
    int? iniWurf,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return CombatManualMods(
      iniMod: iniMod ?? this.iniMod,
      ausweichenMod: ausweichenMod ?? this.ausweichenMod,
      atMod: atMod ?? this.atMod,
      paMod: paMod ?? this.paMod,
      iniWurf: iniWurf ?? this.iniWurf,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert die manuellen Modifikatoren zu einem JSON-kompatiblen Map.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'iniMod': iniMod,
      'ausweichenMod': ausweichenMod,
      'atMod': atMod,
      'paMod': paMod,
      'iniWurf': iniWurf,
    }, unbekannteFelder);
  }

  /// Deserialisiert [CombatManualMods] aus einem JSON-Map.
  ///
  /// Tolerant bei fehlenden Feldern (Standardwert 0).
  static CombatManualMods fromJson(Map<String, dynamic> json) {
    int getInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    final hasAtMod = json.containsKey('atMod') && json['atMod'] != null;
    return CombatManualMods(
      iniMod: getInt('iniMod'),
      ausweichenMod: getInt('ausweichenMod'),
      atMod: hasAtMod ? getInt('atMod') : getInt('fkMod'),
      paMod: getInt('paMod'),
      iniWurf: getInt('iniWurf'),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}
