import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/begleiter_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/zustands_buchung.dart';

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

  group('lastModified', () {
    test('roundtrip keeps the timestamp in UTC', () {
      final state = HeroState(
        currentLep: 12,
        currentAsp: 7,
        currentKap: 1,
        currentAu: 16,
        lastModified: DateTime.utc(2026, 8, 20, 10, 30),
      );

      final reloaded = HeroState.fromJson(state.toJson());

      expect(reloaded.lastModified, DateTime.utc(2026, 8, 20, 10, 30));
    });

    test('is omitted from json when unset', () {
      const state = HeroState(
        currentLep: 10,
        currentAsp: 0,
        currentKap: 0,
        currentAu: 10,
      );

      expect(state.toJson().containsKey('lastModified'), isFalse);
      expect(HeroState.fromJson(state.toJson()).lastModified, isNull);
    });

    test('stays null for older data without the field', () {
      final loaded = HeroState.fromJson(const <String, dynamic>{
        'schemaVersion': 4,
        'currentLep': 10,
        'currentAsp': 3,
        'currentKap': 0,
        'currentAu': 12,
      });

      expect(loaded.lastModified, isNull);
    });

    test('copyWith replaces the timestamp', () {
      const state = HeroState(
        currentLep: 10,
        currentAsp: 0,
        currentKap: 0,
        currentAu: 10,
      );

      final stamped = state.copyWith(
        lastModified: DateTime.utc(2026, 8, 20, 11),
      );

      expect(stamped.lastModified, DateTime.utc(2026, 8, 20, 11));
      expect(stamped.currentLep, 10);
    });
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

  group('buchungen (ARCH-06)', () {
    const zustand = HeroState(
      currentLep: 10,
      currentAsp: 0,
      currentKap: 0,
      currentAu: 10,
    );

    ZustandsBuchung buchung(String id) => ZustandsBuchung(
      id: id,
      art: ZustandsBuchungsArt.schaden,
      zeitpunkt: DateTime.utc(2026, 10, 7),
      lepDelta: -3,
    );

    test('ohne Buchungen entsteht kein Schlüssel (Inhalts-Hash)', () {
      expect(zustand.toJson().containsKey('buchungen'), isFalse);
      expect(
        HeroState.fromJson(zustand.toJson()).toJson().containsKey('buchungen'),
        isFalse,
      );
    });

    test('Buchungen überstehen JSON und bleiben in der Reihenfolge', () {
      final mit = zustand.withBuchung(buchung('a')).withBuchung(buchung('b'));
      final geladen = HeroState.fromJson(mit.toJson());

      expect(geladen.buchungen.map((b) => b.id), ['a', 'b']);
      expect(geladen.buchungen.first.lepDelta, -3);
      expect(geladen.copyWith(currentLep: 4).buchungen, hasLength(2));
    });

    test('verdrängt die ältesten über dem Maximum', () {
      var voll = zustand;
      for (var i = 0; i <= HeroState.buchungenMax; i++) {
        voll = voll.withBuchung(buchung('b$i'));
      }

      expect(voll.buchungen, hasLength(HeroState.buchungenMax));
      expect(voll.buchungen.first.id, 'b1');
    });
  });

  group('begleiterZustaende (V2)', () {
    const zustand = HeroState(
      currentLep: 10,
      currentAsp: 0,
      currentKap: 0,
      currentAu: 10,
    );

    test('ohne Begleiterwerte entsteht kein Schlüssel (Inhalts-Hash)', () {
      expect(zustand.toJson().containsKey('begleiterZustaende'), isFalse);
      expect(
        HeroState.fromJson(zustand.toJson())
            .toJson()
            .containsKey('begleiterZustaende'),
        isFalse,
      );
    });

    test('Werte überstehen JSON; null bleibt „voll“ und entfällt', () {
      final mit = zustand.withBegleiterZustand(
        'mira',
        const BegleiterZustand(currentLep: 4, currentAup: 9),
      );
      final json = mit.toJson()['begleiterZustaende'] as Map;
      expect(json, {
        'mira': {'currentLep': 4, 'currentAup': 9},
      });
      final geladen = HeroState.fromJson(mit.toJson());
      expect(geladen.begleiterZustaende['mira']!.currentLep, 4);
      expect(geladen.begleiterZustaende['mira']!.currentAsp, isNull);
      expect(geladen.copyWith(currentLep: 1).begleiterZustaende, hasLength(1));
    });

    test('ein leerer Zustand entfernt den Eintrag', () {
      final mit = zustand.withBegleiterZustand(
        'mira',
        const BegleiterZustand(currentLep: 4),
      );
      final leer = mit.withBegleiterZustand('mira', const BegleiterZustand());
      expect(leer.begleiterZustaende, isEmpty);
      expect(leer.toJson().containsKey('begleiterZustaende'), isFalse);
    });

    test('Zukunftsfelder im Eintrag bleiben erhalten', () {
      final json = zustand.toJson()
        ..['begleiterZustaende'] = {
          'mira': {'currentLep': 4, 'wunden': 2},
        };
      final geladen = HeroState.fromJson(json);
      final zurueck = geladen
          .withBegleiterZustand(
            'mira',
            geladen.begleiterZustaende['mira']!.copyWith(currentLep: 3),
          )
          .toJson();
      expect((zurueck['begleiterZustaende'] as Map)['mira'], {
        'currentLep': 3,
        'wunden': 2,
      });
    });
  });
}
