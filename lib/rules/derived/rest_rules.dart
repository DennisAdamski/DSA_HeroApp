import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';

/// Art des Zustandsabbaus fuer Erschöpfung und Überanstrengung.
enum RestConditionMode { rast, schlaf }

/// Eingaben fuer äussere Umstände einer Schlaf-Regeneration.
class RestEnvironmentInput {
  /// Erzeugt unveraenderliche Umweltmodifikatoren.
  const RestEnvironmentInput({
    this.weatherModifier = 0,
    this.sleepSiteModifier = 0,
    this.hasBadCamp = false,
    this.hasNightDisturbance = false,
    this.hasWatchDuty = false,
    this.extraModifier = 0,
    this.isIll = false,
  });

  /// Wettermodifikator, typischerweise 0 bis -5.
  final int weatherModifier;

  /// Schlafstaette: 0 / +1 / +2.
  final int sleepSiteModifier;

  /// Schlechter Lagerplatz.
  final bool hasBadCamp;

  /// Ruhestörung in der Nacht.
  final bool hasNightDisturbance;

  /// Nachtwache gehalten.
  final bool hasWatchDuty;

  /// Freier Restwert fuer Sonderfaelle des Meisters.
  final int extraModifier;

  /// Krankheit blockiert LeP-Regeneration und reduziert AsP stark.
  final bool isIll;
}

/// Erfasste Vorteile, Nachteile und Sonderfertigkeiten fuer Rast.
class RestAbilitySummary {
  /// Erzeugt eine erkannte Regenerationszusammenfassung.
  const RestAbilitySummary({
    this.fastHealingLevel = 0,
    this.astralRegenerationLevel = 0,
    this.hasPoorRegeneration = false,
    this.hasAstralBlock = false,
    this.talentRegenerationLevel = 0,
    this.hasMasterfulRegeneration = false,
  });

  /// Stufe von Schnelle Heilung I-III.
  final int fastHealingLevel;

  /// Stufe von Astrale Regeneration I-III.
  final int astralRegenerationLevel;

  /// Nachteil Schlechte Regeneration.
  final bool hasPoorRegeneration;

  /// Nachteil Astraler Block.
  final bool hasAstralBlock;

  /// Sonderfertigkeit Regeneration I-II aus dem Talentbereich.
  final int talentRegenerationLevel;

  /// Magische Sonderfertigkeit Meisterliche Regeneration.
  final bool hasMasterfulRegeneration;
}

/// Ergebnis einer einzelnen 6h-Regenerationsphase.
class RestRecoveryPhaseResult {
  /// Erzeugt das Ergebnis einer Phase.
  const RestRecoveryPhaseResult({
    required this.lepRecovered,
    required this.aspRecovered,
    required this.lepBase,
    required this.aspBase,
    required this.lepBonus,
    required this.aspBonus,
    required this.environmentModifier,
    required this.koBonusApplied,
    required this.inBonusApplied,
    required this.usedMasterfulRegeneration,
  });

  /// Effektiv regenerierte Lebenspunkte.
  final int lepRecovered;

  /// Effektiv regenerierte Astralpunkte.
  final int aspRecovered;

  /// Basiswurf/-wert der LeP vor Boni/Mali.
  final int lepBase;

  /// Basiswurf/-wert der AsP vor Boni/Mali.
  final int aspBase;

  /// Summierte LeP-Boni aus Vor-/Nachteilen und KO-Probe.
  final int lepBonus;

  /// Summierte AsP-Boni aus SF, Vor-/Nachteilen und IN-Probe.
  final int aspBonus;

  /// Effektiver Umweltmodifikator nach Clamp.
  final int environmentModifier;

  /// Zeigt, ob die KO-Probe +1 LeP gegeben hat.
  final bool koBonusApplied;

  /// Zeigt, ob die IN-Probe +1 AsP gegeben hat.
  final bool inBonusApplied;

  /// Meisterliche Regeneration ersetzt den W6 durch Leiteigenschaft/3.
  final bool usedMasterfulRegeneration;
}

