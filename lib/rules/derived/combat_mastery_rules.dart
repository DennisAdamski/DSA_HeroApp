import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/combat_mastery.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/maneuver_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/waffen_rules.dart';

/// Budgetergebnis einer Kampfmeisterschaft.
class CombatMasteryBudgetSummary {
  /// Erstellt eine neue Budgetzusammenfassung.
  const CombatMasteryBudgetSummary({
    required this.baseCost,
    required this.effectCost,
    required this.totalCost,
    required this.remainingPoints,
    required this.issues,
  });

  /// Automatische Grundkosten des Ziels.
  final int baseCost;

  /// Summe aller Effektkosten.
  final int effectCost;

  /// Gesamtkosten aus Ziel und Effekten.
  final int totalCost;

  /// Restbudget relativ zu `mastery.buildPoints`.
  final int remainingPoints;

  /// Formale Hinweise oder Regelverletzungen.
  final List<String> issues;

  /// Gibt an, ob formale Fehler vorliegen.
  bool get isValid => issues.isEmpty && remainingPoints >= 0;
}

/// Status der formalen und pruefbaren Voraussetzungen.
class CombatMasteryRequirementStatus {
  /// Erstellt einen neuen Anforderungsstatus.
  const CombatMasteryRequirementStatus({
    required this.isFulfilled,
    required this.missingReasons,
    required this.warnings,
  });

  /// Wahr, wenn alle pruefbaren Voraussetzungen erfuellt sind.
  final bool isFulfilled;

  /// Harte, pruefbare Abweichungen.
  final List<String> missingReasons;

  /// Nicht pruefbare oder nur teilweise pruefbare Hinweise.
  final List<String> warnings;
}

/// Sichtbare Zusammenfassung einer anwendbaren Kampfmeisterschaft.
class CombatMasteryApplicationSummary {
  /// Erstellt eine neue Anwendungssicht.
  const CombatMasteryApplicationSummary({
    required this.masteryId,
    required this.name,
    required this.targetLabel,
    required this.automaticEffectLabels,
    required this.conditionalEffectLabels,
    required this.requirementStatus,
    required this.budgetSummary,
    required this.notes,
  });

  /// ID der Meisterschaft.
  final String masteryId;

  /// Anzeigename.
  final String name;

  /// Sichtbarer Zielbereich.
  final String targetLabel;

  /// Automatisch wirksame oder deterministisch darstellbare Effekte.
  final List<String> automaticEffectLabels;

  /// Bedingte oder manuell zu fuehrende Effekte.
  final List<String> conditionalEffectLabels;

  /// Aktueller Validierungsstatus.
  final CombatMasteryRequirementStatus requirementStatus;

  /// Budgetauswertung der Meisterschaft.
  final CombatMasteryBudgetSummary budgetSummary;

  /// Freitext-Notiz der Meisterschaft.
  final String notes;
}

/// Numerisch auswertbare Modifikatoren aus anwendbaren Meisterschaften.
class CombatMasteryDerivedModifiers {
  /// Erstellt eine neue aggregierte Meisterschaftsauswertung.
  const CombatMasteryDerivedModifiers({
    this.attackModifier = 0,
    this.parryModifier = 0,
    this.initiativeBonus = 0,
    this.shieldParryModifier = 0,
    this.tpkkBaseShift = 0,
    this.tpkkThresholdShift = 0,
    this.reloadModifier = 0,
    this.reloadDivisor = 1,
    this.rangedRangePercent = 0,
    this.targetedShotDiscount = 0,
    this.maneuverDiscounts = const <String, int>{},
    this.additionalManeuverIds = const <String>[],
    this.applicableMasteries = const <CombatMasteryApplicationSummary>[],
  });

  /// Bonus auf AT mit der aktiven Hauptwaffe.
  final int attackModifier;

  /// Bonus auf PA mit der aktiven Hauptwaffe.
  final int parryModifier;

  /// Bonus auf die Kampf-Initiative.
  final int initiativeBonus;

  /// Bonus auf die Schild-PA.
  final int shieldParryModifier;

  /// Delta fuer TP/KK-Basis.
  final int tpkkBaseShift;

