import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/rest_rules.dart';

/// Rastaktivität des Helden; bestimmt, welche Teilregeln einer Rast greifen.
enum RestActivity {
  /// Kurze Pause: nur Abbau von Überanstrengung und Erschöpfung im Rasttempo.
  kurzeRast,

  /// Volle Nachtruhe: Ausdauer, Zustandsabbau im Schlaftempo und eine
  /// Regenerationsphase für LeP/AsP.
  schlaf,

  /// Bettruhe: wie Schlaf, aber mit optionaler zweiter Regenerationsphase.
  bettruhe,

  /// Nur Ausdauer regenerieren – kein Schlaf, keine Regeneration.
  nurAusruhen,
}

/// Feste Schlafdauer für den Zustandsabbau bei Schlaf und Bettruhe.
const int kRestSleepConditionHours = 8;

/// Leitet aus einer [RestActivity] ab, welche Teilregeln einer Rast greifen.
extension RestActivityRules on RestActivity {
  /// Ausdauer regeneriert bei allen Aktivitäten außer der kurzen Rast.
  bool get recoversAu => this != RestActivity.kurzeRast;

  /// Zustände bauen sich bei allen Aktivitäten außer „nur ausruhen“ ab.
  bool get reducesConditions => this != RestActivity.nurAusruhen;

  /// Die kurze Rast baut im Rasttempo ab, alles andere im Schlaftempo.
  RestConditionMode get conditionMode => this == RestActivity.kurzeRast
      ? RestConditionMode.rast
      : RestConditionMode.schlaf;

  /// Verrechnete Stunden: frei gewählt bei der kurzen Rast, sonst fest 8.
  int conditionHours(int requestedHours) {
    return this == RestActivity.kurzeRast
        ? requestedHours
        : kRestSleepConditionHours;
  }

  /// Anzahl der LeP/AsP-Regenerationsphasen dieser Aktivität.
  int regenerationPhases({required bool applySecondPhase}) {
    switch (this) {
      case RestActivity.schlaf:
        return 1;
      case RestActivity.bettruhe:
        return applySecondPhase ? 2 : 1;
      case RestActivity.kurzeRast:
      case RestActivity.nurAusruhen:
        return 0;
    }
  }
}

/// Wertet eine einfache W20-Probe der Rast aus.
///
/// Eine 1 gelingt immer, eine 20 misslingt immer, ein fehlender Wurf
/// misslingt; sonst gelingt die Probe bei höchstens dem Zielwert.
bool isRestProbeSuccessful({required int? roll, required int target}) {
  if (roll == null) {
    return false;
  }
  if (roll == 1) {
    return true;
  }
  if (roll == 20) {
    return false;
  }
  return roll <= target;
}

/// Ein Wurf oder eine Probe der Rast.
enum RestRollSlot {
  /// 3W6 Ausdauer beim Ausruhen.
  auRoll,

  /// KO-Probe beim Ausruhen (+6 Au).
  auKoProbe,

  /// 1W6 LeP in Phase 1.
  phase1Lep,

  /// KO-Probe in Phase 1 (+1 LeP).
  phase1KoProbe,

  /// 1W6 AsP in Phase 1.
  phase1Asp,

  /// IN-Probe in Phase 1 (+1 AsP).
  phase1InProbe,

  /// 1W6 LeP in Phase 2.
  phase2Lep,

  /// KO-Probe in Phase 2.
  phase2KoProbe,

  /// 1W6 AsP in Phase 2.
  phase2Asp,

  /// IN-Probe in Phase 2.
  phase2InProbe,
}

/// Die vier Würfe einer Regenerationsphase in fester Reihenfolge.
class RestPhaseSlots {
  const RestPhaseSlots._({
    required this.lep,
    required this.koProbe,
    required this.asp,
    required this.inProbe,
  });

  /// 1W6 LeP.
  final RestRollSlot lep;

  /// KO-Probe.
  final RestRollSlot koProbe;

  /// 1W6 AsP bzw. Leiteigenschaft/3.
  final RestRollSlot asp;

  /// IN-Probe.
  final RestRollSlot inProbe;
}

/// Würfe der Phasen 1 und 2, indiziert ab 0.
const List<RestPhaseSlots> kRestPhaseSlots = <RestPhaseSlots>[
  RestPhaseSlots._(
    lep: RestRollSlot.phase1Lep,
    koProbe: RestRollSlot.phase1KoProbe,
    asp: RestRollSlot.phase1Asp,
    inProbe: RestRollSlot.phase1InProbe,
  ),
  RestPhaseSlots._(
    lep: RestRollSlot.phase2Lep,
    koProbe: RestRollSlot.phase2KoProbe,
    asp: RestRollSlot.phase2Asp,
    inProbe: RestRollSlot.phase2InProbe,
  ),
];

