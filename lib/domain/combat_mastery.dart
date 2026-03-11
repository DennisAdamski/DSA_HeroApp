import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';

/// Zielbereich einer Kampfmeisterschaft.
enum CombatMasteryTargetScope {
  /// Eine konkrete Waffenart wie `Langschwert`.
  singleWeapon,

  /// Eine definierte Liste aehnlicher Waffenarten.
  weaponSet,

  /// Gilt fuer Schilde in der Nebenhand.
  shield,

  /// Gilt fuer Parierwaffen in der Nebenhand.
  parryWeapon,

  /// Freie Gruppe fuer spaetere Erweiterungen.
  customGroup,
}

/// Typ eines strukturierten Kampfmeisterschaftseffekts.
enum CombatMasteryEffectType {
  maneuverDiscount,
  allowedAdditionalManeuver,
  initiativeBonus,
  attackModifier,
  parryModifier,
  shieldParryModifier,
  tpkkShift,
  rangedRangePercent,
  targetedShotDiscount,
  reloadModifier,
  specialRuleNote,
  conditionalToggle,
}

/// Beschreibt eine Eigenschaftsanforderung fuer eine Kampfmeisterschaft.
class CombatMasteryAttributeRequirement {
  /// Erstellt eine einzelne Eigenschaftsvorgabe.
  const CombatMasteryAttributeRequirement({
    required this.attributeCode,
    required this.minimum,
  });

  /// Kanonischer Eigenschaftscode (`MU`, `GE`, ...).
  final String attributeCode;

  /// Mindestwert der Eigenschaft.
  final int minimum;

  /// Gibt eine Kopie mit geaenderten Feldern zurueck.
  CombatMasteryAttributeRequirement copyWith({
    String? attributeCode,
    int? minimum,
  }) {
    return CombatMasteryAttributeRequirement(
      attributeCode: _normalizeAttributeCode(attributeCode ?? this.attributeCode),
      minimum: minimum ?? this.minimum,
    );
  }