  /// Delta fuer TP/KK-Schwelle.
  final int tpkkThresholdShift;

  /// Additiver Ladezeitmodifikator.
  final int reloadModifier;

  /// Divisor fuer halbe oder andere relative Ladezeit.
  final int reloadDivisor;

  /// Prozentualer Reichweitenbonus fuer Fernkampf.
  final int rangedRangePercent;

  /// Erleichterung fuer Gezielte Schuesse.
  final int targetedShotDiscount;

  /// Manoeverbezogene Erleichterungen nach stabiler Manoever-ID.
  final Map<String, int> maneuverDiscounts;

  /// Zusaetzlich erlaubte Manoever.
  final List<String> additionalManeuverIds;

  /// Sichtbare Zusammenfassungen der anwendbaren Meisterschaften.
  final List<CombatMasteryApplicationSummary> applicableMasteries;
}

/// Ermittelt die Budgetbilanz einer Kampfmeisterschaft.
CombatMasteryBudgetSummary evaluateCombatMasteryBudget({
  required CombatMastery mastery,
  TalentDef? relatedTalent,
}) {
  final issues = <String>[];
  final baseCost = _computeCombatMasteryBaseCost(
    mastery: mastery,
    relatedTalent: relatedTalent,
  );
  var effectCost = 0;
  var highDiscountUsed = false;
  var additionalManeuverCount = 0;

  for (final effect in mastery.effects) {
    if (effect.type == CombatMasteryEffectType.maneuverDiscount) {
      final discount = effect.value < 0 ? -effect.value : effect.value;
      if (discount > 2) {
        if (discount == 4 && !highDiscountUsed) {
          highDiscountUsed = true;
        } else {
          issues.add(
            'Nur ein Manoever darf eine Erleichterung von 4 Punkten erhalten.',
          );
        }
      }
    }
    if (effect.type == CombatMasteryEffectType.allowedAdditionalManeuver) {
      additionalManeuverCount++;
      if (additionalManeuverCount > 1) {
        issues.add('Es ist hoechstens ein zusaetzliches Manoever erlaubt.');
      }
    }
    if (effect.type == CombatMasteryEffectType.initiativeBonus &&
        effect.value > 2) {
      issues.add('Der INI-Bonus darf maximal 2 Punkte betragen.');
    }
    if ((effect.type == CombatMasteryEffectType.attackModifier ||
            effect.type == CombatMasteryEffectType.parryModifier ||
            effect.type == CombatMasteryEffectType.shieldParryModifier) &&
        effect.value > 2) {
      issues.add('AT/PA-WM-Boni duerfen hoechstens 2 Punkte betragen.');
    }
    if (effect.type == CombatMasteryEffectType.targetedShotDiscount &&
        effect.value > 1) {
      issues.add(
        'Die Reduzierung bei Gezielten Schuessen ist nur einmalig erlaubt.',
      );
    }
    if (effect.type == CombatMasteryEffectType.rangedRangePercent &&
        effect.value > 20) {
      issues.add('Der Reichweitenbonus ist auf 20 % begrenzt.');
    }
    if (effect.type == CombatMasteryEffectType.tpkkShift &&
        !_canUseTpKkShift(relatedTalent)) {
      issues.add(
        'TP/KK-Verschiebung ist nur fuer Dolche und Fechtwaffen vorgesehen.',
      );
    }
    effectCost += _combatMasteryEffectCost(effect);
  }

  final totalCost = baseCost + effectCost;
  final remainingPoints = mastery.buildPoints - totalCost;
  if (remainingPoints < 0) {
    issues.add(
      'Das Punktbudget ist um ${-remainingPoints} Punkte ueberschritten.',
    );
  }

  return CombatMasteryBudgetSummary(
    baseCost: baseCost,
    effectCost: effectCost,
    totalCost: totalCost,
    remainingPoints: remainingPoints,
    issues: List<String>.unmodifiable(issues),
  );
}

