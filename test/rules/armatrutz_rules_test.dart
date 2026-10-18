import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/armatrutz_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';

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
  HeroState stateWithArmatrutz({
    required int rsBonus,
    SpellDuration? duration,
  }) {
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

    test('Endkosten werden abgerundet (Beispiel LC S. 28)', () {
      // RS 4, ZfP* 5: 16 − 2,5 = 13,5 → 13 AsP wie im Zaubertext.
      expect(computeArmatrutzAspCost(rsBonus: 4, zfpStar: 5), 13);
      // 16 − 3,5 = 12,5 → 12 AsP.
      expect(computeArmatrutzAspCost(rsBonus: 4, zfpStar: 7), 12);
      expect(computeArmatrutzAspCost(rsBonus: 4, zfpStar: 6), 13);
    });

    test('der Kostenhinweis nennt die Abrundung', () {
      expect(
        describeArmatrutzAspCost(rsBonus: 4, zfpStar: 5),
        contains('abgerundet → 13 AsP'),
      );
    });

    test('Mindestkosten von 4 AsP greifen immer', () {
      expect(computeArmatrutzAspCost(rsBonus: 1, zfpStar: 20), 4);
      expect(computeArmatrutzAspCost(rsBonus: 0), 4);
    });
  });

  group('Grenze ZfW/2', () {
    HeroSheet mitZfw(int? zfw) => hero.copyWith(
      spells: <String, HeroSpellEntry>{
        armatrutzSpellId: HeroSpellEntry(spellValue: zfw),
      },
    );

    test('ZfW/2 wird aufgerundet', () {
      expect(armatrutzRsGrenze(sheet: mitZfw(0)), 0);
      expect(armatrutzRsGrenze(sheet: mitZfw(1)), 1);
      expect(armatrutzRsGrenze(sheet: mitZfw(8)), 4);
      expect(armatrutzRsGrenze(sheet: mitZfw(9)), 5);
      expect(armatrutzRsGrenze(sheet: mitZfw(-2)), 0);
    });

    test('ohne ZfW gibt es keine Grenze', () {
      expect(armatrutzRsGrenze(sheet: hero), isNull);
      expect(armatrutzRsGrenze(sheet: mitZfw(null)), isNull);
      expect(
        describeArmatrutzGrenze(rsBonus: 6, grenze: null),
        contains('nicht geprüft'),
      );
    });

    test('der ZfW-Modifikator zählt nicht', () {
      final sheet = hero.copyWith(
        spells: <String, HeroSpellEntry>{
          armatrutzSpellId: const HeroSpellEntry(spellValue: 8, modifier: 3),
        },
      );
      expect(armatrutzRsGrenze(sheet: sheet), 4);
    });

    test('ein Wert über der Grenze wird begrenzt, gespeichert bleibt er', () {
      final state = stateWithArmatrutz(rsBonus: 7);
      final vorschau = computeCombatPreviewStats(mitZfw(9), state);

      expect(vorschau.armatrutzRsBonus, 5);
      expect(vorschau.rsTotal, 2 + 5);
      final rs = vorschau.herleitungen!.rs;
      expect(rs.wert, vorschau.rsTotal);
      final grenze = rs.schritte.singleWhere(
        (s) => s.bezeichnung == 'Armatrutz-Grenze ZfW/2',
      );
      expect(grenze.betrag, -2);
      expect(grenze.art, HerleitungsArt.begrenzung);
      expect(grenze.formel, contains('ZfW 9 / 2 = 5'));
      expect(
        state.activeSpellEffects.detailFor(activeSpellEffectArmatrutz).amount,
        7,
      );
      expect(
        describeArmatrutzWert(sheet: mitZfw(9), state: state),
        contains('Es wirken nur 5'),
      );
    });

    test('an und unter der Grenze gibt es keinen Begrenzungsschritt', () {
      for (final rs in [5, 3]) {
        final vorschau = computeCombatPreviewStats(
          mitZfw(9),
          stateWithArmatrutz(rsBonus: rs),
        );
        expect(vorschau.armatrutzRsBonus, rs);
        expect(vorschau.rsTotal, 2 + rs);
        expect(
          vorschau.herleitungen!.rs.schritte.where(
            (s) => s.art == HerleitungsArt.begrenzung,
          ),
          isEmpty,
        );
      }
    });

    test('ohne ZfW wirkt der gespeicherte Wert unbegrenzt', () {
      final vorschau = computeCombatPreviewStats(
        hero,
        stateWithArmatrutz(rsBonus: 7),
      );
      expect(vorschau.armatrutzRsBonus, 7);
      expect(vorschau.rsTotal, 9);
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
