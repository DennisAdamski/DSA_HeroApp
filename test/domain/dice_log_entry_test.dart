import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

void main() {
  group('DiceLogEntry', () {
    test('roundtrip preserves all fields', () {
      final ts = DateTime.utc(2026, 4, 30, 8, 2, 15);
      final entry = DiceLogEntry(
        timestamp: ts,
        type: ProbeType.attribute,
        title: 'Probe · KL',
        subtitle: 'Eigenschaftsprobe ≤ 12',
        targetValue: 12,
        success: true,
        automaticOutcome: AutomaticOutcome.none,
        diceValues: const [9],
        total: null,
      );

      final reloaded = DiceLogEntry.fromJson(entry.toJson());

      expect(reloaded.timestamp, ts);
      expect(reloaded.type, ProbeType.attribute);
      expect(reloaded.title, 'Probe · KL');
      expect(reloaded.subtitle, 'Eigenschaftsprobe ≤ 12');
      expect(reloaded.targetValue, 12);
      expect(reloaded.success, isTrue);
      expect(reloaded.automaticOutcome, AutomaticOutcome.none);
      expect(reloaded.diceValues, const [9]);
      expect(reloaded.total, isNull);
    });

    test('roundtrip handles null targetValue and a damage total', () {
      final ts = DateTime.utc(2026, 4, 30, 12, 0, 0);
      final entry = DiceLogEntry(
        timestamp: ts,
        type: ProbeType.damage,
        title: 'Schaden: Langschwert',
        subtitle: '1W6+4',
        targetValue: null,
        success: true,
        automaticOutcome: AutomaticOutcome.none,
        diceValues: const [3],
        total: 7,
      );

      final reloaded = DiceLogEntry.fromJson(entry.toJson());

      expect(reloaded.targetValue, isNull);
      expect(reloaded.total, 7);
      expect(reloaded.type, ProbeType.damage);
    });

    test('roundtrip preserves automatic failure outcome', () {
      final entry = DiceLogEntry(
        timestamp: DateTime.utc(2026, 4, 30),
        type: ProbeType.attribute,
        title: 'Probe · MU',
        subtitle: 'Eigenschaftsprobe ≤ 14',
        targetValue: 14,
        success: false,
        automaticOutcome: AutomaticOutcome.failure,
        diceValues: const [20],
        total: null,
      );

      final reloaded = DiceLogEntry.fromJson(entry.toJson());

      expect(reloaded.automaticOutcome, AutomaticOutcome.failure);
      expect(reloaded.success, isFalse);
    });

    test('fromJson is robust against missing optional fields', () {
      final reloaded = DiceLogEntry.fromJson(<String, dynamic>{
        'timestamp': '2026-04-30T08:02:15.000Z',
        'type': 'attribute',
        'title': 'Probe · KL',
        'subtitle': 'Eigenschaftsprobe ≤ 12',
        'success': true,
        'diceValues': [9],
      });

      expect(reloaded.targetValue, isNull);
      expect(reloaded.total, isNull);
      expect(reloaded.automaticOutcome, AutomaticOutcome.none);
      expect(reloaded.isNeutral, isFalse);
    });

    test('roundtrip preserves neutral generic roll entries', () {
      final entry = DiceLogEntry(
        timestamp: DateTime.utc(2026, 4, 30, 13, 0, 0),
        type: ProbeType.genericRoll,
        title: 'Trefferzone',
        subtitle: 'Kopf',
        success: true,
        diceValues: const [4],
        total: 4,
        isNeutral: true,
      );

      final reloaded = DiceLogEntry.fromJson(entry.toJson());

      expect(reloaded.type, ProbeType.genericRoll);
      expect(reloaded.isNeutral, isTrue);
      expect(reloaded.total, 4);
    });
  });

  group('buchungId (ARCH-06)', () {
    test('wird nur geschrieben, wenn gesetzt, und übersteht JSON', () {
      final ohne = diceLogEntryFromRoll(
        title: 'Wurf',
        subtitle: '',
        diceValues: const <int>[3],
      );
      final mit = diceLogEntryFromRoll(
        title: 'Schaden erhalten',
        subtitle: '',
        diceValues: const <int>[],
        type: ProbeType.damage,
        total: 7,
        buchungId: 'treffer-1',
      );

      expect(ohne.toJson().containsKey('buchungId'), isFalse);
      expect(DiceLogEntry.fromJson(ohne.toJson()).buchungId, isNull);
      expect(DiceLogEntry.fromJson(mit.toJson()).buchungId, 'treffer-1');
    });
  });

  group('Zielwerte und Restpunkte (SPIEL-05)', () {
    ProbeResult talentErgebnis({required bool success, required int rest}) {
      const request = ResolvedProbeRequest(
        type: ProbeType.talent,
        title: 'Talentprobe: Menschenkenntnis',
        subtitle: 'KL/IN/CH',
        ruleHint: 'hint',
        diceSpec: DiceSpec(count: 3, sides: 20),
        targets: <ProbeTargetValue>[
          ProbeTargetValue(label: 'KL', value: 13),
          ProbeTargetValue(label: 'IN', value: 12),
          ProbeTargetValue(label: 'CH', value: 14),
        ],
      );
      return ProbeResult(
        request: request,
        input: const ProbeRollInput(
          mode: ProbeRollMode.digital,
          diceValues: <int>[9, 15, 5],
          situationalModifier: 0,
          specializationApplied: false,
        ),
        diceValues: const <int>[9, 15, 5],
        effectiveTargetValues: const <int>[13, 12, 14],
        targetOverflows: const <int>[0, 3, 0],
        compensationPoolStart: 5,
        remainingPool: rest,
        appliedAttributePenalty: 0,
        total: 29,
        success: success,
        automaticOutcome: AutomaticOutcome.none,
        specialExperience: false,
        usedFixedRollTotal: false,
      );
    }

    test('eine 3W20-Probe hält alle Zielwerte und die TaP* fest', () {
      final entry = diceLogEntryFromResult(
        talentErgebnis(success: true, rest: 2),
      );

      expect(entry.zielwerte, const [13, 12, 14]);
      expect(entry.restpunkte, 2);
      // Das Einzelziel bleibt für ältere Leser erhalten.
      expect(entry.targetValue, 13);
    });

    test('Zielwerte und Restpunkte überstehen JSON', () {
      final entry = diceLogEntryFromResult(
        talentErgebnis(success: false, rest: -2),
      );
      final neu = DiceLogEntry.fromJson(entry.toJson());

      expect(neu.zielwerte, const [13, 12, 14]);
      expect(neu.restpunkte, -2);
    });

    test('bei Einzelwurf bleiben beide Felder leer und fehlen im JSON', () {
      // Hash-Schutz: Bestandseinträge ändern sich im JSON nicht.
      final einfach = diceLogEntryFromSimpleCheck(
        title: 'Eigenschaftsprobe: MU',
        subtitle: 'MU',
        roll: 7,
        targetValue: 12,
      );
      expect(einfach.zielwerte, isEmpty);
      expect(einfach.restpunkte, isNull);
      expect(einfach.toJson().containsKey('zielwerte'), isFalse);
      expect(einfach.toJson().containsKey('restpunkte'), isFalse);

      const alt = <String, dynamic>{
        'timestamp': '2026-04-30T08:02:15.000Z',
        'type': 'talent',
        'title': 'Talentprobe: X',
        'subtitle': '',
        'success': true,
        'diceValues': <int>[1, 2, 3],
        'targetValue': 10,
        'automaticOutcome': 'none',
      };
      final geladen = DiceLogEntry.fromJson(alt);
      expect(geladen.zielwerte, isEmpty);
      expect(geladen.restpunkte, isNull);
      expect(geladen.toJson().containsKey('zielwerte'), isFalse);
    });

    test('ein Summenwurf bekommt keine Restpunkte', () {
      final entry = diceLogEntryFromRoll(
        title: 'Wurf',
        subtitle: '',
        diceValues: const <int>[3, 4, 5],
      );
      expect(entry.restpunkte, isNull);
      expect(entry.zielwerte, isEmpty);
    });
  });

  group('diceLogEntryFromResult', () {
    test('maps ProbeResult of an attribute check', () {
      const request = ResolvedProbeRequest(
        type: ProbeType.attribute,
        title: 'Eigenschaftsprobe: KL',
        subtitle: 'KL',
        ruleHint: 'hint',
        diceSpec: DiceSpec(count: 1, sides: 20),
        targets: <ProbeTargetValue>[ProbeTargetValue(label: 'KL', value: 12)],
      );
      const input = ProbeRollInput(
        mode: ProbeRollMode.digital,
        diceValues: <int>[9],
        situationalModifier: 0,
        specializationApplied: false,
      );
      const result = ProbeResult(
        request: request,
        input: input,
        diceValues: <int>[9],
        effectiveTargetValues: <int>[12],
        targetOverflows: <int>[0],
        compensationPoolStart: 0,
        remainingPool: 0,
        appliedAttributePenalty: 0,
        total: 9,
        success: true,
        automaticOutcome: AutomaticOutcome.none,
        specialExperience: false,
        usedFixedRollTotal: false,
      );

      final entry = diceLogEntryFromResult(result);

      expect(entry.type, ProbeType.attribute);
      expect(entry.title, 'Eigenschaftsprobe: KL');
      expect(entry.subtitle, 'KL');
      expect(entry.targetValue, 12);
      expect(entry.success, isTrue);
      expect(entry.automaticOutcome, AutomaticOutcome.none);
      expect(entry.diceValues, const [9]);
      expect(
        entry.total,
        isNull,
        reason: 'binary attribute checks do not carry a meaningful total',
      );
    });

    test('maps ProbeResult of an initiative roll with a total', () {
      const request = ResolvedProbeRequest(
        type: ProbeType.initiative,
        title: 'Initiative',
        subtitle: '1W6+12',
        ruleHint: 'hint',
        diceSpec: DiceSpec(count: 1, sides: 6, modifier: 12),
        targets: <ProbeTargetValue>[],
      );
      const input = ProbeRollInput(
        mode: ProbeRollMode.digital,
        diceValues: <int>[4],
        situationalModifier: 0,
        specializationApplied: false,
      );
      const result = ProbeResult(
        request: request,
        input: input,
        diceValues: <int>[4],
        effectiveTargetValues: <int>[],
        targetOverflows: <int>[],
        compensationPoolStart: 0,
        remainingPool: 0,
        appliedAttributePenalty: 0,
        total: 16,
        success: true,
        automaticOutcome: AutomaticOutcome.none,
        specialExperience: false,
        usedFixedRollTotal: false,
      );

      final entry = diceLogEntryFromResult(result);

      expect(entry.type, ProbeType.initiative);
      expect(entry.targetValue, isNull);
      expect(entry.total, 16);
      expect(entry.isNeutral, isTrue);
    });

    test('maps simple neutral roll with computed total', () {
      final entry = diceLogEntryFromRoll(
        title: 'Extraschaden',
        subtitle: '2W6+1',
        diceValues: const [2, 5],
        diceSpec: const DiceSpec(count: 2, sides: 6, modifier: 1),
      );

      expect(entry.type, ProbeType.genericRoll);
      expect(entry.isNeutral, isTrue);
      expect(entry.diceValues, const [2, 5]);
      expect(entry.total, 8);
    });

    test('maps simple W20 check with automatic outcomes', () {
      final entry = diceLogEntryFromSimpleCheck(
        title: 'Rast: KO-Probe',
        subtitle: 'Zielwert 12',
        roll: 20,
        targetValue: 12,
      );

      expect(entry.success, isFalse);
      expect(entry.targetValue, 12);
      expect(entry.automaticOutcome, AutomaticOutcome.failure);
      expect(entry.isNeutral, isFalse);
    });
  });
}
