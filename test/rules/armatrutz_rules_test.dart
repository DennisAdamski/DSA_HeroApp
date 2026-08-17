import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/armatrutz_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';

void main() {
  final hero = HeroSheet(
    id: 'h',
    name: 'Testheld',
    level: 5,
    attributes: const Attributes(
      mu: 12,
      kl: 12,
      inn: 12,
      ch: 12,
      ff: 12,
      ge: 12,
      ko: 12,
      kk: 12,
    ),
    talents: const <String, HeroTalentEntry>{},
    combatConfig: const CombatConfig(
      armor: ArmorConfig(
        pieces: <ArmorPiece>[
          ArmorPiece(name: 'Lederrüstung', rs: 2, be: 1, isActive: true),
        ],
      ),
    ),
    vorteileText: '',
    nachteileText: '',
  );

  const baseState = HeroState(
    currentLep: 0,
    currentAsp: 0,
    currentKap: 0,
    currentAu: 0,
  );

  /// Baut einen Laufzeitzustand mit laufendem Armatrutz.
  HeroState stateWithArmatrutz({required int rsBonus, SpellDuration? duration}) {
    final effects = const ActiveSpellEffectsState()
        .withToggled(activeSpellEffectArmatrutz, true)
        .withDetail(
          activeSpellEffectArmatrutz,
          ActiveSpellEffectDetail(amount: rsBonus, duration: duration),
        );
    return baseState.copyWith(activeSpellEffects: effects);
  }

  group('computeArmatrutzRsBonus', () {
    test('ohne laufenden Armatrutz gibt es keinen Bonus', () {
      expect(computeArmatrutzRsBonus(sheet: hero, state: baseState), 0);
    });

    test('laufender Armatrutz liefert den erzauberten RS', () {
      final state = stateWithArmatrutz(rsBonus: 3);

      expect(computeArmatrutzRsBonus(sheet: hero, state: state), 3);
    });

    test('abgelaufene Wirkungsdauer schaltet den Bonus ab', () {
      final state = stateWithArmatrutz(
        rsBonus: 3,
        duration: SpellDuration(
          amount: 1,
          remaining: 0,
          unit: SpellDurationUnit.spielrunden,
        ),
      );

      expect(computeArmatrutzRsBonus(sheet: hero, state: state), 0);
    });

    test('negative Werte senken den Ruestungsschutz nicht', () {
      final state = stateWithArmatrutz(rsBonus: -4);

      expect(computeArmatrutzRsBonus(sheet: hero, state: state), 0);
    });
  });

  group('computeArmatrutzAspCost', () {
    test('Kosten sind RS im Quadrat abzueglich halber ZfP*', () {
      expect(computeArmatrutzAspCost(rsBonus: 5, zfpStar: 6), 22);
    });

    test('halbe ZfP* werden abgerundet', () {
      expect(computeArmatrutzAspCost(rsBonus: 4, zfpStar: 7), 13);
    });

    test('Mindestkosten von 4 AsP greifen immer', () {
      expect(computeArmatrutzAspCost(rsBonus: 1, zfpStar: 20), 4);
      expect(computeArmatrutzAspCost(rsBonus: 0), 4);
    });
  });

  group('Kampfvorschau', () {
    test('Armatrutz-RS zaehlt zur getragenen Ruestung hinzu', () {
      final ohne = computeCombatPreviewStats(hero, baseState);
      final mit = computeCombatPreviewStats(
        hero,
        stateWithArmatrutz(rsBonus: 4),
      );

      expect(ohne.rsTotal, 2);
      expect(ohne.armatrutzRsBonus, 0);
      expect(mit.rsTotal, 6);
      expect(mit.armatrutzRsBonus, 4);
    });

    test('die Behinderung bleibt vom Armatrutz unberuehrt', () {
      final ohne = computeCombatPreviewStats(hero, baseState);
      final mit = computeCombatPreviewStats(
        hero,
        stateWithArmatrutz(rsBonus: 4),
      );

      expect(mit.beTotalRaw, ohne.beTotalRaw);
      expect(mit.beKampf, ohne.beKampf);
      expect(mit.ebe, ohne.ebe);
    });
  });
}
