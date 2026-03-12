/// Typ eines Waffenmeister-Bonus im 15-Punkte-Baukasten.
enum WaffenmeisterBonusType {
  /// Manoever-Erschwernis-Verminderung (1 Punkt pro -1).
  maneuverReduction,

  /// INI-Bonus (3 Punkte pro +1, max +2).
  iniBonus,

  /// TP/KK -1/-1 (2 Punkte, nur Dolche/Fechtwaffen, einmalig).
  tpKkReduction,

  /// AT-WM Bonus (5 Punkte pro +1, max +2).
  atWmBonus,

  /// PA-WM Bonus (5 Punkte pro +1, max +2).
  paWmBonus,

  /// Ausfall-Erstangriff-Malus entfernt (2 Punkte, einmalig).
  ausfallPenaltyRemoval,

  /// Zusaetzliches Manoever erlaubt (5 Punkte, eines erlaubt).
  additionalManeuver,

  /// Fernkampf-Reichweite +10% (1 Punkt, max 2).
  rangeIncrease,

  /// Gezielter Schuss Erschwernis -1 (2 Punkte, einmalig).
  gezielterSchussReduction,

  /// Ladezeit halbiert fuer Armbrueste (5 Punkte, einmalig).
  reloadTimeHalved,

  /// Besonderer/individueller Vorteil (2-5 Punkte, Freitext).
  customAdvantage,
}

/// JSON-Schluessel fuer [WaffenmeisterBonusType].
String waffenmeisterBonusTypeToJson(WaffenmeisterBonusType type) {
  return type.name;
}

/// Deserialisiert [WaffenmeisterBonusType] aus einem JSON-String.
WaffenmeisterBonusType waffenmeisterBonusTypeFromJson(String value) {
  for (final type in WaffenmeisterBonusType.values) {
    if (type.name == value) return type;
  }
  return WaffenmeisterBonusType.customAdvantage;
}

/// Ein einzelner Bonus-Eintrag im Waffenmeister-Baukasten.
///
/// Unveraenderlich; Aktualisierungen erfolgen ueber [copyWith].
class WaffenmeisterBonus {
  const WaffenmeisterBonus({
    this.type = WaffenmeisterBonusType.customAdvantage,
    this.value = 0,
    this.targetManeuver = '',
    this.description = '',
    this.customPointCost = 2,
  });

  /// Typ des Bonus.
  final WaffenmeisterBonusType type;

  /// Bonus-Wert (z.B. 2 bei Manoever -2, oder 1 bei INI +1).
  final int value;

  /// Manoever-ID (bei [maneuverReduction] und [additionalManeuver]).
  final String targetManeuver;

  /// Freitext-Beschreibung (vor allem bei [customAdvantage]).
  final String description;

  /// Manuell gesetzte Punktekosten (nur bei [customAdvantage], 2-5).
  final int customPointCost;

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  WaffenmeisterBonus copyWith({
    WaffenmeisterBonusType? type,
    int? value,
    String? targetManeuver,
    String? description,
    int? customPointCost,
  }) {
    return WaffenmeisterBonus(
      type: type ?? this.type,
      value: value ?? this.value,
      targetManeuver: targetManeuver ?? this.targetManeuver,
      description: description ?? this.description,
      customPointCost: customPointCost ?? this.customPointCost,
    );
  }

  /// Serialisiert den Bonus zu einem JSON-kompatiblen Map.
  Map<String, dynamic> toJson() {
    return {
      'type': waffenmeisterBonusTypeToJson(type),
      'value': value,
      'targetManeuver': targetManeuver,
      'description': description,
      'customPointCost': customPointCost,
    };
  }

