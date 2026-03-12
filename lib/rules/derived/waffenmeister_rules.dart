import 'package:dsa_heldenverwaltung/domain/combat_config/waffenmeister_config.dart';

/// Gesamt-Budget fuer Waffenmeister-Boni.
const int waffenmeisterTotalBudget = 15;

/// AP-Kosten fuer die Sonderfertigkeit Waffenmeister.
const int waffenmeisterApCost = 400;

// ---------------------------------------------------------------------------
// Budget-Berechnung
// ---------------------------------------------------------------------------

/// Berechnet die automatischen Grundkosten einer Waffenmeisterschaft.
///
/// - [steigerung]: Steigerungsspalte des Kampftalents ('C', 'D', 'E').
/// - [isAttackOnly]: `true` fuer reine Angriffswaffen (Fernkampf, Peitsche,
///   Lanzenreiten).
/// - [hasAdditionalWeapons]: `true` wenn die WM fuer mehrere aehnliche
///   Waffen gilt.
int computeAutoPointCost({
  required String steigerung,
  required bool isAttackOnly,
  required bool hasAdditionalWeapons,
}) {
  var cost = 0;
  final upper = steigerung.trim().toUpperCase();
  if (upper == 'C') {
    cost += 4;
  } else if (upper == 'D') {
    cost += 2;
  }
  // Steigerung E = 0 Grundkosten
  if (isAttackOnly) {
    cost += 4;
  }
  if (hasAdditionalWeapons) {
    cost += 2;
  }
  return cost;
}

/// Berechnet das verfuegbare Budget nach Abzug der Grundkosten.
int computeAvailableBudget(int autoPointCost) {
  return waffenmeisterTotalBudget - autoPointCost;
}

// ---------------------------------------------------------------------------
// Punktekosten pro Bonus
// ---------------------------------------------------------------------------

/// Berechnet die Punktekosten eines einzelnen Bonus.
int computePointCostForBonus(WaffenmeisterBonus bonus) {
  switch (bonus.type) {
    case WaffenmeisterBonusType.maneuverReduction:
      return bonus.value.abs();
    case WaffenmeisterBonusType.iniBonus:
      return bonus.value * 3;
    case WaffenmeisterBonusType.tpKkReduction:
      return 2;
    case WaffenmeisterBonusType.atWmBonus:
      return bonus.value * 5;
    case WaffenmeisterBonusType.paWmBonus:
      return bonus.value * 5;
    case WaffenmeisterBonusType.ausfallPenaltyRemoval:
      return 2;
    case WaffenmeisterBonusType.additionalManeuver:
      return 5;
    case WaffenmeisterBonusType.rangeIncrease:
      return bonus.value;
    case WaffenmeisterBonusType.gezielterSchussReduction:
      return 2;
    case WaffenmeisterBonusType.reloadTimeHalved:
      return 5;
    case WaffenmeisterBonusType.customAdvantage:
      return bonus.customPointCost.clamp(2, 5);
  }
}

/// Berechnet die Summe aller verteilten Bonus-Punkte.
int computeTotalAllocated(List<WaffenmeisterBonus> bonuses) {
  var total = 0;
  for (final bonus in bonuses) {
    total += computePointCostForBonus(bonus);
  }
  return total;
}

// ---------------------------------------------------------------------------
// Validierung
// ---------------------------------------------------------------------------

/// Validierungsergebnis fuer eine Waffenmeister-Konfiguration.
class WaffenmeisterValidation {
  const WaffenmeisterValidation({
    required this.isValid,
    this.errors = const <String>[],
  });

  final bool isValid;
  final List<String> errors;
}