  /// Serialisiert die Eigenschaftsanforderung.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'attributeCode': _normalizeAttributeCode(attributeCode),
      'minimum': minimum,
    };
  }

  /// Liest eine Eigenschaftsanforderung tolerant aus JSON.
  static CombatMasteryAttributeRequirement? fromJson(
    Map<String, dynamic> json,
  ) {
    final code = _normalizeAttributeCode(
      (json['attributeCode'] as String?) ?? '',
    );
    if (code.isEmpty) {
      return null;
    }
    return CombatMasteryAttributeRequirement(
      attributeCode: code,
      minimum: (json['minimum'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Beschreibt die formalen Voraussetzungen einer Kampfmeisterschaft.
class CombatMasteryRequirements {
  /// Erstellt ein neues Anforderungspaket.
  const CombatMasteryRequirements({
    this.requiredCombatAp = 2500,
    this.requiredTalentId = '',
    this.requiredTalentValue = 18,
    this.requiresWeaponSpecialization = true,
    this.attributePairMinimumTotal = 32,
    this.attributeRequirements =
        const <CombatMasteryAttributeRequirement>[],
    this.notes = '',
  });

  /// Mindest-AP in Kampfsonderfertigkeiten.
  final int requiredCombatAp;

  /// Referenziertes Kampftalent fuer die Meisterschaft.
  final String requiredTalentId;

  /// Mindest-TaW im referenzierten Kampftalent.
  final int requiredTalentValue;

  /// Ob eine passende Waffenspezialisierung verlangt wird.
  final bool requiresWeaponSpecialization;

  /// Mindest-Gesamtsumme der angegebenen Eigenschaften.
  final int attributePairMinimumTotal;

  /// Einzelne Eigenschaftsmindestwerte.
  final List<CombatMasteryAttributeRequirement> attributeRequirements;

  /// Freitext fuer nicht strukturierte Zusatzvoraussetzungen.
  final String notes;

  /// Gibt eine Kopie mit selektiv angepassten Feldern zurueck.
  CombatMasteryRequirements copyWith({
    int? requiredCombatAp,
    String? requiredTalentId,
    int? requiredTalentValue,
    bool? requiresWeaponSpecialization,
    int? attributePairMinimumTotal,
    List<CombatMasteryAttributeRequirement>? attributeRequirements,
    String? notes,
  }) {
    return CombatMasteryRequirements(
      requiredCombatAp: requiredCombatAp ?? this.requiredCombatAp,
      requiredTalentId: requiredTalentId ?? this.requiredTalentId,
      requiredTalentValue: requiredTalentValue ?? this.requiredTalentValue,
      requiresWeaponSpecialization:
          requiresWeaponSpecialization ?? this.requiresWeaponSpecialization,
      attributePairMinimumTotal:
          attributePairMinimumTotal ?? this.attributePairMinimumTotal,
      attributeRequirements: _normalizeAttributeRequirements(
        attributeRequirements ?? this.attributeRequirements,
      ),
      notes: notes ?? this.notes,
    );
  }

  /// Serialisiert die Anforderungen in JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'requiredCombatAp': requiredCombatAp,
      'requiredTalentId': requiredTalentId,
      'requiredTalentValue': requiredTalentValue,
      'requiresWeaponSpecialization': requiresWeaponSpecialization,
      'attributePairMinimumTotal': attributePairMinimumTotal,
      'attributeRequirements': _normalizeAttributeRequirements(
        attributeRequirements,
      ).map((entry) => entry.toJson()).toList(growable: false),
      'notes': notes,
    };
  }

  /// Liest Anforderungen tolerant aus JSON.
  static CombatMasteryRequirements fromJson(Map<String, dynamic> json) {
    final rawRequirements =
        (json['attributeRequirements'] as List?) ?? const <dynamic>[];
    return CombatMasteryRequirements(
      requiredCombatAp: (json['requiredCombatAp'] as num?)?.toInt() ?? 2500,
      requiredTalentId: (json['requiredTalentId'] as String?) ?? '',
      requiredTalentValue:
          (json['requiredTalentValue'] as num?)?.toInt() ?? 18,
      requiresWeaponSpecialization:
          json['requiresWeaponSpecialization'] as bool? ?? true,
      attributePairMinimumTotal:
          (json['attributePairMinimumTotal'] as num?)?.toInt() ?? 32,
      attributeRequirements: rawRequirements
          .whereType<Map>()
          .map(
            (entry) => CombatMasteryAttributeRequirement.fromJson(
              entry.cast<String, dynamic>(),
            ),
          )
          .whereType<CombatMasteryAttributeRequirement>()
          .toList(growable: false),
      notes: (json['notes'] as String?) ?? '',
    );
  }
}

/// Einzelner, strukturierter Effekt einer Kampfmeisterschaft.
class CombatMasteryEffect {
  /// Erstellt einen Kampfmeisterschaftseffekt.
  const CombatMasteryEffect({
    required this.type,
    this.maneuverId = '',
    this.label = '',
    this.value = 0,
    this.secondaryValue = 0,
    this.pointCostOverride,
    this.isConditional = false,
    this.isManualActivation = false,
    this.notes = '',
  });

  /// Art des Effekts.
  final CombatMasteryEffectType type;

  /// Referenziertes Manoever fuer manoeverbezogene Effekte.
  final String maneuverId;

  /// Anzeigename oder Kurzlabel.
  final String label;

  /// Primaerwert des Effekts.
  final int value;

  /// Sekundaerwert des Effekts.
  final int secondaryValue;

  /// Optionaler fixer Punktwert fuer Sonderfaelle.
  final int? pointCostOverride;

  /// Markiert einen bedingten, nicht immer aktiven Effekt.
  final bool isConditional;

  /// Kennzeichnet Effekte, die spaeter manuell aktivierbar sein sollen.
  final bool isManualActivation;

  /// Freitext fuer Details oder Restregeln.
  final String notes;

  /// Gibt eine Kopie mit selektiv geaenderten Feldern zurueck.
  CombatMasteryEffect copyWith({
    CombatMasteryEffectType? type,
    String? maneuverId,
    String? label,
    int? value,
    int? secondaryValue,
    int? pointCostOverride,
    bool clearPointCostOverride = false,
    bool? isConditional,
    bool? isManualActivation,
    String? notes,
  }) {
    return CombatMasteryEffect(
      type: type ?? this.type,
      maneuverId: maneuverId ?? this.maneuverId,
      label: label ?? this.label,
      value: value ?? this.value,
      secondaryValue: secondaryValue ?? this.secondaryValue,
      pointCostOverride: clearPointCostOverride
          ? null
          : (pointCostOverride ?? this.pointCostOverride),
      isConditional: isConditional ?? this.isConditional,
      isManualActivation: isManualActivation ?? this.isManualActivation,
      notes: notes ?? this.notes,
    );
  }

  /// Serialisiert den Effekt in JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': combatMasteryEffectTypeToJson(type),
      'maneuverId': maneuverId,
      'label': label,
      'value': value,
      'secondaryValue': secondaryValue,
      'pointCostOverride': pointCostOverride,
      'isConditional': isConditional,
      'isManualActivation': isManualActivation,
      'notes': notes,
    };
  }

  /// Liest einen Effekt tolerant aus JSON.
  static CombatMasteryEffect? fromJson(Map<String, dynamic> json) {
    final type = combatMasteryEffectTypeFromJson(
      (json['type'] as String?) ?? '',
    );
    if (type == null) {
      return null;
    }
    return CombatMasteryEffect(
      type: type,
      maneuverId: (json['maneuverId'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      value: (json['value'] as num?)?.toInt() ?? 0,
      secondaryValue: (json['secondaryValue'] as num?)?.toInt() ?? 0,
      pointCostOverride: (json['pointCostOverride'] as num?)?.toInt(),
      isConditional: json['isConditional'] as bool? ?? false,
      isManualActivation: json['isManualActivation'] as bool? ?? false,
      notes: (json['notes'] as String?) ?? '',
    );
  }
}

/// Persistierte Kampfmeisterschaft eines Helden.
class CombatMastery {
  /// Erstellt eine Kampfmeisterschaft.
  const CombatMastery({
    required this.id,
    required this.name,
    this.targetScope = CombatMasteryTargetScope.singleWeapon,
    this.targetRefs = const <String>[],
    this.effects = const <CombatMasteryEffect>[],
    this.requirements = const CombatMasteryRequirements(),
    this.apCost = 400,
    this.buildPoints = 15,
    this.notes = '',
  });

  /// Stabile ID innerhalb des Helden.
  final String id;

  /// Anzeigename der Meisterschaft.
  final String name;

  /// Zielbereich, auf den die Meisterschaft reagiert.
  final CombatMasteryTargetScope targetScope;

  /// Referenzen auf Waffenarten oder freie Gruppennamen.
  final List<String> targetRefs;

  /// Strukturierte Effekte der Meisterschaft.
  final List<CombatMasteryEffect> effects;

  /// Formale Voraussetzungen.
  final CombatMasteryRequirements requirements;

  /// AP-Kosten der Sonderfertigkeit.
  final int apCost;

  /// Zielbudget der Meisterschaft.
  final int buildPoints;

  /// Freitext fuer Meisterstil, Quelle oder offene Regeln.
  final String notes;

  /// Gibt eine Kopie mit selektiv geaenderten Feldern zurueck.
  CombatMastery copyWith({
    String? id,
    String? name,
    CombatMasteryTargetScope? targetScope,
    List<String>? targetRefs,
    List<CombatMasteryEffect>? effects,
    CombatMasteryRequirements? requirements,
    int? apCost,
    int? buildPoints,
    String? notes,
  }) {
    return CombatMastery(
      id: id ?? this.id,
      name: name ?? this.name,
      targetScope: targetScope ?? this.targetScope,
      targetRefs: _normalizeStringList(targetRefs ?? this.targetRefs),
      effects: _normalizeEffects(effects ?? this.effects),
      requirements: requirements ?? this.requirements,
      apCost: apCost ?? this.apCost,
      buildPoints: buildPoints ?? this.buildPoints,
      notes: notes ?? this.notes,
    );
  }

  /// Serialisiert die Kampfmeisterschaft.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'targetScope': combatMasteryTargetScopeToJson(targetScope),
      'targetRefs': _normalizeStringList(targetRefs),
      'effects': _normalizeEffects(effects)
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'requirements': requirements.toJson(),
      'apCost': apCost,
      'buildPoints': buildPoints,
      'notes': notes,
    };
  }

  /// Liest eine Kampfmeisterschaft tolerant aus JSON.
  static CombatMastery? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?) ?? '';
    if (id.trim().isEmpty) {
      return null;
    }
    final rawEffects = (json['effects'] as List?) ?? const <dynamic>[];
    final rawRequirements = json['requirements'];
    return CombatMastery(
      id: id,
      name: (json['name'] as String?) ?? '',
      targetScope: combatMasteryTargetScopeFromJson(
        (json['targetScope'] as String?) ?? '',
      ),
      targetRefs: _normalizeStringList(
        (json['targetRefs'] as List?) ?? const <dynamic>[],
      ),
      effects: rawEffects
          .whereType<Map>()
          .map((entry) => CombatMasteryEffect.fromJson(
                entry.cast<String, dynamic>(),
              ))
          .whereType<CombatMasteryEffect>()
          .toList(growable: false),
      requirements: rawRequirements is Map
          ? CombatMasteryRequirements.fromJson(
              rawRequirements.cast<String, dynamic>(),
            )
          : const CombatMasteryRequirements(),
      apCost: (json['apCost'] as num?)?.toInt() ?? 400,
      buildPoints: (json['buildPoints'] as num?)?.toInt() ?? 15,
      notes: (json['notes'] as String?) ?? '',
    );
  }
}

