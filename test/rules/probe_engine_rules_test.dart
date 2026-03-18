import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';

class _FixedDiceRoller implements DiceRoller {
  _FixedDiceRoller(this._values);

  final List<int> _values;
  var _index = 0;

  @override
  int rollDie(int sides) {
    final value = _values[_index];
    _index++;
    return value;
  }
}

void main() {
  test('attribute probe treats 1 as automatic success', () {
    const request = ResolvedProbeRequest(
      type: ProbeType.attribute,
      title: 'MU',
      subtitle: 'Mut',
      ruleHint: 'rule',
      diceSpec: DiceSpec(count: 1, sides: 20),
      targets: <ProbeTargetValue>[ProbeTargetValue(label: 'MU', value: 3)],
    );

    final input = createDigitalProbeRollInput(
      request,
      roller: _FixedDiceRoller(<int>[1]),
    );
    final result = evaluateProbe(request, input);

    expect(result.success, isTrue);
    expect(result.automaticOutcome, AutomaticOutcome.success);
  });

  test('attribute probe treats 20 as automatic failure', () {
    const request = ResolvedProbeRequest(
      type: ProbeType.attribute,
      title: 'MU',
      subtitle: 'Mut',
      ruleHint: 'rule',
      diceSpec: DiceSpec(count: 1, sides: 20),
      targets: <ProbeTargetValue>[ProbeTargetValue(label: 'MU', value: 19)],
    );

    final input = createDigitalProbeRollInput(
      request,
      roller: _FixedDiceRoller(<int>[20]),
    );
    final result = evaluateProbe(request, input);

    expect(result.success, isFalse);
    expect(result.automaticOutcome, AutomaticOutcome.failure);
  });

  test('talent probe compensates overflows from the pool', () {
    const request = ResolvedProbeRequest(
      type: ProbeType.talent,
      title: 'Athletik',
      subtitle: 'MU / GE / KK',
      ruleHint: 'rule',
      diceSpec: DiceSpec(count: 3, sides: 20),
      targets: <ProbeTargetValue>[
        ProbeTargetValue(label: 'MU', value: 13),
        ProbeTargetValue(label: 'GE', value: 14),
        ProbeTargetValue(label: 'KK', value: 12),
      ],
      basePool: 7,
    );

    const input = ProbeRollInput(
      mode: ProbeRollMode.manual,
      diceValues: <int>[15, 14, 12],
      situationalModifier: 0,
      specializationApplied: false,
    );
    final result = evaluateProbe(request, input);

    expect(result.success, isTrue);
    expect(result.compensationPoolStart, 7);
    expect(result.remainingPool, 5);
  });

  test('talent probe shifts negative pool into attribute penalty', () {
    const request = ResolvedProbeRequest(
      type: ProbeType.talent,
      title: 'Athletik',
      subtitle: 'MU / GE / KK',
      ruleHint: 'rule',
      diceSpec: DiceSpec(count: 3, sides: 20),
      targets: <ProbeTargetValue>[
        ProbeTargetValue(label: 'MU', value: 13),
        ProbeTargetValue(label: 'GE', value: 13),
        ProbeTargetValue(label: 'KK', value: 13),
      ],
      basePool: 3,
    );

    const input = ProbeRollInput(
      mode: ProbeRollMode.manual,
      diceValues: <int>[12, 12, 12],
      situationalModifier: -5,
      specializationApplied: false,
    );
    final result = evaluateProbe(request, input);

    expect(result.compensationPoolStart, 0);
    expect(result.appliedAttributePenalty, -2);
    expect(result.effectiveTargetValues, const <int>[11, 11, 11]);
    expect(result.success, isFalse);
  });

  test('talent probe fails automatically on double 20', () {
    const request = ResolvedProbeRequest(
      type: ProbeType.talent,
      title: 'Athletik',
      subtitle: 'MU / GE / KK',
      ruleHint: 'rule',
      diceSpec: DiceSpec(count: 3, sides: 20),
      targets: <ProbeTargetValue>[
        ProbeTargetValue(label: 'MU', value: 20),
        ProbeTargetValue(label: 'GE', value: 20),
        ProbeTargetValue(label: 'KK', value: 20),
      ],
      basePool: 99,
    );

    const input = ProbeRollInput(
      mode: ProbeRollMode.manual,
      diceValues: <int>[20, 20, 1],
      situationalModifier: 0,
      specializationApplied: false,
    );
    final result = evaluateProbe(request, input);

    expect(result.success, isFalse);
    expect(result.automaticOutcome, AutomaticOutcome.failure);
  });

  test('talent probe succeeds automatically on double 1 and grants SE', () {
    const request = ResolvedProbeRequest(
      type: ProbeType.talent,
      title: 'Athletik',
      subtitle: 'MU / GE / KK',
      ruleHint: 'rule',
      diceSpec: DiceSpec(count: 3, sides: 20),
      targets: <ProbeTargetValue>[
        ProbeTargetValue(label: 'MU', value: 1),
        ProbeTargetValue(label: 'GE', value: 1),
        ProbeTargetValue(label: 'KK', value: 1),
      ],
      basePool: 0,
    );

    const input = ProbeRollInput(
      mode: ProbeRollMode.manual,
      diceValues: <int>[1, 1, 20],
      situationalModifier: 0,
      specializationApplied: false,
    );
    final result = evaluateProbe(request, input);

    expect(result.success, isTrue);
    expect(result.automaticOutcome, AutomaticOutcome.success);
    expect(result.specialExperience, isTrue);
  });

  test('spell probe uses the same compensation logic as talent probes', () {
    const request = ResolvedProbeRequest(
      type: ProbeType.spell,
      title: 'Axxeleratus',
      subtitle: 'KL / GE / KO',
      ruleHint: 'rule',
      diceSpec: DiceSpec(count: 3, sides: 20),
      targets: <ProbeTargetValue>[
        ProbeTargetValue(label: 'KL', value: 12),
        ProbeTargetValue(label: 'GE', value: 12),
        ProbeTargetValue(label: 'KO', value: 12),
      ],
      basePool: 5,
    );

    const input = ProbeRollInput(
      mode: ProbeRollMode.manual,
      diceValues: <int>[12, 14, 13],
      situationalModifier: 0,
      specializationApplied: false,
    );
    final result = evaluateProbe(request, input);

    expect(result.success, isTrue);
    expect(result.remainingPool, 2);
  });

  test('combat probe uses normal <= evaluation without automatic outcomes', () {
    const request = ResolvedProbeRequest(
      type: ProbeType.combatAttack,
      title: 'AT',
      subtitle: 'Kampf',
      ruleHint: 'rule',
      diceSpec: DiceSpec(count: 1, sides: 20),
      targets: <ProbeTargetValue>[ProbeTargetValue(label: 'AT', value: 14)],
    );

    const input = ProbeRollInput(
      mode: ProbeRollMode.manual,
      diceValues: <int>[14],
      situationalModifier: 0,
      specializationApplied: false,
    );
    final result = evaluateProbe(request, input);

    expect(result.success, isTrue);
    expect(result.automaticOutcome, AutomaticOutcome.none);
  });

  test('initiative probe supports fixed totals for Aufmerksamkeit', () {
    const request = ResolvedProbeRequest(
      type: ProbeType.initiative,
      title: 'INI',
      subtitle: 'Aufmerksamkeit',
      ruleHint: 'rule',
      diceSpec: DiceSpec(count: 1, sides: 6),
      targets: <ProbeTargetValue>[],
      fixedRollTotal: 6,
    );

    const input = ProbeRollInput(
      mode: ProbeRollMode.digital,
      diceValues: <int>[],
      situationalModifier: 0,
      specializationApplied: false,
    );
    final result = evaluateProbe(request, input);

    expect(result.total, 6);
    expect(result.usedFixedRollTotal, isTrue);
  });

  test('damage probe sums dice and flat modifier', () {
    const request = ResolvedProbeRequest(
      type: ProbeType.damage,
      title: 'TP',
      subtitle: '1W6+4',
      ruleHint: 'rule',
      diceSpec: DiceSpec(count: 1, sides: 6, modifier: 4),
      targets: <ProbeTargetValue>[],
    );

    final input = createDigitalProbeRollInput(
      request,
      roller: _FixedDiceRoller(<int>[5]),
    );
    final result = evaluateProbe(request, input);

    expect(result.total, 9);
  });
}