/// Validiert die Bonus-Verteilung einer Waffenmeisterschaft.
///
/// Prueft:
/// - Budget nicht ueberschritten
/// - Manoever-Reduktion max -2 pro Manoever, ein Manoever darf -4 haben
/// - INI-Bonus max +2 gesamt
/// - TP/KK nur bei Dolchen/Fechtwaffen, einmalig
/// - AT-WM / PA-WM max +2 gesamt
/// - Ausfall-Malus-Entfernung einmalig
/// - Zusatz-Manoever einmalig
/// - Reichweite max 2, nur Fernkampf
/// - Gezielter Schuss einmalig, nur Fernkampf
/// - Ladezeit-Halbierung einmalig, nur Armbrust
WaffenmeisterValidation validateBonusAllocation({
  required WaffenmeisterConfig config,
  required int autoPointCost,
  required String talentType,
  required String talentId,
}) {
  final errors = <String>[];

  // Budget
  final allocated = computeTotalAllocated(config.bonuses);
  final totalUsed = autoPointCost + allocated;
  if (totalUsed > waffenmeisterTotalBudget) {
    errors.add(
      'Budget überschritten: $totalUsed / $waffenmeisterTotalBudget Punkte.',
    );
  }

  // Manoever-Reduktionen pro Manoever summieren
  final maneuverReductions = <String, int>{};
  var maneuverReductionOver2Count = 0;
  for (final bonus in config.bonuses) {
    if (bonus.type == WaffenmeisterBonusType.maneuverReduction) {
      final key = bonus.targetManeuver.isNotEmpty
          ? bonus.targetManeuver
          : '<unbenannt>';
      maneuverReductions[key] =
          (maneuverReductions[key] ?? 0) + bonus.value.abs();
    }
  }
  for (final entry in maneuverReductions.entries) {
    if (entry.value > 4) {
      errors.add('${entry.key}: Reduktion ${entry.value} > 4 nicht erlaubt.');
    } else if (entry.value > 2) {
      maneuverReductionOver2Count++;
    }
  }
  if (maneuverReductionOver2Count > 1) {
    errors.add('Nur ein Manöver darf eine Reduktion > 2 erhalten.');
  }

  // INI-Bonus gesamt
  final totalIni = config.bonuses
      .where((b) => b.type == WaffenmeisterBonusType.iniBonus)
      .fold(0, (sum, b) => sum + b.value);
  if (totalIni > 2) {
    errors.add('INI-Bonus maximal +2 (aktuell: +$totalIni).');
  }

  // AT-WM gesamt
  final totalAtWm = config.bonuses
      .where((b) => b.type == WaffenmeisterBonusType.atWmBonus)
      .fold(0, (sum, b) => sum + b.value);
  if (totalAtWm > 2) {
    errors.add('AT-WM maximal +2 (aktuell: +$totalAtWm).');
  }

  // PA-WM gesamt
  final totalPaWm = config.bonuses
      .where((b) => b.type == WaffenmeisterBonusType.paWmBonus)
      .fold(0, (sum, b) => sum + b.value);
  if (totalPaWm > 2) {
    errors.add('PA-WM maximal +2 (aktuell: +$totalPaWm).');
  }

  // TP/KK nur Dolche/Fechtwaffen, einmalig
  final tpKkCount = config.bonuses
      .where((b) => b.type == WaffenmeisterBonusType.tpKkReduction)
      .length;
  if (tpKkCount > 1) {
    errors.add('TP/KK -1/-1 ist nur einmalig erlaubt.');
  }
  if (tpKkCount > 0) {
    final isAllowed = talentId == 'tal_dolche' || talentId == 'tal_fechtwaffen';
    if (!isAllowed) {
      errors.add('TP/KK -1/-1 ist nur bei Dolchen und Fechtwaffen möglich.');
    }
  }

  // Ausfall einmalig
  final ausfallCount = config.bonuses
      .where((b) => b.type == WaffenmeisterBonusType.ausfallPenaltyRemoval)
      .length;
  if (ausfallCount > 1) {
    errors.add('Ausfall-Malus-Entfernung ist nur einmalig erlaubt.');
  }

  // Zusatz-Manoever einmalig
  final additionalManeuverCount = config.bonuses
      .where((b) => b.type == WaffenmeisterBonusType.additionalManeuver)
      .length;
  if (additionalManeuverCount > 1) {
    errors.add('Nur ein zusätzliches Manöver erlaubt.');
  }

  // Fernkampf-spezifische Boni
  final isFernkampf = talentType == 'Fernkampf';
  final rangeCount = config.bonuses
      .where((b) => b.type == WaffenmeisterBonusType.rangeIncrease)
      .fold(0, (sum, b) => sum + b.value);
  if (rangeCount > 0 && !isFernkampf) {
    errors.add('Reichweiten-Bonus nur bei Fernkampfwaffen möglich.');
  }
  if (rangeCount > 2) {
    errors.add('Reichweiten-Bonus maximal +20% (aktuell: +${rangeCount * 10}%).');
  }

  final gezielterSchussCount = config.bonuses
      .where((b) => b.type == WaffenmeisterBonusType.gezielterSchussReduction)
      .length;
  if (gezielterSchussCount > 1) {
    errors.add('Gezielter Schuss -1 ist nur einmalig erlaubt.');
  }
  if (gezielterSchussCount > 0 && !isFernkampf) {
    errors.add('Gezielter Schuss nur bei Fernkampfwaffen möglich.');
  }

  final reloadCount = config.bonuses
      .where((b) => b.type == WaffenmeisterBonusType.reloadTimeHalved)
      .length;
  if (reloadCount > 1) {
    errors.add('Ladezeit-Halbierung ist nur einmalig erlaubt.');
  }
  if (reloadCount > 0) {
    final isArmbrust = talentId == 'tal_armbrust';
    if (!isArmbrust) {
      errors.add('Ladezeit-Halbierung nur bei Armbrüsten möglich.');
    }
  }

  return WaffenmeisterValidation(
    isValid: errors.isEmpty,
    errors: List<String>.unmodifiable(errors),
  );
}