/// Wandelt den JSON-Wert in einen Zielbereich um.
CombatMasteryTargetScope combatMasteryTargetScopeFromJson(String value) {
  switch (value.trim()) {
    case 'weaponSet':
      return CombatMasteryTargetScope.weaponSet;
    case 'shield':
      return CombatMasteryTargetScope.shield;
    case 'parryWeapon':
      return CombatMasteryTargetScope.parryWeapon;
    case 'customGroup':
      return CombatMasteryTargetScope.customGroup;
    case 'singleWeapon':
    default:
      return CombatMasteryTargetScope.singleWeapon;
  }
}

/// Serialisiert einen Zielbereich.
String combatMasteryTargetScopeToJson(CombatMasteryTargetScope value) {
  switch (value) {
    case CombatMasteryTargetScope.singleWeapon:
      return 'singleWeapon';
    case CombatMasteryTargetScope.weaponSet:
      return 'weaponSet';
    case CombatMasteryTargetScope.shield:
      return 'shield';
    case CombatMasteryTargetScope.parryWeapon:
      return 'parryWeapon';
    case CombatMasteryTargetScope.customGroup:
      return 'customGroup';
  }
}

/// Liest einen Effekt-Typ aus JSON.
CombatMasteryEffectType? combatMasteryEffectTypeFromJson(String value) {
  switch (value.trim()) {
    case 'maneuverDiscount':
      return CombatMasteryEffectType.maneuverDiscount;
    case 'allowedAdditionalManeuver':
      return CombatMasteryEffectType.allowedAdditionalManeuver;
    case 'initiativeBonus':
      return CombatMasteryEffectType.initiativeBonus;
    case 'attackModifier':
      return CombatMasteryEffectType.attackModifier;
    case 'parryModifier':
      return CombatMasteryEffectType.parryModifier;
    case 'shieldParryModifier':
      return CombatMasteryEffectType.shieldParryModifier;
    case 'tpkkShift':
      return CombatMasteryEffectType.tpkkShift;
    case 'rangedRangePercent':
      return CombatMasteryEffectType.rangedRangePercent;
    case 'targetedShotDiscount':
      return CombatMasteryEffectType.targetedShotDiscount;
    case 'reloadModifier':
      return CombatMasteryEffectType.reloadModifier;
    case 'specialRuleNote':
      return CombatMasteryEffectType.specialRuleNote;
    case 'conditionalToggle':
      return CombatMasteryEffectType.conditionalToggle;
    default:
      return null;
  }
}

