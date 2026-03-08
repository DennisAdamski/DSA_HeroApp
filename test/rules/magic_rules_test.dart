import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_rules.dart';

void main() {
  const state = HeroState(
    currentLep: 0,
    currentAsp: 0,
    currentKap: 0,
    currentAu: 0,
  );
  const stateWithAxx = HeroState(
    currentLep: 0,
    currentAsp: 0,
    currentKap: 0,
    currentAu: 0,
    activeSpellEffects: ActiveSpellEffectsState(
      activeEffectIds: <String>[activeSpellEffectAxxeleratus],
    ),
  );
  const baseAttributes = Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  );
  final baseHero = HeroSheet(
    id: 'h',
    name: 'Testheld',
    level: 10,
    attributes: baseAttributes,
    talents: const <String, HeroTalentEntry>{},
    combatConfig: const CombatConfig(),
    vorteileText: '',
    nachteileText: '',
  );

  HeroSheet hero({
    Attributes? attributes,
    CombatConfig combatConfig = const CombatConfig(),
  }) {
    return baseHero.copyWith(
      attributes: attributes ?? baseAttributes,
      combatConfig: combatConfig,
    );
  }

  CombatPreviewStats preview(HeroSheet sheet, {HeroState heroState = state}) {
    return computeCombatPreviewStats(sheet, heroState);
  }

  test('Axxeleratus gibt +2 TP auf Nahkampfangriffe', () {
    final withoutAxx = hero(
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(tpFlat: 4, kkBase: 12, kkThreshold: 2),
      ),
    );
    final withAxx = hero(
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(tpFlat: 4, kkBase: 12, kkThreshold: 2),
      ),
    );

    expect(preview(withoutAxx).tpCalc, 4);
    expect(preview(withAxx, heroState: stateWithAxx).tpCalc, 6);
  });

  test('Axxeleratus erhoeht den Parade-Basiswert um 2', () {
    final withoutAxx = hero();
    final withAxx = hero();

    final withoutResult = preview(withoutAxx);
    final withResult = preview(withAxx, heroState: stateWithAxx);

    expect(withoutResult.axxPaBaseBonus, 0);
    expect(withResult.axxPaBaseBonus, 2);
    expect(withResult.paBase, withoutResult.paBase + 2);
    expect(withResult.pa, withoutResult.pa + 2);
  });

  test('Axxeleratus erhoeht Ausweichen insgesamt um 4', () {
    final withoutAxx = hero();
    final withAxx = hero();

    final withoutResult = preview(withoutAxx);
    final withResult = preview(withAxx, heroState: stateWithAxx);

    expect(withResult.axxAusweichenBonus, 2);
    expect(withResult.ausweichen, withoutResult.ausweichen + 4);
  });

  test('Axxeleratus verdoppelt nur den Ini-Basisanteil', () {
    final withoutAxx = hero(
      combatConfig: const CombatConfig(
        specialRules: CombatSpecialRules(kampfreflexe: true),
        manualMods: CombatManualMods(iniWurf: 3, iniMod: 1),
      ),
    );
    final withAxx = hero(
      combatConfig: const CombatConfig(
        specialRules: CombatSpecialRules(kampfreflexe: true),
        manualMods: CombatManualMods(iniWurf: 3, iniMod: 1),
      ),
    );

    final withoutResult = preview(withoutAxx);
    final withResult = preview(withAxx, heroState: stateWithAxx);

    expect(withoutResult.axxIniBonus, 0);
    expect(withResult.axxIniBonus, withResult.eigenschaftsIni);
    expect(
      withResult.heldenInitiative,
      withoutResult.heldenInitiative + withResult.eigenschaftsIni,
    );
    expect(withResult.iniWurfEffective, withoutResult.iniWurfEffective);
  });

  test('Axxeleratus verdoppelt den finalen GS-Wert', () {
    final withoutAxx = hero();
    final withAxx = hero();

    final withoutGs = computeDerivedStats(withoutAxx, state).gs;
    final withGs = computeDerivedStats(withAxx, stateWithAxx).gs;

    expect(withoutGs, 8);
    expect(withGs, 16);
  });

  test('Axxeleratus liefert den Anzeigehinweis fuer Finte +2', () {
    expect(buildAxxeleratusDefenseHint(axxeleratusActive: false), isEmpty);
    expect(
      buildAxxeleratusDefenseHint(axxeleratusActive: true),
      'Abwehr des beschleunigten Nahkampfangriffs: Automatische Finte +2',
    );
  });

  test('legacy combat rule flag remains a fallback for Axxeleratus', () {
    final withoutAxx = hero(
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(tpFlat: 4, kkBase: 12, kkThreshold: 2),
      ),
    );
    final withLegacyAxx = hero(
      combatConfig: const CombatConfig(
        mainWeapon: MainWeaponSlot(tpFlat: 4, kkBase: 12, kkThreshold: 2),
        specialRules: CombatSpecialRules(axxeleratusActive: true),
      ),
    );

    expect(preview(withLegacyAxx).tpCalc, preview(withoutAxx).tpCalc + 2);
    expect(computeDerivedStats(withLegacyAxx, state).gs, 16);
  });
}