  /// Deserialisiert einen [WaffenmeisterBonus] aus einem JSON-Map.
  ///
  /// Tolerant bei fehlenden Feldern (Standardwerte werden gesetzt).
  static WaffenmeisterBonus fromJson(Map<String, dynamic> json) {
    return WaffenmeisterBonus(
      type: waffenmeisterBonusTypeFromJson(
        (json['type'] as String?) ?? '',
      ),
      value: (json['value'] as num?)?.toInt() ?? 0,
      targetManeuver: (json['targetManeuver'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      customPointCost: (json['customPointCost'] as num?)?.toInt() ?? 2,
    );
  }
}

/// Konfiguration einer Waffenmeisterschaft fuer eine bestimmte Waffenart.
///
/// Speichert die gewaehlten Boni aus dem 15-Punkte-Baukasten,
/// die Waffenart und die Eigenschafts-Anforderungen.
/// Unveraenderlich; Aktualisierungen erfolgen ueber [copyWith].
class WaffenmeisterConfig {
  const WaffenmeisterConfig({
    this.talentId = '',
    this.weaponType = '',
    this.isSchild = false,
    this.bonuses = const <WaffenmeisterBonus>[],
    this.additionalWeaponTypes = const <String>[],
    this.styleName = '',
    this.masterName = '',
    this.requiredAttribute1 = 'GE',
    this.requiredAttribute1Value = 13,
    this.requiredAttribute2 = 'KK',
    this.requiredAttribute2Value = 13,
  });

  /// Kampftalent-ID (z.B. "tal_schwerter").
  final String talentId;

  /// Konkrete Waffenart (z.B. "Langschwert").
  final String weaponType;

  /// Sonderfall Schild-Waffenmeister (spaetere Implementierung).
  final bool isSchild;

  /// Verteilte Boni aus dem Baukasten.
  final List<WaffenmeisterBonus> bonuses;

  /// Weitere aehnliche Waffen (max 2, kostet 2 automatische Punkte).
  final List<String> additionalWeaponTypes;

  /// Name des Meisterstils (Flavor).
  final String styleName;

  /// Name des Lehrmeisters (Flavor).
  final String masterName;

  /// Erste geforderte Eigenschaft (z.B. "GE").
  final String requiredAttribute1;

  /// Mindestwert der ersten Eigenschaft.
  final int requiredAttribute1Value;

  /// Zweite geforderte Eigenschaft (z.B. "KK").
  final String requiredAttribute2;

  /// Mindestwert der zweiten Eigenschaft.
  final int requiredAttribute2Value;

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  WaffenmeisterConfig copyWith({
    String? talentId,
    String? weaponType,
    bool? isSchild,
    List<WaffenmeisterBonus>? bonuses,
    List<String>? additionalWeaponTypes,
    String? styleName,
    String? masterName,
    String? requiredAttribute1,
    int? requiredAttribute1Value,
    String? requiredAttribute2,
    int? requiredAttribute2Value,
  }) {
    return WaffenmeisterConfig(
      talentId: talentId ?? this.talentId,
      weaponType: weaponType ?? this.weaponType,
      isSchild: isSchild ?? this.isSchild,
      bonuses: bonuses != null
          ? List<WaffenmeisterBonus>.unmodifiable(bonuses)
          : this.bonuses,
      additionalWeaponTypes: additionalWeaponTypes != null
          ? List<String>.unmodifiable(additionalWeaponTypes)
          : this.additionalWeaponTypes,
      styleName: styleName ?? this.styleName,
      masterName: masterName ?? this.masterName,
      requiredAttribute1: requiredAttribute1 ?? this.requiredAttribute1,
      requiredAttribute1Value:
          requiredAttribute1Value ?? this.requiredAttribute1Value,
      requiredAttribute2: requiredAttribute2 ?? this.requiredAttribute2,
      requiredAttribute2Value:
          requiredAttribute2Value ?? this.requiredAttribute2Value,
    );
  }

  /// Serialisiert die Waffenmeisterschaft zu einem JSON-kompatiblen Map.
  Map<String, dynamic> toJson() {
    return {
      'talentId': talentId,
      'weaponType': weaponType,
      'isSchild': isSchild,
      'bonuses': bonuses
          .map((bonus) => bonus.toJson())
          .toList(growable: false),
      'additionalWeaponTypes': List<String>.from(additionalWeaponTypes),
      'styleName': styleName,
      'masterName': masterName,
      'requiredAttribute1': requiredAttribute1,
      'requiredAttribute1Value': requiredAttribute1Value,
      'requiredAttribute2': requiredAttribute2,
      'requiredAttribute2Value': requiredAttribute2Value,
    };
  }

  /// Deserialisiert eine [WaffenmeisterConfig] aus einem JSON-Map.
  ///
  /// Tolerant bei fehlenden Feldern (Standardwerte werden gesetzt).
  static WaffenmeisterConfig fromJson(Map<String, dynamic> json) {
    final rawBonuses = (json['bonuses'] as List?) ?? const <dynamic>[];
    final parsedBonuses = rawBonuses
        .whereType<Map>()
        .map((entry) => WaffenmeisterBonus.fromJson(
              entry.cast<String, dynamic>(),
            ))
        .toList(growable: false);
    final rawAdditional =
        (json['additionalWeaponTypes'] as List?) ?? const <dynamic>[];
    final parsedAdditional = rawAdditional
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList(growable: false);
    return WaffenmeisterConfig(
      talentId: (json['talentId'] as String?) ?? '',
      weaponType: (json['weaponType'] as String?) ?? '',
      isSchild: (json['isSchild'] as bool?) ?? false,
      bonuses: List<WaffenmeisterBonus>.unmodifiable(parsedBonuses),
      additionalWeaponTypes: List<String>.unmodifiable(parsedAdditional),
      styleName: (json['styleName'] as String?) ?? '',
      masterName: (json['masterName'] as String?) ?? '',
      requiredAttribute1: (json['requiredAttribute1'] as String?) ?? 'GE',
      requiredAttribute1Value:
          (json['requiredAttribute1Value'] as num?)?.toInt() ?? 13,
      requiredAttribute2: (json['requiredAttribute2'] as String?) ?? 'KK',
      requiredAttribute2Value:
          (json['requiredAttribute2Value'] as num?)?.toInt() ?? 13,
    );
  }
}
