/// Konfiguriert eine einzelne Hauptwaffenposition des Helden.
///
/// Unveraenderlich; Aktualisierungen erfolgen ueber [copyWith].
/// Serialisierung ist abwaertskompatibel (Schema v4).
/// Die Wuerfelseiten sind im aktuellen Hausregel-Fluss fest auf W6 gesetzt.
class MainWeaponSlot {
  const MainWeaponSlot({
    this.name = '',
    this.talentId = '',
    this.weaponType = '',
    this.distanceClass = '',
    this.kkBase = 0,
    this.kkThreshold = 1,
    this.breakFactor = 0,
    this.tpDiceCount = 1,
    this.tpDiceSides = 6,
    this.tpFlat = 0,
    this.wmAt = 0,
    this.wmPa = 0,
    this.iniMod = 0,
    this.beTalentMod = 0,
    this.isOneHanded = true,
    this.isArtifact = false,
    this.artifactDescription = '',
  });

  /// Anzeigename der Waffe.
  final String name;

  /// ID des zugeordneten Kampftalents.
  final String talentId;

  /// Waffenart (z. B. 'Schwert', 'Axt').
  final String weaponType;

  /// Entfernungsklasse der Waffe.
  final String distanceClass;

  /// KK-Basiswert fuer TP-Bonus-Berechnung.
  final int kkBase;

  /// KK-Schwellenwert fuer TP-Stufen.
  final int kkThreshold;

  /// Bruchfaktor der Waffe.
  final int breakFactor;

  /// Anzahl der TP-Wuerfel.
  final int tpDiceCount;

  /// Wuerfelseiten (im Hausregel-Fluss immer 6).
  final int tpDiceSides;

  /// Flacher TP-Bonus (ohne Wuerfel).
  final int tpFlat;

  /// Waffenmodifikator auf Attacke.
  final int wmAt;

  /// Waffenmodifikator auf Parade.
  final int wmPa;

  /// Initiativmodifikator der Waffe.
  final int iniMod;

  /// BE-Modifikator fuer Talentproben mit dieser Waffe.
  final int beTalentMod;

  /// Gibt an, ob die Waffe einhaendig gefuehrt wird.
  final bool isOneHanded;

  /// Kennzeichnet die Waffe als Artefakt.
  final bool isArtifact;

  /// Freitext-Beschreibung fuer das Artefakt.
  final String artifactDescription;

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  ///
  /// Hinweis: [tpDiceSides] ist immer 6 und wird ignoriert.
  MainWeaponSlot copyWith({
    String? name,
    String? talentId,
    String? weaponType,
    String? distanceClass,
    int? kkBase,
    int? kkThreshold,
    int? breakFactor,
    int? tpDiceCount,
    int? tpDiceSides,
    int? tpFlat,
    int? wmAt,
    int? wmPa,
    int? iniMod,
    int? beTalentMod,
    bool? isOneHanded,
    bool? isArtifact,
    String? artifactDescription,
  }) {
    return MainWeaponSlot(
      name: name ?? this.name,
      talentId: talentId ?? this.talentId,
      weaponType: weaponType ?? this.weaponType,
      distanceClass: distanceClass ?? this.distanceClass,
      kkBase: kkBase ?? this.kkBase,
      kkThreshold: kkThreshold ?? this.kkThreshold,
      breakFactor: breakFactor ?? this.breakFactor,
      tpDiceCount: tpDiceCount ?? this.tpDiceCount,
      // W6 ist im aktuellen Hausregel-Waffenfluss fest.
      tpDiceSides: 6,
      tpFlat: tpFlat ?? this.tpFlat,
      wmAt: wmAt ?? this.wmAt,
      wmPa: wmPa ?? this.wmPa,
      iniMod: iniMod ?? this.iniMod,
      beTalentMod: beTalentMod ?? this.beTalentMod,
      isOneHanded: isOneHanded ?? this.isOneHanded,
      isArtifact: isArtifact ?? this.isArtifact,
      artifactDescription: artifactDescription ?? this.artifactDescription,
    );
  }

  /// Serialisiert den Slot zu einem JSON-kompatiblen Map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'talentId': talentId,
      'weaponType': weaponType,
      'distanceClass': distanceClass,
      'kkBase': kkBase,
      'kkThreshold': kkThreshold,
      'breakFactor': breakFactor,
      'tpDiceCount': tpDiceCount,
      // Als W6 persistiert fuer Schema-Kompatibilitaet.
      'tpDiceSides': 6,
      'tpFlat': tpFlat,
      'wmAt': wmAt,
      'wmPa': wmPa,
      'iniMod': iniMod,
      'beTalentMod': beTalentMod,
      'isOneHanded': isOneHanded,
      'isArtifact': isArtifact,
      'artifactDescription': artifactDescription,
    };
  }

  /// Deserialisiert einen [MainWeaponSlot] aus einem JSON-Map.
  ///
  /// Tolerant bei fehlenden Feldern (Standardwerte werden gesetzt).
  static MainWeaponSlot fromJson(Map<String, dynamic> json) {
    int getInt(String key, int fallback) =>
        (json[key] as num?)?.toInt() ?? fallback;
    String getString(String key) => (json[key] as String?) ?? '';
    return MainWeaponSlot(
      name: getString('name'),
      talentId: getString('talentId'),
      weaponType: getString('weaponType'),
      distanceClass: getString('distanceClass'),
      kkBase: getInt('kkBase', 0),
      kkThreshold: getInt('kkThreshold', 1) < 1 ? 1 : getInt('kkThreshold', 1),
      breakFactor: getInt('breakFactor', 0),
      tpDiceCount: getInt('tpDiceCount', 1),
      tpDiceSides: 6,
      tpFlat: getInt('tpFlat', 0),
      wmAt: getInt('wmAt', 0),
      wmPa: getInt('wmPa', 0),
      iniMod: getInt('iniMod', 0),
      beTalentMod: getInt('beTalentMod', 0),
      isOneHanded: (json['isOneHanded'] as bool?) ?? true,
      isArtifact: (json['isArtifact'] as bool?) ?? false,
      artifactDescription: getString('artifactDescription'),
    );
  }
}