// ---------------------------------------------------------------------------
// Effekt-Extraktion
// ---------------------------------------------------------------------------

/// Effekt-Snapshot einer aktiven Waffenmeisterschaft fuer die Kampfberechnung.
class WaffenmeisterCombatEffects {
  const WaffenmeisterCombatEffects({
    this.iniBonus = 0,
    this.atWmBonus = 0,
    this.paWmBonus = 0,
    this.tpKkBaseReduction = 0,
    this.tpKkThresholdReduction = 0,
    this.ausfallPenaltyRemoved = false,
    this.reloadTimeHalved = false,
    this.rangeIncreasePercent = 0,
    this.gezielterSchussReduction = 0,
    this.maneuverReductions = const <String, int>{},
    this.additionalManeuvers = const <String>[],
  });

  /// INI-Bonus (0-2).
  final int iniBonus;

  /// AT-Waffenmodifikator-Bonus.
  final int atWmBonus;

  /// PA-Waffenmodifikator-Bonus.
  final int paWmBonus;

  /// TP/KK-Basisreduktion (-1 wenn aktiv, sonst 0).
  final int tpKkBaseReduction;

  /// TP/KK-Schwellenreduktion (-1 wenn aktiv, sonst 0).
  final int tpKkThresholdReduction;

  /// Ausfall-Erstangriff ohne Erschwernis.
  final bool ausfallPenaltyRemoved;

  /// Ladezeit halbiert (Armbrust).
  final bool reloadTimeHalved;

  /// Reichweiten-Bonus in Prozent (0, 10, 20).
  final int rangeIncreasePercent;

  /// Gezielter-Schuss-Reduktion (0 oder 1).
  final int gezielterSchussReduction;

  /// Manoever-Erschwernis-Reduktionen nach Manoever-Name.
  final Map<String, int> maneuverReductions;

  /// Zusaetzlich erlaubte Manoever-Namen.
  final List<String> additionalManeuvers;

  /// Keine aktive Waffenmeisterschaft.
  static const none = WaffenmeisterCombatEffects();

  /// Gibt `true` zurueck wenn mindestens ein Effekt aktiv ist.
  bool get isActive =>
      iniBonus != 0 ||
      atWmBonus != 0 ||
      paWmBonus != 0 ||
      tpKkBaseReduction != 0 ||
      ausfallPenaltyRemoved ||
      reloadTimeHalved ||
      rangeIncreasePercent != 0 ||
      gezielterSchussReduction != 0 ||
      maneuverReductions.isNotEmpty ||
      additionalManeuvers.isNotEmpty;
}