/// Ergebnis des Au-Rückgewinns durch Ausruhen.
class RestAuRecoveryResult {
  /// Erzeugt das Ausdauer-Ergebnis.
  const RestAuRecoveryResult({
    required this.recovered,
    required this.baseRoll,
    required this.koBonusApplied,
  });

  /// Effektiv zurückgewonnene Au.
  final int recovered;

  /// Gewürfelte 3W6-Grundsumme.
  final int baseRoll;

  /// Gelungene KO-Probe gibt +6 Au.
  final bool koBonusApplied;
}

/// Ergebnis des Abbaus von Überanstrengung und Erschöpfung.
class RestConditionRecoveryResult {
  /// Erzeugt das Zustands-Ergebnis.
  const RestConditionRecoveryResult({
    required this.reducedUeberanstrengung,
    required this.reducedErschoepfung,
    required this.remainingUeberanstrengung,
    required this.remainingErschoepfung,
    required this.hours,
    required this.mode,
  });

  /// Abgebaute Überanstrengung.
  final int reducedUeberanstrengung;

  /// Abgebaute Erschöpfung.
  final int reducedErschoepfung;

  /// Restliche Überanstrengung.
  final int remainingUeberanstrengung;

  /// Restliche Erschöpfung.
  final int remainingErschoepfung;

  /// Verrechnete Stunden.
  final int hours;

  /// Rast oder Schlaf.
  final RestConditionMode mode;
}

/// Erkennt alle für Rast relevanten Vorteile, Nachteile und SF.
RestAbilitySummary collectRestAbilities(HeroSheet hero) {
  final vorteile = hero.vorteileText;
  final nachteile = hero.nachteileText;
  return RestAbilitySummary(
    fastHealingLevel: _maxNamedLevel(vorteile, 'schnelle heilung', 3),
    astralRegenerationLevel: _maxNamedLevel(
      vorteile,
      'astrale regeneration',
      3,
    ),
    hasPoorRegeneration: _containsNamedEntry(
      nachteile,
      'schlechte regeneration',
    ),
    hasAstralBlock: _containsNamedEntry(nachteile, 'astraler block'),
    talentRegenerationLevel: _maxNamedAbilityLevel(
      hero.talentSpecialAbilities,
      'regeneration',
      2,
    ),
    hasMasterfulRegeneration: _containsNamedAbility(
      hero.magicSpecialAbilities.map((entry) => entry.name),
      'meisterliche regeneration',
    ),
  );
}

/// Berechnet den effektiven Umweltmodifikator für LeP/AsP-Regeneration.
int computeRestEnvironmentModifier(RestEnvironmentInput input) {
  var total = input.weatherModifier + input.sleepSiteModifier + input.extraModifier;
  if (input.hasBadCamp) {
    total -= 1;
  }
  if (input.hasNightDisturbance) {
    total -= 1;
  }
  if (input.hasWatchDuty) {
    total -= 1;
  }
  if (total < -8) {
    return -8;
  }
  if (total > 2) {
    return 2;
  }
  return total;
}

/// Berechnet den Rückgewinn von Ausdauer durch kurzes Ausruhen.
RestAuRecoveryResult computeRestAuRecovery({
  required int currentAu,
  required int maxAu,
  required int baseRoll,
  required bool koProbeSucceeded,
}) {
  final cappedCurrent = _clampNonNegative(currentAu);
  final cappedMax = _clampNonNegative(maxAu);
  if (cappedCurrent >= cappedMax) {
    return const RestAuRecoveryResult(
      recovered: 0,
      baseRoll: 0,
      koBonusApplied: false,
    );
  }
  final rawRecovery = baseRoll + (koProbeSucceeded ? 6 : 0);
  final recovered = _clampBetween(rawRecovery, 0, cappedMax - cappedCurrent);
  return RestAuRecoveryResult(
    recovered: recovered,
    baseRoll: _clampNonNegative(baseRoll),
    koBonusApplied: koProbeSucceeded,
  );
}