/// Prueft die Voraussetzungen einer Kampfmeisterschaft gegen den aktuellen Held.
CombatMasteryRequirementStatus evaluateCombatMasteryRequirements({
  required CombatMastery mastery,
  required HeroSheet hero,
  required Attributes effectiveAttributes,
}) {
  final missingReasons = <String>[];
  final warnings = <String>[];
  final requirements = mastery.requirements;
  final talentId = requirements.requiredTalentId.trim();

  if (requirements.requiredCombatAp > 0) {
    warnings.add(
      'Investierte AP in Kampfsonderfertigkeiten sind aktuell nicht automatisch pruefbar.',
    );
  }

  if (talentId.isNotEmpty) {
    final talent = hero.talents[talentId];
    final taw = talent?.talentValue ?? 0;
    if (taw < requirements.requiredTalentValue) {
      missingReasons.add(
        'TaW ${requirements.requiredTalentValue} im zugeordneten Kampftalent fehlt.',
      );
    }
    if (requirements.requiresWeaponSpecialization &&
        !_hasAnyRequiredWeaponSpecialization(
          mastery: mastery,
          heroTalents: hero.talents,
          talentId: talentId,
        )) {
      missingReasons.add(
        'Passende Waffenspezialisierung fuer die Meisterschaft fehlt.',
      );
    }
  }

  var attributeSum = 0;
  for (final requirement in requirements.attributeRequirements) {
    final code = parseAttributeCode(requirement.attributeCode);
    if (code == null) {
      continue;
    }
    final value = readAttributeValue(effectiveAttributes, code);
    attributeSum += value;
    if (value < requirement.minimum) {
      missingReasons.add(
        '${requirement.attributeCode} ${requirement.minimum} wird nicht erreicht.',
      );
    }
  }
  if (requirements.attributeRequirements.length >= 2 &&
      attributeSum < requirements.attributePairMinimumTotal) {
    missingReasons.add(
      'Die Summe der Meisterschaftseigenschaften erreicht nicht ${requirements.attributePairMinimumTotal}.',
    );
  }

  if (requirements.notes.trim().isNotEmpty) {
    warnings.add('Zusatzvoraussetzungen muessen manuell geprueft werden.');
  }

  return CombatMasteryRequirementStatus(
    isFulfilled: missingReasons.isEmpty,
    missingReasons: List<String>.unmodifiable(missingReasons),
    warnings: List<String>.unmodifiable(warnings),
  );
}

