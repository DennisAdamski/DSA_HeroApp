import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/two_weapon_combat_rules.dart';

part 'combat_basis_cases.dart';
part 'combat_waffen_cases.dart';
part 'combat_nebenhand_cases.dart';
part 'combat_episch_cases.dart';

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
  int level = 10,
  Attributes? attributes,
  Map<String, HeroTalentEntry> talents = const <String, HeroTalentEntry>{},
  CombatConfig combatConfig = const CombatConfig(),
  String vorteileText = '',
  String nachteileText = '',
}) {
  return baseHero.copyWith(
    level: level,
    attributes: attributes ?? baseAttributes,
    talents: talents,
    combatConfig: combatConfig,
    vorteileText: vorteileText,
    nachteileText: nachteileText,
  );
}

HeroSheet heroWithAttributes({
  int? mu,
  int? kl,
  int? inn,
  int? ch,
  int? ff,
  int? ge,
  int? ko,
  int? kk,
  CombatConfig combatConfig = const CombatConfig(),
}) {
  return hero(
    attributes: baseAttributes.copyWith(
      mu: mu,
      kl: kl,
      inn: inn,
      ch: ch,
      ff: ff,
      ge: ge,
      ko: ko,
      kk: kk,
    ),
    combatConfig: combatConfig,
  );
}

CombatPreviewStats preview(
  HeroSheet sheet, {
  List<TalentDef> catalogTalents = const <TalentDef>[],
  HeroState heroState = state,
}) {
  return computeCombatPreviewStats(
    sheet,
    heroState,
    catalogTalents: catalogTalents,
  );
}

void main() {
  _combatBasis();
  _combatWaffen();
  _combatNebenhand();
  _combatEpisch();
}
