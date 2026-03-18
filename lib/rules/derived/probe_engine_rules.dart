import 'dart:math';

import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

/// Abstraktion ueber die Zufallsquelle der Wuerfel-Engine.
abstract interface class DiceRoller {
  /// Liefert einen Wurf im Bereich `1..sides`.
  int rollDie(int sides);
}

/// Standard-Zufallsquelle auf Basis von `dart:math`.
class RandomDiceRoller implements DiceRoller {
  /// Erzeugt einen Wuerfler mit optionaler Random-Instanz.
  RandomDiceRoller([Random? random]) : _random = random ?? Random();

  final Random _random;

  @override
  int rollDie(int sides) {
    final normalizedSides = sides < 1 ? 1 : sides;
    return _random.nextInt(normalizedSides) + 1;
  }
}

/// Erzeugt eine digitale Wurfeingabe fuer eine Probe.
ProbeRollInput createDigitalProbeRollInput(
  ResolvedProbeRequest request, {
  DiceRoller? roller,
  int? situationalModifier,
  bool? specializationApplied,
}) {
  final activeRoller = roller ?? RandomDiceRoller();
  final values = <int>[];
  if (request.fixedRollTotal == null) {
    for (var index = 0; index < request.diceSpec.count; index++) {
      values.add(activeRoller.rollDie(request.diceSpec.sides));
    }
  }
  return ProbeRollInput(
    mode: ProbeRollMode.digital,
    diceValues: List<int>.unmodifiable(values),
    situationalModifier:
        situationalModifier ?? request.initialSituationalModifier,
    specializationApplied:
        specializationApplied ?? request.initialSpecializationApplied,
  );
}

/// Validiert eine manuelle Wurfeingabe fuer die gegebene Probe.
bool isValidManualProbeInput(
  ResolvedProbeRequest request,
  ProbeRollInput input,
) {
  if (request.fixedRollTotal != null) {
    return input.diceValues.isEmpty;
  }
  if (input.diceValues.length != request.diceSpec.count) {
    return false;
  }
  for (final value in input.diceValues) {
    if (value < 1 || value > request.diceSpec.sides) {
      return false;
    }
  }
  return true;
}

/// Wertet eine vollstaendig aufgeloeste Probe gegen eine Wurfeingabe aus.
ProbeResult evaluateProbe(
  ResolvedProbeRequest request,
  ProbeRollInput input,
) {
  if (!isValidManualProbeInput(request, input)) {
    throw ArgumentError('Ungueltige Wurfeingabe fuer ${request.title}.');
  }

  if (request.usesCompensationPool) {
    return _evaluateCompensationProbe(request, input);
  }
  if (request.usesBinaryCheck) {
    return _evaluateBinaryProbe(request, input);
  }
  return _evaluateSummedProbe(request, input);
}

ProbeResult _evaluateBinaryProbe(
  ResolvedProbeRequest request,
  ProbeRollInput input,
) {
  final target = request.targets.isEmpty ? 0 : request.targets.first.value;
  final effectiveTarget = target + input.situationalModifier;
  final roll = input.diceValues.first;
  var automaticOutcome = AutomaticOutcome.none;
  var success = roll <= effectiveTarget;

  if (request.type == ProbeType.attribute) {
    if (roll == 1) {
      automaticOutcome = AutomaticOutcome.success;
      success = true;
    } else if (roll == request.diceSpec.sides) {
      automaticOutcome = AutomaticOutcome.failure;
      success = false;
    }
  }

  return ProbeResult(
    request: request,
    input: input,
    diceValues: List<int>.unmodifiable(input.diceValues),
    effectiveTargetValues: <int>[effectiveTarget],
    targetOverflows: <int>[_overflow(roll, effectiveTarget)],
    compensationPoolStart: 0,
    remainingPool: 0,
    appliedAttributePenalty: 0,
    total: roll,
    success: success,
    automaticOutcome: automaticOutcome,
    specialExperience: false,
    usedFixedRollTotal: false,
  );
}

ProbeResult _evaluateCompensationProbe(
  ResolvedProbeRequest request,
  ProbeRollInput input,
) {
  final specializationBonus = input.specializationApplied
      ? request.specializationBonus
      : 0;
  final rawPool =
      request.basePool + specializationBonus + input.situationalModifier;
  final appliedPenalty = rawPool < 0 ? rawPool : 0;
  final compensationPoolStart = rawPool < 0 ? 0 : rawPool;
  final effectiveTargets = request.targets
      .map((target) => target.value + appliedPenalty)
      .toList(growable: false);
  final overflows = <int>[];
  var overflowSum = 0;
  for (var index = 0; index < input.diceValues.length; index++) {
    final roll = input.diceValues[index];
    final target = index < effectiveTargets.length ? effectiveTargets[index] : 0;
    final overflow = _overflow(roll, target);
    overflows.add(overflow);
    overflowSum += overflow;
  }

  final ones = input.diceValues.where((value) => value == 1).length;
  final twenties = input.diceValues
      .where((value) => value == request.diceSpec.sides)
      .length;

  var automaticOutcome = AutomaticOutcome.none;
  var success = overflowSum <= compensationPoolStart;
  var specialExperience = false;
  if (twenties >= 2) {
    automaticOutcome = AutomaticOutcome.failure;
    success = false;
  } else if (ones >= 2) {
    automaticOutcome = AutomaticOutcome.success;
    success = true;
    specialExperience = true;
  }

  final remainingPool = success && automaticOutcome != AutomaticOutcome.failure
      ? compensationPoolStart - overflowSum
      : compensationPoolStart - overflowSum;

  return ProbeResult(
    request: request,
    input: input,
    diceValues: List<int>.unmodifiable(input.diceValues),
    effectiveTargetValues: List<int>.unmodifiable(effectiveTargets),
    targetOverflows: List<int>.unmodifiable(overflows),
    compensationPoolStart: compensationPoolStart,
    remainingPool: remainingPool,
    appliedAttributePenalty: appliedPenalty,
    total: input.diceValues.fold<int>(0, (sum, value) => sum + value),
    success: success,
    automaticOutcome: automaticOutcome,
    specialExperience: specialExperience,
    usedFixedRollTotal: false,
  );
}

ProbeResult _evaluateSummedProbe(
  ResolvedProbeRequest request,
  ProbeRollInput input,
) {
  final total = request.fixedRollTotal != null
      ? request.fixedRollTotal! +
            request.diceSpec.modifier +
            input.situationalModifier
      : input.diceValues.fold<int>(0, (sum, value) => sum + value) +
            request.diceSpec.modifier +
            input.situationalModifier;

  return ProbeResult(
    request: request,
    input: input,
    diceValues: List<int>.unmodifiable(input.diceValues),
    effectiveTargetValues: const <int>[],
    targetOverflows: const <int>[],
    compensationPoolStart: 0,
    remainingPool: 0,
    appliedAttributePenalty: 0,
    total: total,
    success: true,
    automaticOutcome: AutomaticOutcome.none,
    specialExperience: false,
    usedFixedRollTotal: request.fixedRollTotal != null,
  );
}

int _overflow(int roll, int target) {
  final overflow = roll - target;
  return overflow > 0 ? overflow : 0;
}