/// Baut eine einzelne 6h-Regenerationsphase fuer LeP und AsP.
RestRecoveryPhaseResult computeRestRecoveryPhase({
  required RestAbilitySummary abilities,
  required Attributes effectiveAttributes,
  required RestEnvironmentInput environment,
  required int lepRoll,
  required int aspRoll,
  required bool koProbeSucceeded,
  required bool inProbeSucceeded,
  required String magicLeadAttribute,
  required bool magicEnabled,
}) {
  final envModifier = computeRestEnvironmentModifier(environment);
  if (environment.isIll) {
    return RestRecoveryPhaseResult(
      lepRecovered: 0,
      aspRecovered: magicEnabled ? _clampNonNegative(1) : 0,
      lepBase: 0,
      aspBase: magicEnabled ? 1 : 0,
      lepBonus: 0,
      aspBonus: 0,
      environmentModifier: envModifier,
      koBonusApplied: false,
      inBonusApplied: false,
      usedMasterfulRegeneration: false,
    );
  }

  final lepBonus =
      abilities.fastHealingLevel +
      (abilities.hasPoorRegeneration ? -1 : 0) +
      (koProbeSucceeded ? 1 : 0);
  final lepRecovered = _clampNonNegative(lepRoll + lepBonus + envModifier);

  final supportsMagic = magicEnabled;
  final masterfulBase = supportsMagic
      ? computeMagicLeadAttributeBonus(
          effectiveAttributes,
          magicLeadAttribute,
        )
      : 0;
  final usesMasterful = supportsMagic && abilities.hasMasterfulRegeneration;
  final aspBase = supportsMagic
      ? (usesMasterful ? masterfulBase : aspRoll)
      : 0;
  final aspBonus = supportsMagic
      ? _computeAspBonus(
          abilities: abilities,
          inProbeSucceeded: inProbeSucceeded,
          usesMasterfulRegeneration: usesMasterful,
        )
      : 0;
  final aspRecovered = supportsMagic
      ? _clampNonNegative(aspBase + aspBonus + envModifier)
      : 0;

  return RestRecoveryPhaseResult(
    lepRecovered: lepRecovered,
    aspRecovered: aspRecovered,
    lepBase: _clampNonNegative(lepRoll),
    aspBase: _clampNonNegative(aspBase),
    lepBonus: lepBonus,
    aspBonus: aspBonus,
    environmentModifier: envModifier,
    koBonusApplied: koProbeSucceeded,
    inBonusApplied: inProbeSucceeded,
    usedMasterfulRegeneration: usesMasterful,
  );
}

/// Berechnet den Abbau von Überanstrengung und Erschöpfung.
RestConditionRecoveryResult computeConditionRecovery({
  required int currentUeberanstrengung,
  required int currentErschoepfung,
  required int hours,
  required RestConditionMode mode,
}) {
  final cappedHours = _clampNonNegative(hours);
  final ueberRate = mode == RestConditionMode.schlaf ? 2 : 1;
  final erschoepfungRate = mode == RestConditionMode.schlaf ? 4 : 2;
  var remainingUeber = _clampNonNegative(currentUeberanstrengung);
  var remainingErschoepfung = _clampNonNegative(currentErschoepfung);

  for (var hour = 0; hour < cappedHours; hour++) {
    if (remainingUeber > 0) {
      remainingUeber = _clampNonNegative(remainingUeber - ueberRate);
      continue;
    }
    if (remainingErschoepfung > 0) {
      remainingErschoepfung = _clampNonNegative(
        remainingErschoepfung - erschoepfungRate,
      );
    }
  }

  final ueberBefore = _clampNonNegative(currentUeberanstrengung);
  final erschBefore = _clampNonNegative(currentErschoepfung);
  final ueberReduction = ueberBefore - remainingUeber;
  final erschReduction = erschBefore - remainingErschoepfung;
  return RestConditionRecoveryResult(
    reducedUeberanstrengung: ueberReduction,
    reducedErschoepfung: erschReduction,
    remainingUeberanstrengung: remainingUeber,
    remainingErschoepfung: remainingErschoepfung,
    hours: cappedHours,
    mode: mode,
  );
}