/// Leitet alle fuer die Kampfvorschau relevanten Meisterschaftseffekte ab.
CombatMasteryDerivedModifiers deriveCombatMasteryModifiers({
  required List<CombatMastery> masteries,
  required HeroSheet hero,
  required Attributes effectiveAttributes,
  required MainWeaponSlot selectedWeapon,
  required OffhandEquipmentEntry? offhandEquipment,
  required List<TalentDef> catalogTalents,
  List<ManeuverDef> catalogManeuvers = const <ManeuverDef>[],
}) {
  var attackModifier = 0;
  var parryModifier = 0;
  var initiativeBonus = 0;
  var shieldParryModifier = 0;
  var tpkkBaseShift = 0;
  var tpkkThresholdShift = 0;
  var reloadModifier = 0;
  var reloadDivisor = 1;
  var rangedRangePercent = 0;
  var targetedShotDiscount = 0;
  final maneuverDiscounts = <String, int>{};
  final additionalManeuvers = <String>[];
  final summaries = <CombatMasteryApplicationSummary>[];

  for (final mastery in masteries) {
    final appliesToWeapon = combatMasteryAppliesToWeapon(
      mastery: mastery,
      weapon: selectedWeapon,
    );
    final appliesToOffhand = combatMasteryAppliesToOffhand(
      mastery: mastery,
      offhandEquipment: offhandEquipment,
    );
    if (!appliesToWeapon && !appliesToOffhand) {
      continue;
    }

    final relatedTalent = _findTalentById(
      catalogTalents,
      mastery.requirements.requiredTalentId,
    );
    final budget = evaluateCombatMasteryBudget(
      mastery: mastery,
      relatedTalent: relatedTalent,
    );
    final requirements = evaluateCombatMasteryRequirements(
      mastery: mastery,
      hero: hero,
      effectiveAttributes: effectiveAttributes,
    );
    final automaticLabels = <String>[];
    final conditionalLabels = <String>[];

    for (final effect in mastery.effects) {
      final isConditional = effect.isConditional ||
          effect.type == CombatMasteryEffectType.specialRuleNote ||
          effect.type == CombatMasteryEffectType.conditionalToggle;
      final label = describeCombatMasteryEffect(
        effect,
        catalogManeuvers: catalogManeuvers,
      );
      if (isConditional) {
        conditionalLabels.add(label);
      } else {
        automaticLabels.add(label);
      }

      switch (effect.type) {
        case CombatMasteryEffectType.initiativeBonus:
          initiativeBonus += effect.value;
          break;
        case CombatMasteryEffectType.attackModifier:
          attackModifier += effect.value;
          break;
        case CombatMasteryEffectType.parryModifier:
          if (appliesToWeapon) {
            parryModifier += effect.value;
          }
          break;
        case CombatMasteryEffectType.shieldParryModifier:
          if (appliesToOffhand && offhandEquipment?.isShield == true) {
            shieldParryModifier += effect.value;
          }
          break;
        case CombatMasteryEffectType.tpkkShift:
          tpkkBaseShift += effect.value;
          tpkkThresholdShift += effect.secondaryValue;
          break;
        case CombatMasteryEffectType.reloadModifier:
          reloadModifier += effect.value;
          if (effect.secondaryValue > 1 &&
              effect.secondaryValue > reloadDivisor) {
            reloadDivisor = effect.secondaryValue;
          }
          break;
        case CombatMasteryEffectType.rangedRangePercent:
          rangedRangePercent += effect.value;
          break;
        case CombatMasteryEffectType.targetedShotDiscount:
          targetedShotDiscount += effect.value;
          break;
        case CombatMasteryEffectType.maneuverDiscount:
          final maneuverId = canonicalManeuverIdFromName(
            effect.maneuverId,
            catalogManeuvers: catalogManeuvers,
          );
          if (maneuverId.isEmpty) {
            break;
          }
          maneuverDiscounts[maneuverId] =
              (maneuverDiscounts[maneuverId] ?? 0) + effect.value;
          break;
        case CombatMasteryEffectType.allowedAdditionalManeuver:
          final maneuverId = canonicalManeuverIdFromName(
            effect.maneuverId,
            catalogManeuvers: catalogManeuvers,
          );
          if (maneuverId.isNotEmpty &&
              !additionalManeuvers.contains(maneuverId)) {
            additionalManeuvers.add(maneuverId);
          }
          break;
        case CombatMasteryEffectType.specialRuleNote:
        case CombatMasteryEffectType.conditionalToggle:
          break;
      }
    }

    summaries.add(
      CombatMasteryApplicationSummary(
        masteryId: mastery.id,
        name: mastery.name,
        targetLabel: describeCombatMasteryTarget(mastery),
        automaticEffectLabels: List<String>.unmodifiable(automaticLabels),
        conditionalEffectLabels: List<String>.unmodifiable(conditionalLabels),
        requirementStatus: requirements,
        budgetSummary: budget,
        notes: mastery.notes,
      ),
    );
  }

  return CombatMasteryDerivedModifiers(
    attackModifier: attackModifier,
    parryModifier: parryModifier,
    initiativeBonus: initiativeBonus,
    shieldParryModifier: shieldParryModifier,
    tpkkBaseShift: tpkkBaseShift,
    tpkkThresholdShift: tpkkThresholdShift,
    reloadModifier: reloadModifier,
    reloadDivisor: reloadDivisor,
    rangedRangePercent: rangedRangePercent,
    targetedShotDiscount: targetedShotDiscount,
    maneuverDiscounts: Map<String, int>.unmodifiable(maneuverDiscounts),
    additionalManeuverIds: List<String>.unmodifiable(additionalManeuvers),
    applicableMasteries: List<CombatMasteryApplicationSummary>.unmodifiable(
      summaries,
    ),
  );
}