/// Alle Eingaben einer Rast außer den aktuellen Vitalwerten.
///
/// Fehlt ein Wurf in [rolls], zählt ein Wurf als 0 und eine Probe als
/// misslungen.
class RestOutcomeInput {
  /// Erzeugt die Eingaben einer Rast.
  const RestOutcomeInput({
    required this.activity,
    this.requestedConditionHours = 1,
    this.applySecondPhase = true,
    this.rolls = const <RestRollSlot, int>{},
    this.environment = const RestEnvironmentInput(),
    this.abilities = const RestAbilitySummary(),
    required this.effectiveAttributes,
    this.magicLeadAttribute = '',
    required this.magicEnabled,
    required this.maxLep,
    required this.maxAu,
    required this.maxAsp,
  });

  /// Gewählte Aktivität.
  final RestActivity activity;

  /// Stunden der kurzen Rast; Schlaf und Bettruhe verrechnen fest 8.
  final int requestedConditionHours;

  /// Ob die Bettruhe eine zweite Regenerationsphase anwendet.
  final bool applySecondPhase;

  /// Gewürfelte bzw. eingetragene Werte je Wurf.
  final Map<RestRollSlot, int> rolls;

  /// Äußere Umstände der Regeneration.
  final RestEnvironmentInput environment;

  /// Erkannte Rastfähigkeiten des Helden.
  final RestAbilitySummary abilities;

  /// Effektive Eigenschaften; KO und IN sind die Zielwerte der Proben.
  final Attributes effectiveAttributes;

  /// Leiteigenschaft für Meisterliche Regeneration.
  final String magicLeadAttribute;

  /// Ob Astralenergie aktiviert ist.
  final bool magicEnabled;

  /// Maximale Lebenspunkte.
  final int maxLep;

  /// Maximale Ausdauer.
  final int maxAu;

  /// Maximale Astralpunkte.
  final int maxAsp;

  /// Zielwert der KO-Proben.
  int get koTarget => effectiveAttributes.ko;

  /// Zielwert der IN-Proben.
  int get inTarget => effectiveAttributes.inn;

  /// Anzahl der Regenerationsphasen dieser Rast.
  int get regenerationPhases =>
      activity.regenerationPhases(applySecondPhase: applySecondPhase);
}

/// Die von einer Rast betroffenen Laufzeitwerte.
class RestVitals {
  /// Erzeugt einen Satz Rastwerte.
  const RestVitals({
    required this.currentLep,
    required this.currentAu,
    required this.currentAsp,
    required this.ueberanstrengung,
    required this.erschoepfung,
  });

  /// Liest die Rastwerte aus einem Laufzeitzustand.
  factory RestVitals.fromState(HeroState state) {
    return RestVitals(
      currentLep: state.currentLep,
      currentAu: state.currentAu,
      currentAsp: state.currentAsp,
      ueberanstrengung: state.ueberanstrengung,
      erschoepfung: state.erschoepfung,
    );
  }

  /// Aktuelle Lebenspunkte.
  final int currentLep;

  /// Aktuelle Ausdauer.
  final int currentAu;

  /// Aktuelle Astralpunkte.
  final int currentAsp;

  /// Überanstrengung.
  final int ueberanstrengung;

  /// Erschöpfung.
  final int erschoepfung;
}

/// Ergebnis einer Regenerationsphase samt tatsächlich gewonnener Punkte.
class RestPhaseOutcome {
  /// Erzeugt das Ergebnis einer Phase.
  const RestPhaseOutcome({
    required this.result,
    required this.lepGain,
    required this.aspGain,
  });

  /// Regelergebnis der Phase vor der Begrenzung auf das Maximum.
  final RestRecoveryPhaseResult result;

  /// Gewonnene LeP nach Begrenzung auf das Maximum.
  final int lepGain;

  /// Gewonnene AsP nach Begrenzung auf das Maximum.
  final int aspGain;
}

/// Gesamtergebnis einer Rast.
class RestOutcome {
  /// Erzeugt das Ergebnis einer Rast.
  const RestOutcome({
    required this.before,
    required this.after,
    this.au,
    this.conditions,
    this.phases = const <RestPhaseOutcome>[],
  });

  /// Rastwerte vor der Rast.
  final RestVitals before;

  /// Rastwerte nach der Rast.
  final RestVitals after;

  /// Ausdauerergebnis, falls die Aktivität Ausdauer regeneriert.
  final RestAuRecoveryResult? au;

  /// Zustandsabbau, falls die Aktivität Zustände abbaut.
  final RestConditionRecoveryResult? conditions;

  /// Ergebnisse der Regenerationsphasen in Reihenfolge.
  final List<RestPhaseOutcome> phases;
}