/// Extrahiert die Kampfeffekte einer passenden Waffenmeisterschaft.
///
/// Durchsucht [waffenmeisterschaften] nach einer Konfiguration, deren
/// [weaponType] (oder [additionalWeaponTypes]) zur aktiven Waffe passt.
/// Gibt [WaffenmeisterCombatEffects.none] zurueck wenn keine passt.
WaffenmeisterCombatEffects computeWaffenmeisterEffects({
  required List<WaffenmeisterConfig> waffenmeisterschaften,
  required String activeWeaponType,
  required String activeTalentId,
}) {
  if (waffenmeisterschaften.isEmpty ||
      activeWeaponType.isEmpty ||
      activeTalentId.isEmpty) {
    return WaffenmeisterCombatEffects.none;
  }

  final normalizedActive = activeWeaponType.trim().toLowerCase();
  WaffenmeisterConfig? matched;
  for (final wm in waffenmeisterschaften) {
    if (wm.isSchild) continue; // Schild-Fall spaeter
    if (wm.talentId != activeTalentId) continue;
    final primaryMatch =
        wm.weaponType.trim().toLowerCase() == normalizedActive;
    final additionalMatch = wm.additionalWeaponTypes.any(
      (type) => type.trim().toLowerCase() == normalizedActive,
    );
    if (primaryMatch || additionalMatch) {
      matched = wm;
      break;
    }
  }

  if (matched == null) return WaffenmeisterCombatEffects.none;

  // Effekte aus den Boni aggregieren
  var iniBonus = 0;
  var atWmBonus = 0;
  var paWmBonus = 0;
  var tpKkBaseReduction = 0;
  var tpKkThresholdReduction = 0;
  var ausfallPenaltyRemoved = false;
  var reloadTimeHalved = false;
  var rangeIncreasePercent = 0;
  var gezielterSchussReduction = 0;
  final maneuverReductions = <String, int>{};
  final additionalManeuvers = <String>[];

  for (final bonus in matched.bonuses) {
    switch (bonus.type) {
      case WaffenmeisterBonusType.maneuverReduction:
        final key = bonus.targetManeuver.isNotEmpty
            ? bonus.targetManeuver
            : '<unbenannt>';
        maneuverReductions[key] =
            (maneuverReductions[key] ?? 0) + bonus.value.abs();
      case WaffenmeisterBonusType.iniBonus:
        iniBonus += bonus.value;
      case WaffenmeisterBonusType.tpKkReduction:
        tpKkBaseReduction = -1;
        tpKkThresholdReduction = -1;
      case WaffenmeisterBonusType.atWmBonus:
        atWmBonus += bonus.value;
      case WaffenmeisterBonusType.paWmBonus:
        paWmBonus += bonus.value;
      case WaffenmeisterBonusType.ausfallPenaltyRemoval:
        ausfallPenaltyRemoved = true;
      case WaffenmeisterBonusType.additionalManeuver:
        if (bonus.targetManeuver.isNotEmpty) {
          additionalManeuvers.add(bonus.targetManeuver);
        }
      case WaffenmeisterBonusType.rangeIncrease:
        rangeIncreasePercent += bonus.value * 10;
      case WaffenmeisterBonusType.gezielterSchussReduction:
        gezielterSchussReduction = 1;
      case WaffenmeisterBonusType.reloadTimeHalved:
        reloadTimeHalved = true;
      case WaffenmeisterBonusType.customAdvantage:
        break; // Nur Freitext, kein automatischer Effekt
    }
  }

  return WaffenmeisterCombatEffects(
    iniBonus: iniBonus,
    atWmBonus: atWmBonus,
    paWmBonus: paWmBonus,
    tpKkBaseReduction: tpKkBaseReduction,
    tpKkThresholdReduction: tpKkThresholdReduction,
    ausfallPenaltyRemoved: ausfallPenaltyRemoved,
    reloadTimeHalved: reloadTimeHalved,
    rangeIncreasePercent: rangeIncreasePercent,
    gezielterSchussReduction: gezielterSchussReduction,
    maneuverReductions: Map<String, int>.unmodifiable(maneuverReductions),
    additionalManeuvers: List<String>.unmodifiable(additionalManeuvers),
  );
}