/// Prueft, ob eine Meisterschaft auf die aktive Hauptwaffe passt.
bool combatMasteryAppliesToWeapon({
  required CombatMastery mastery,
  required MainWeaponSlot weapon,
}) {
  switch (mastery.targetScope) {
    case CombatMasteryTargetScope.singleWeapon:
    case CombatMasteryTargetScope.weaponSet:
    case CombatMasteryTargetScope.customGroup:
      final tokens = _masteryTargetTokens(mastery.targetRefs);
      if (tokens.isEmpty) {
        return false;
      }
      final weaponToken = _primaryWeaponToken(weapon);
      return weaponToken.isNotEmpty && tokens.contains(weaponToken);
    case CombatMasteryTargetScope.shield:
    case CombatMasteryTargetScope.parryWeapon:
      return false;
  }
}

/// Prueft, ob eine Meisterschaft auf die belegte Nebenhand passt.
bool combatMasteryAppliesToOffhand({
  required CombatMastery mastery,
  required OffhandEquipmentEntry? offhandEquipment,
}) {
  if (offhandEquipment == null) {
    return false;
  }
  switch (mastery.targetScope) {
    case CombatMasteryTargetScope.shield:
      return offhandEquipment.isShield;
    case CombatMasteryTargetScope.parryWeapon:
      return !offhandEquipment.isShield;
    case CombatMasteryTargetScope.singleWeapon:
    case CombatMasteryTargetScope.weaponSet:
    case CombatMasteryTargetScope.customGroup:
      return false;
  }
}

/// Liefert einen menschenlesbaren Zieltext.
String describeCombatMasteryTarget(CombatMastery mastery) {
  switch (mastery.targetScope) {
    case CombatMasteryTargetScope.singleWeapon:
      return mastery.targetRefs.isEmpty
          ? 'Einzelwaffe'
          : mastery.targetRefs.first;
    case CombatMasteryTargetScope.weaponSet:
      return mastery.targetRefs.isEmpty
          ? 'Waffenset'
          : mastery.targetRefs.join(', ');
    case CombatMasteryTargetScope.shield:
      return 'Schild';
    case CombatMasteryTargetScope.parryWeapon:
      return 'Parierwaffe';
    case CombatMasteryTargetScope.customGroup:
      return mastery.targetRefs.isEmpty
          ? 'Freie Gruppe'
          : mastery.targetRefs.join(', ');
  }
}

/// Formatiert einen Effekt fuer die UI.
String describeCombatMasteryEffect(
  CombatMasteryEffect effect, {
  List<ManeuverDef> catalogManeuvers = const <ManeuverDef>[],
}) {
  final maneuverLabel = displayNameForManeuverId(
    effect.maneuverId,
    catalogManeuvers: catalogManeuvers,
  );
  switch (effect.type) {
    case CombatMasteryEffectType.maneuverDiscount:
      return '$maneuverLabel ${_signedValue(-effect.value)}';
    case CombatMasteryEffectType.allowedAdditionalManeuver:
      return 'Zusaetzliches Manoever: $maneuverLabel';
    case CombatMasteryEffectType.initiativeBonus:
      return 'INI ${_signedValue(effect.value)}';
    case CombatMasteryEffectType.attackModifier:
      return 'AT-WM ${_signedValue(effect.value)}';
    case CombatMasteryEffectType.parryModifier:
      return 'PA-WM ${_signedValue(effect.value)}';
    case CombatMasteryEffectType.shieldParryModifier:
      return 'Schild-PA ${_signedValue(effect.value)}';
    case CombatMasteryEffectType.tpkkShift:
      return 'TP/KK ${_signedValue(effect.value)}/${_signedValue(effect.secondaryValue)}';
    case CombatMasteryEffectType.rangedRangePercent:
      return 'Reichweite +${effect.value} %';
    case CombatMasteryEffectType.targetedShotDiscount:
      return 'Gezielter Schuss ${_signedValue(-effect.value)}';
    case CombatMasteryEffectType.reloadModifier:
      if (effect.secondaryValue > 1) {
        return 'Ladezeit /${effect.secondaryValue}';
      }
      return 'Ladezeit ${_signedValue(effect.value)}';
    case CombatMasteryEffectType.specialRuleNote:
      return effect.label.trim().isEmpty ? effect.notes.trim() : effect.label;
    case CombatMasteryEffectType.conditionalToggle:
      return effect.label.trim().isEmpty
          ? 'Bedingter Effekt'
          : effect.label.trim();
  }
}