/// Serialisiert einen Effekt-Typ.
String combatMasteryEffectTypeToJson(CombatMasteryEffectType value) {
  switch (value) {
    case CombatMasteryEffectType.maneuverDiscount:
      return 'maneuverDiscount';
    case CombatMasteryEffectType.allowedAdditionalManeuver:
      return 'allowedAdditionalManeuver';
    case CombatMasteryEffectType.initiativeBonus:
      return 'initiativeBonus';
    case CombatMasteryEffectType.attackModifier:
      return 'attackModifier';
    case CombatMasteryEffectType.parryModifier:
      return 'parryModifier';
    case CombatMasteryEffectType.shieldParryModifier:
      return 'shieldParryModifier';
    case CombatMasteryEffectType.tpkkShift:
      return 'tpkkShift';
    case CombatMasteryEffectType.rangedRangePercent:
      return 'rangedRangePercent';
    case CombatMasteryEffectType.targetedShotDiscount:
      return 'targetedShotDiscount';
    case CombatMasteryEffectType.reloadModifier:
      return 'reloadModifier';
    case CombatMasteryEffectType.specialRuleNote:
      return 'specialRuleNote';
    case CombatMasteryEffectType.conditionalToggle:
      return 'conditionalToggle';
  }
}

List<String> _normalizeStringList(Iterable<dynamic> values) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final value in values) {
    final text = value.toString().trim();
    if (text.isEmpty || seen.contains(text)) {
      continue;
    }
    seen.add(text);
    normalized.add(text);
  }
  return List<String>.unmodifiable(normalized);
}