/// Liefert die Würfe, die bei dieser Rast zählen, in Protokollreihenfolge.
///
/// Ausruhen: Ausdauerwurf, KO-Probe. Je Regenerationsphase: LeP-Wurf,
/// KO-Probe und nur mit aktivierter Magie AsP-Wurf und IN-Probe.
List<RestRollSlot> applicableRestRollSlots(RestOutcomeInput input) {
  final slots = <RestRollSlot>[];
  if (input.activity.recoversAu) {
    slots
      ..add(RestRollSlot.auRoll)
      ..add(RestRollSlot.auKoProbe);
  }
  for (var phase = 0; phase < input.regenerationPhases; phase++) {
    final phaseSlots = kRestPhaseSlots[phase];
    slots
      ..add(phaseSlots.lep)
      ..add(phaseSlots.koProbe);
    if (input.magicEnabled) {
      slots
        ..add(phaseSlots.asp)
        ..add(phaseSlots.inProbe);
    }
  }
  return slots;
}

/// Berechnet das Ergebnis einer Rast ausgehend von [current].
///
/// Reihenfolge: Ausdauer, Zustandsabbau, dann die Regenerationsphasen, wobei
/// jede Phase auf der vorigen aufbaut. Gewonnene Punkte werden auf das
/// jeweilige Maximum begrenzt; ein Wert über dem Maximum sinkt dabei auf das
/// Maximum, ein negativer Wert steigt auf 0. Ein negatives Maximum gilt als 0.
RestOutcome computeRestOutcome({
  required RestOutcomeInput input,
  required RestVitals current,
}) {
  var nextLep = current.currentLep;
  var nextAu = current.currentAu;
  var nextAsp = current.currentAsp;
  var nextUeber = current.ueberanstrengung;
  var nextErsch = current.erschoepfung;
  final maxLep = math.max(0, input.maxLep);
  final maxAu = math.max(0, input.maxAu);
  final maxAsp = math.max(0, input.maxAsp);

  RestAuRecoveryResult? auResult;
  if (input.activity.recoversAu) {
    auResult = computeRestAuRecovery(
      currentAu: nextAu,
      maxAu: input.maxAu,
      baseRoll: input.rolls[RestRollSlot.auRoll] ?? 0,
      koProbeSucceeded: isRestProbeSuccessful(
        roll: input.rolls[RestRollSlot.auKoProbe],
        target: input.koTarget,
      ),
    );
    nextAu = (nextAu + auResult.recovered).clamp(0, maxAu);
  }

  RestConditionRecoveryResult? conditionResult;
  if (input.activity.reducesConditions) {
    conditionResult = computeConditionRecovery(
      currentUeberanstrengung: nextUeber,
      currentErschoepfung: nextErsch,
      hours: input.activity.conditionHours(input.requestedConditionHours),
      mode: input.activity.conditionMode,
    );
    nextUeber = conditionResult.remainingUeberanstrengung;
    nextErsch = conditionResult.remainingErschoepfung;
  }

  final phases = <RestPhaseOutcome>[];
  for (var phase = 0; phase < input.regenerationPhases; phase++) {
    final slots = kRestPhaseSlots[phase];
    final result = computeRestRecoveryPhase(
      abilities: input.abilities,
      effectiveAttributes: input.effectiveAttributes,
      environment: input.environment,
      lepRoll: input.rolls[slots.lep] ?? 0,
      aspRoll: input.rolls[slots.asp] ?? 0,
      koProbeSucceeded: isRestProbeSuccessful(
        roll: input.rolls[slots.koProbe],
        target: input.koTarget,
      ),
      inProbeSucceeded: isRestProbeSuccessful(
        roll: input.rolls[slots.inProbe],
        target: input.inTarget,
      ),
      magicLeadAttribute: input.magicLeadAttribute,
      magicEnabled: input.magicEnabled,
    );
    final lepGain = math.min(result.lepRecovered, maxLep - nextLep);
    final aspGain = math.min(result.aspRecovered, maxAsp - nextAsp);
    nextLep = (nextLep + lepGain).clamp(0, maxLep);
    nextAsp = (nextAsp + aspGain).clamp(0, maxAsp);
    phases.add(
      RestPhaseOutcome(result: result, lepGain: lepGain, aspGain: aspGain),
    );
  }

  return RestOutcome(
    before: current,
    after: RestVitals(
      currentLep: nextLep,
      currentAu: nextAu,
      currentAsp: nextAsp,
      ueberanstrengung: nextUeber,
      erschoepfung: nextErsch,
    ),
    au: auResult,
    conditions: conditionResult,
    phases: List<RestPhaseOutcome>.unmodifiable(phases),
  );
}

/// Übernimmt die Rastwerte aus [outcome] in [state].
///
/// Ersetzt ausschließlich LeP, Au, AsP, Überanstrengung und Erschöpfung;
/// alle übrigen Felder einschließlich unbekannter bleiben unverändert.
HeroState applyRestOutcome(HeroState state, RestOutcome outcome) {
  final after = outcome.after;
  return state.copyWith(
    currentLep: after.currentLep,
    currentAu: after.currentAu,
    currentAsp: after.currentAsp,
    ueberanstrengung: after.ueberanstrengung,
    erschoepfung: after.erschoepfung,
  );
}