int _computeCombatMasteryBaseCost({
  required CombatMastery mastery,
  required TalentDef? relatedTalent,
}) {
  var total = 0;
  final isAttackOnly =
      relatedTalent != null &&
      (_isPureAttackTalent(relatedTalent) ||
          normalizeCombatToken(relatedTalent.name) == 'lanzenreiten');
  if (isAttackOnly) {
    total += 4;
  }
  if ((mastery.targetScope == CombatMasteryTargetScope.weaponSet ||
          mastery.targetScope == CombatMasteryTargetScope.customGroup) &&
      mastery.targetRefs.length > 1) {
    total += 2;
  }
  final steigerung = (relatedTalent?.steigerung ?? '').trim().toUpperCase();
  if (steigerung == 'C') {
    total += 4;
  } else if (steigerung == 'D') {
    total += 2;
  }
  return total;
}

int _combatMasteryEffectCost(CombatMasteryEffect effect) {
  if (effect.pointCostOverride != null) {
    return effect.pointCostOverride!;
  }
  switch (effect.type) {
    case CombatMasteryEffectType.maneuverDiscount:
      return effect.value < 0 ? -effect.value : effect.value;
    case CombatMasteryEffectType.allowedAdditionalManeuver:
      return 5;
    case CombatMasteryEffectType.initiativeBonus:
      return effect.value * 3;
    case CombatMasteryEffectType.attackModifier:
    case CombatMasteryEffectType.parryModifier:
    case CombatMasteryEffectType.shieldParryModifier:
      return effect.value * 5;
    case CombatMasteryEffectType.tpkkShift:
      return 2;
    case CombatMasteryEffectType.rangedRangePercent:
      return effect.value ~/ 10;
    case CombatMasteryEffectType.targetedShotDiscount:
      return effect.value * 2;
    case CombatMasteryEffectType.reloadModifier:
      if (effect.secondaryValue > 1) {
        return 5;
      }
      final value = effect.value < 0 ? -effect.value : effect.value;
      return value * 2;
    case CombatMasteryEffectType.specialRuleNote:
    case CombatMasteryEffectType.conditionalToggle:
      return 0;
  }
}

bool _hasAnyRequiredWeaponSpecialization({
  required CombatMastery mastery,
  required Map<String, HeroTalentEntry> heroTalents,
  required String talentId,
}) {
  final targetRefs = mastery.targetRefs;
  if (targetRefs.isEmpty) {
    return false;
  }
  for (final targetRef in targetRefs) {
    if (hasCombatSpecialization(
      talents: heroTalents,
      talentId: talentId,
      weaponType: targetRef,
    )) {
      return true;
    }
  }
  return false;
}

bool _canUseTpKkShift(TalentDef? talent) {
  if (talent == null) {
    return false;
  }
  final name = normalizeCombatToken(talent.name);
  return name == 'dolche' || name == 'fechtwaffen';
}

bool _isPureAttackTalent(TalentDef talent) {
  if (isRangedCombatTalent(talent)) {
    return true;
  }
  final name = normalizeCombatToken(talent.name);
  return name == 'peitsche';
}

Set<String> _masteryTargetTokens(Iterable<String> targetRefs) {
  final tokens = <String>{};
  for (final value in targetRefs) {
    final token = normalizeCombatToken(value);
    if (token.isEmpty) {
      continue;
    }
    tokens.add(token);
  }
  return tokens;
}

String _primaryWeaponToken(MainWeaponSlot weapon) {
  final raw = weapon.weaponType.trim().isEmpty ? weapon.name : weapon.weaponType;
  return normalizeCombatToken(raw);
}

String _signedValue(int value) {
  if (value > 0) {
    return '+$value';
  }
  return value.toString();
}

TalentDef? _findTalentById(List<TalentDef> talents, String talentId) {
  final trimmed = talentId.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  for (final talent in talents) {
    if (talent.id == trimmed) {
      return talent;
    }
  }
  return null;
}
