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

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  CombatManualMods copyWith({
    int? iniMod,
    int? ausweichenMod,
    int? atMod,
    int? paMod,
    int? iniWurf,
  }) {
    return CombatManualMods(
      iniMod: iniMod ?? this.iniMod,
      ausweichenMod: ausweichenMod ?? this.ausweichenMod,
      atMod: atMod ?? this.atMod,
      paMod: paMod ?? this.paMod,
      iniWurf: iniWurf ?? this.iniWurf,
    );
  }

  /// Serialisiert die manuellen Modifikatoren zu einem JSON-kompatiblen Map.
  Map<String, dynamic> toJson() {
    return {
      'iniMod': iniMod,
      'ausweichenMod': ausweichenMod,
      'atMod': atMod,
      'paMod': paMod,
      'iniWurf': iniWurf,
    };
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
    );
  }
}
