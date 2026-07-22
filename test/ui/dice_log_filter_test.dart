import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_dice_log_section.dart';

DiceLogEntry _entry(ProbeType type) {
  return DiceLogEntry(
    timestamp: DateTime.utc(2026, 7, 12),
    type: type,
    title: 'Test',
    subtitle: '',
    success: true,
    diceValues: const <int>[10],
  );
}

void main() {
  group('DiceLogFilter.matches', () {
    test('all akzeptiert jeden Eintrag', () {
      for (final type in ProbeType.values) {
        expect(DiceLogFilter.all.matches(_entry(type)), isTrue);
      }
    });

    test('attribute/talent/spell matchen nur ihre Probeart', () {
      expect(
        DiceLogFilter.attribute.matches(_entry(ProbeType.attribute)),
        isTrue,
      );
      expect(DiceLogFilter.attribute.matches(_entry(ProbeType.talent)), isFalse);
      expect(DiceLogFilter.talent.matches(_entry(ProbeType.talent)), isTrue);
      expect(DiceLogFilter.talent.matches(_entry(ProbeType.spell)), isFalse);
      expect(DiceLogFilter.spell.matches(_entry(ProbeType.spell)), isTrue);
      expect(DiceLogFilter.spell.matches(_entry(ProbeType.attribute)), isFalse);
    });

    test('combat buendelt alle kampfbezogenen Wuerfe', () {
      const combatTypes = <ProbeType>[
        ProbeType.combatAttack,
        ProbeType.combatParry,
        ProbeType.dodge,
        ProbeType.initiative,
        ProbeType.damage,
      ];
      for (final type in combatTypes) {
        expect(DiceLogFilter.combat.matches(_entry(type)), isTrue);
      }
      expect(DiceLogFilter.combat.matches(_entry(ProbeType.talent)), isFalse);
      expect(
        DiceLogFilter.combat.matches(_entry(ProbeType.genericRoll)),
        isFalse,
      );
    });
  });
}