List<CombatMasteryEffect> _normalizeEffects(
  Iterable<CombatMasteryEffect> values,
) {
  final normalized = <CombatMasteryEffect>[];
  for (final value in values) {
    normalized.add(value);
  }
  return List<CombatMasteryEffect>.unmodifiable(normalized);
}

List<CombatMasteryAttributeRequirement> _normalizeAttributeRequirements(
  Iterable<CombatMasteryAttributeRequirement> values,
) {
  final seen = <String>{};
  final normalized = <CombatMasteryAttributeRequirement>[];
  for (final value in values) {
    final code = _normalizeAttributeCode(value.attributeCode);
    if (code.isEmpty || seen.contains(code)) {
      continue;
    }
    seen.add(code);
    normalized.add(
      CombatMasteryAttributeRequirement(
        attributeCode: code,
        minimum: value.minimum,
      ),
    );
  }
  return List<CombatMasteryAttributeRequirement>.unmodifiable(normalized);
}

String _normalizeAttributeCode(String raw) {
  final parsed = parseAttributeCode(raw);
  switch (parsed) {
    case AttributeCode.mu:
      return 'MU';
    case AttributeCode.kl:
      return 'KL';
    case AttributeCode.inn:
      return 'IN';
    case AttributeCode.ch:
      return 'CH';
    case AttributeCode.ff:
      return 'FF';
    case AttributeCode.ge:
      return 'GE';
    case AttributeCode.ko:
      return 'KO';
    case AttributeCode.kk:
      return 'KK';
    case null:
      return '';
  }
}