/// Setzt einen Heldenzustand fuer lange Abwesenheiten vollstaendig zurueck.
///
/// Der Fullrestore setzt alle Vitalwerte auf ihre Maximalwerte, baut
/// Erschoepfung und Ueberanstrengung vollstaendig ab und entfernt alle
/// Wunden. Sonstige Laufzeiteffekte bleiben unveraendert.
HeroState buildFullRestoreState({
  required HeroState currentState,
  required DerivedStats derivedStats,
}) {
  return currentState.copyWith(
    currentLep: derivedStats.maxLep,
    currentAsp: derivedStats.maxAsp,
    currentKap: derivedStats.maxKap,
    currentAu: derivedStats.maxAu,
    erschoepfung: 0,
    ueberanstrengung: 0,
    wpiZustand: const WundZustand(),
  );
}

/// Liefert den festen Bonus aus der gewählten Leiteigenschaft.
int computeMagicLeadAttributeBonus(
  Attributes effectiveAttributes,
  String magicLeadAttribute,
) {
  final code = parseAttributeCode(magicLeadAttribute);
  if (code == null) {
    return 0;
  }
  return readAttributeValue(effectiveAttributes, code) ~/ 3;
}

int _computeAspBonus({
  required RestAbilitySummary abilities,
  required bool inProbeSucceeded,
  required bool usesMasterfulRegeneration,
}) {
  final baseBonus =
      abilities.astralRegenerationLevel +
      (abilities.hasAstralBlock ? -1 : 0) +
      (inProbeSucceeded ? 1 : 0);
  if (usesMasterfulRegeneration) {
    return baseBonus + 3;
  }
  return baseBonus + abilities.talentRegenerationLevel;
}

int _maxNamedAbilityLevel(
  List<TalentSpecialAbility> abilities,
  String baseName,
  int maxLevel,
) {
  return _maxNamedLevel(
    abilities.map((entry) => entry.name).join('\n'),
    baseName,
    maxLevel,
  );
}

bool _containsNamedAbility(Iterable<String> abilities, String target) {
  final wanted = _normalizeNamedEntry(target);
  for (final ability in abilities) {
    final normalized = _normalizeNamedEntry(ability);
    if (normalized.contains(wanted)) {
      return true;
    }
  }
  return false;
}

bool _containsNamedEntry(String text, String target) {
  final wanted = _normalizeNamedEntry(target);
  final entries = text.split(RegExp(r'[\n,;]+'));
  for (final entry in entries) {
    final normalized = _normalizeNamedEntry(entry);
    if (normalized.contains(wanted)) {
      return true;
    }
  }
  return false;
}

int _maxNamedLevel(String text, String baseName, int maxLevel) {
  final entries = text.split(RegExp(r'[\n,;]+'));
  var found = 0;
  final wanted = _normalizeNamedEntry(baseName);
  for (final entry in entries) {
    final normalized = _normalizeNamedEntry(entry);
    if (!normalized.contains(wanted)) {
      continue;
    }
    final level = _extractTrailingLevel(normalized);
    if (level > found) {
      found = level;
    } else if (level == 0) {
      found = found < 1 ? 1 : found;
    }
  }
  if (found > maxLevel) {
    return maxLevel;
  }
  return found;
}

int _extractTrailingLevel(String normalized) {
  if (normalized.contains(' iii') || normalized.endsWith('iii')) {
    return 3;
  }
  if (normalized.contains(' ii') || normalized.endsWith('ii')) {
    return 2;
  }
  if (normalized.contains(' i') || normalized.endsWith('i')) {
    return 1;
  }
  if (normalized.contains(' 3') || normalized.endsWith('3')) {
    return 3;
  }
  if (normalized.contains(' 2') || normalized.endsWith('2')) {
    return 2;
  }
  if (normalized.contains(' 1') || normalized.endsWith('1')) {
    return 1;
  }
  return 0;
}

String _normalizeNamedEntry(String value) {
  var text = value.toLowerCase().trim();
  text = text
      .replaceAll(String.fromCharCode(228), 'ae')
      .replaceAll(String.fromCharCode(246), 'oe')
      .replaceAll(String.fromCharCode(252), 'ue')
      .replaceAll(String.fromCharCode(223), 'ss');
  return text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

int _clampNonNegative(int value) => value < 0 ? 0 : value;

int _clampBetween(int value, int min, int max) {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}
