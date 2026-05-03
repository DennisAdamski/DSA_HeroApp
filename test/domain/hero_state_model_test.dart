import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

void main() {
  test('hero state roundtrip keeps exhaustion fields', () {
    const state = HeroState(
      currentLep: 12,
      currentAsp: 7,
      currentKap: 1,
      currentAu: 16,
      erschoepfung: 5,
      ueberanstrengung: 2,
    );

    final reloaded = HeroState.fromJson(state.toJson());

    expect(reloaded.schemaVersion, 6);
    expect(reloaded.erschoepfung, 5);
    expect(reloaded.ueberanstrengung, 2);
  });

  test('hero state backwards compatibility defaults new fields to zero', () {
    final loaded = HeroState.fromJson(const <String, dynamic>{
      'schemaVersion': 4,
      'currentLep': 10,
      'currentAsp': 3,
      'currentKap': 0,
      'currentAu': 12,
    });

    expect(loaded.erschoepfung, 0);
    expect(loaded.ueberanstrengung, 0);
  });

  group('diceLog', () {
    DiceLogEntry entry(int target) => DiceLogEntry(
      timestamp: DateTime.utc(2026, 4, 30, 8, target),
      type: ProbeType.attribute,
      title: 'Probe',
      subtitle: 'KL',
      success: true,
      diceValues: const [9],
      targetValue: target,
    );

    test('defaults to empty list', () {
      const state = HeroState(
        currentLep: 10,
        currentAsp: 0,
        currentKap: 0,
        currentAu: 10,
      );
      expect(state.diceLog, isEmpty);
    });

    test('schema v5 payload migrates with empty diceLog', () {
      final loaded = HeroState.fromJson(const <String, dynamic>{
        'schemaVersion': 5,
        'currentLep': 10,
        'currentAsp': 3,
        'currentKap': 0,
        'currentAu': 12,
      });

      expect(loaded.diceLog, isEmpty);
    });

    test('roundtrip preserves diceLog entries', () {
      final state = HeroState(
        currentLep: 10,
        currentAsp: 0,
        currentKap: 0,
        currentAu: 10,
        diceLog: [entry(11), entry(12)],
      );

      final reloaded = HeroState.fromJson(state.toJson());

      expect(reloaded.diceLog, hasLength(2));
      expect(reloaded.diceLog.first.targetValue, 11);
      expect(reloaded.diceLog.last.targetValue, 12);
    });

    test('withAppendedDiceLog appends to the end', () {
      final state = HeroState(
        currentLep: 10,
        currentAsp: 0,
        currentKap: 0,
        currentAu: 10,
        diceLog: [entry(1), entry(2)],
      );

      final updated = state.withAppendedDiceLog(entry(3));

      expect(updated.diceLog, hasLength(3));
      expect(updated.diceLog.last.targetValue, 3);
    });

    test('withAppendedDiceLog trims FIFO at diceLogMax', () {
      final entries = List<DiceLogEntry>.generate(
        HeroState.diceLogMax,
        (i) => entry(i + 1),
      );
      final state = HeroState(
        currentLep: 10,
        currentAsp: 0,
        currentKap: 0,
        currentAu: 10,
        diceLog: entries,
      );

      final updated = state.withAppendedDiceLog(entry(99));

      expect(updated.diceLog, hasLength(HeroState.diceLogMax));
      expect(
        updated.diceLog.first.targetValue,
        2,
        reason: 'oldest entry (target=1) must be dropped',
      );
      expect(
        updated.diceLog.last.targetValue,
        99,
        reason: 'new entry must be at the end',
      );
    });

    test('withAppendedDiceLogEntries appends a batch and trims FIFO', () {
      final entries = List<DiceLogEntry>.generate(
        HeroState.diceLogMax - 1,
        (i) => entry(i + 1),
      );
      final state = HeroState(
        currentLep: 10,
        currentAsp: 0,
        currentKap: 0,
        currentAu: 10,
        diceLog: entries,
      );

      final updated = state.withAppendedDiceLogEntries([entry(98), entry(99)]);

      expect(updated.diceLog, hasLength(HeroState.diceLogMax));
      expect(updated.diceLog.first.targetValue, 2);
      expect(updated.diceLog.last.targetValue, 99);
    });

    test('copyWith preserves existing diceLog when not provided', () {
      final state = HeroState(
        currentLep: 10,
        currentAsp: 0,
        currentKap: 0,
        currentAu: 10,
        diceLog: [entry(7)],
      );

      final updated = state.copyWith(currentLep: 9);

      expect(updated.diceLog, hasLength(1));
      expect(updated.diceLog.first.targetValue, 7);
    });

    test('copyWith replaces diceLog when explicitly provided', () {
      final state = HeroState(
        currentLep: 10,
        currentAsp: 0,
        currentKap: 0,
        currentAu: 10,
        diceLog: [entry(7)],
      );

      final updated = state.copyWith(diceLog: const <DiceLogEntry>[]);

      expect(updated.diceLog, isEmpty);
    });
  });
}
