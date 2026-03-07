import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ausweichen_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/excel_rounding.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ini_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampfbasis_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ruestung_be_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/waffen_rules.dart';

class CombatPreviewStats {
  const CombatPreviewStats({
    required this.rsTotal,
    required this.beTotalRaw,
    required this.rgReduction,
    required this.beKampf,
    required this.beMod,
    required this.tpKk,
    required this.geBase,
    required this.geThreshold,
    required this.iniGe,
    required this.iniParadeMod,
    required this.tpCalc,
    required this.specApplies,
    required this.eigenschaftsIni,
    required this.iniWurfEffective,
    required this.axxIniBonus,
    required this.heldenInitiative,
    required this.kombinierteHeldenWaffenIni,
    required this.kampfInitiative,
    required this.initiative,
    required this.ausweichen,
    required this.at,
    required this.pa,
    required this.ebe,
    required this.tpExpression,
    required this.specBonus,
    required this.akrobatikBonus,
    required this.sfIniBonus,
    required this.sfAusweichenBonus,
    required this.axxAusweichenBonus,
    required this.iniAusweichenBonus,
    required this.paBase,
    required this.axxPaBaseBonus,
    required this.offhandPaBonus,
    required this.iniDiceCount,
    required this.fkBase,
    required this.axxAttackDefenseHint,
  });

  final int rsTotal;
  final int beTotalRaw;
  final int rgReduction;
  final int beKampf;
  final int beMod;
  final int tpKk;
  final int geBase;
  final int geThreshold;
  final int iniGe;
  final int iniParadeMod;
  final int tpCalc;
  final bool specApplies;
  final int eigenschaftsIni;
  final int iniWurfEffective;
  final int axxIniBonus;
  final int heldenInitiative;
  final int kombinierteHeldenWaffenIni;
  final int kampfInitiative;
  // Rueckwaertskompatibler Alias auf die Kampf-Ini.
  final int initiative;
  final int ausweichen;
  final int at;
  final int pa;
  final int ebe;
  final String tpExpression;
  final int specBonus;
  final int akrobatikBonus;
  final int sfIniBonus;
  final int sfAusweichenBonus;
  final int axxAusweichenBonus;
  final int iniAusweichenBonus;
  final int paBase;
  final int axxPaBaseBonus;
  final int offhandPaBonus;
  // Anzahl Ini-Wuerfel: 1 (normal) oder 2 (Klingentaenzer)
  final int iniDiceCount;
  final int fkBase;
  final String axxAttackDefenseHint;
}

CombatPreviewStats computeCombatPreviewStats(
  HeroSheet sheet,
  HeroState state, {
  CombatConfig? overrideConfig,
  Map<String, HeroTalentEntry>? overrideTalents,
  List<TalentDef> catalogTalents = const <TalentDef>[],
  ModifierParseResult? parsedModifiers,
  Attributes? effectiveAttributes,
  DerivedStats? derivedStats,
}) {
  final parsed = parsedModifiers ?? parseModifierTextsForHero(sheet);
  final effective =
      effectiveAttributes ??
      applyAttributeModifiers(
        sheet.attributes,
        parsed.attributeMods + state.tempAttributeMods,
      );
  final effectiveSheet = sheet.copyWith(attributes: effective);
  final mods = sheet.persistentMods + parsed.statMods + state.tempMods;
  final derived =
      derivedStats ??
      computeDerivedStatsFromInputs(
        sheet: sheet,
        state: state,
        parsedModifiers: parsed,
        effectiveAttributes: effective,
      );

  final config = overrideConfig ?? sheet.combatConfig;
  final talents = overrideTalents ?? sheet.talents;
  final main = config.selectedWeapon;
  final offhand = config.offhand.mode == OffhandMode.none
      ? const OffhandSlot()
      : config.offhand;
  final armor = config.armor;
  final special = config.specialRules;
  final manualMods = config.manualMods;

  // --- Ruestung & Behinderung (ruestung_be_rules) ---
  final activeArmorPieces = armor.pieces
      .where((piece) => piece.isActive)
      .toList(growable: false);
  final rsTotal = computeRsTotal(activeArmorPieces) + mods.rs;
  final beTotalRaw = computeBeTotalRaw(activeArmorPieces);
  final rgReduction = computeRgReduction(
    globalArmorTrainingLevel: armor.globalArmorTrainingLevel,
    activePieces: activeArmorPieces,
  );
  final beKampf = computeBeKampf(beTotalRaw, rgReduction);
  final selectedTalent = _findTalentDefById(catalogTalents, main.talentId);
  final beMod = selectedTalent == null
      ? main.beTalentMod
      : parseBeModifier(selectedTalent.be);
  final ebe = computeEbe(beKampf: beKampf, beMod: beMod);
  final atEbePart = computeAtEbePart(ebe);
  final paEbePart = computePaEbePart(ebe);

  // --- Waffe: Spezialisierung & TP (waffen_rules) ---
  final specApplies = hasCombatSpecialization(
    talents: talents,
    talentId: main.talentId,
    weaponType: main.weaponType.trim().isEmpty ? main.name : main.weaponType,
  );
  final isRangedTalent = isRangedCombatTalent(selectedTalent);
  final atSpecBonus = specApplies ? (isRangedTalent ? 2 : 1) : 0;
  final paSpecBonus = specApplies && !isRangedTalent ? 1 : 0;
  final kkThreshold = main.kkThreshold < 1 ? 1 : main.kkThreshold;
  final tpKk = computeTpKk(
    kk: effectiveSheet.attributes.kk,
    kkBase: main.kkBase,
    kkThreshold: kkThreshold,
  );
  final axxTpBonus = computeAxxeleratusTpBonus(
    axxeleratusActive: special.axxeleratusActive,
  );
  final tpCalc = main.tpFlat + tpKk + axxTpBonus;

  // --- Sonderfertigkeit-Boni (ini_rules, ausweichen_rules, waffen_rules) ---
  final sfIniBonus = computeSfIniBonus(
    special,
    hasFlinkFromVorteile: parsed.hasFlinkFromVorteile,
    hasBehaebigFromNachteile: parsed.hasBehaebigFromNachteile,
  );
  final sfAusweichenBonus = computeSfAusweichenBonus(
    special,
    hasFlinkFromVorteile: parsed.hasFlinkFromVorteile,
    hasBehaebigFromNachteile: parsed.hasBehaebigFromNachteile,
  );
  final offhandPaBonus = computeOffhandPaBonus(
    mode: offhand.mode,
    basePaMod: offhand.paMod,
    special: special,
  );

  // --- Kampfbasiswerte (kampfbasis_rules) ---
  final atBase = computeAt(effectiveSheet, mods);
  final basePa = computePa(effectiveSheet, mods);
  final axxPaBaseBonus = computeAxxeleratusPaBaseBonus(
    axxeleratusActive: special.axxeleratusActive,
  );
  final paBase = basePa + axxPaBaseBonus;

  // --- Endwerte AT & PA ---
  final talentEntry = main.talentId.trim().isEmpty
      ? null
      : talents[main.talentId.trim()];
  final talentAt = talentEntry?.atValue ?? 0;
  final talentPa = talentEntry?.paValue ?? 0;
  final at =
      talentAt +
      atBase +
      main.wmAt +
      atEbePart +
      atSpecBonus +
      offhand.atMod +
      manualMods.atMod;
  final pa =
      talentPa +
      paBase +
      main.wmPa +
      paEbePart +
      paSpecBonus +
      offhandPaBonus +
      manualMods.paMod;

  // --- Initiative-Kette (ini_rules) ---
  final iniDiceCount = computeIniDiceCount(special);
  final maxIniRoll = iniDiceCount * 6;
  final iniWurfEffective = _clamp(manualMods.iniWurf, 0, maxIniRoll);
  final eigenschaftsIni = derived.iniBase;
  final axxIniBonus = computeAxxeleratusIniBonus(
    iniBase: eigenschaftsIni,
    axxeleratusActive: special.axxeleratusActive,
  );
  final heldenInitiative = clampNonNegative(
    eigenschaftsIni +
        ebe +
        sfIniBonus +
        iniWurfEffective +
        axxIniBonus +
        manualMods.iniMod,
  );
  final geBase = 26 - main.kkBase;
  final geThreshold = 7 - kkThreshold;
  final iniGe = computeIniGe(
    ge: effectiveSheet.attributes.ge,
    kkBase: main.kkBase,
    kkThreshold: kkThreshold,
  );
  final kombinierteHeldenWaffenIni = clampNonNegative(
    heldenInitiative + main.iniMod + iniGe,
  );
  final kampfInitiative = clampNonNegative(
    kombinierteHeldenWaffenIni + offhand.iniMod,
  );
  final initiative = kampfInitiative;
  final iniParadeMod = computeIniParadeMod(kampfInitiative);

  // --- Ausweichen (ausweichen_rules) ---
  final akrobatikBonusValue = computeAkrobatikBonus(talents);
  final axxAusweichenBonus = computeAxxeleratusAusweichenBonus(
    axxeleratusActive: special.axxeleratusActive,
  );
  final iniAusweichenBonus = computeIniAusweichenBonus(
    kampfInitiative: kampfInitiative,
  );
  final ausweichen = computeAusweichen(
    paBase: paBase,
    sfAusweichenBonus: sfAusweichenBonus,
    akrobatikBonus: akrobatikBonusValue,
    axxAusweichenBonus: axxAusweichenBonus,
    iniAusweichenBonus: iniAusweichenBonus,
    manualAusweichenMod: manualMods.ausweichenMod,
    beKampf: beKampf,
  );
  final axxAttackDefenseHint = buildAxxeleratusDefenseHint(
    axxeleratusActive: special.axxeleratusActive,
  );

  return CombatPreviewStats(
    rsTotal: clampNonNegative(rsTotal),
    beTotalRaw: clampNonNegative(beTotalRaw),
    rgReduction: rgReduction,
    beKampf: beKampf,
    beMod: beMod,
    tpKk: tpKk,
    geBase: geBase,
    geThreshold: geThreshold,
    iniGe: iniGe,
    iniParadeMod: iniParadeMod,
    tpCalc: tpCalc,
    specApplies: specApplies,
    eigenschaftsIni: eigenschaftsIni,
    iniWurfEffective: iniWurfEffective,
    axxIniBonus: axxIniBonus,
    heldenInitiative: heldenInitiative,
    kombinierteHeldenWaffenIni: kombinierteHeldenWaffenIni,
    kampfInitiative: kampfInitiative,
    initiative: initiative,
    ausweichen: ausweichen,
    at: at,
    pa: pa,
    ebe: ebe,
    tpExpression: buildTpExpression(main, tpCalc),
    specBonus: atSpecBonus,
    akrobatikBonus: akrobatikBonusValue,
    sfIniBonus: sfIniBonus,
    sfAusweichenBonus: sfAusweichenBonus,
    axxAusweichenBonus: axxAusweichenBonus,
    iniAusweichenBonus: iniAusweichenBonus,
    paBase: paBase,
    axxPaBaseBonus: axxPaBaseBonus,
    offhandPaBonus: offhandPaBonus,
    iniDiceCount: iniDiceCount,
    fkBase: derived.fkBase,
    axxAttackDefenseHint: axxAttackDefenseHint,
  );
}

TalentDef? _findTalentDefById(List<TalentDef> talents, String id) {
  final trimmed = id.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  for (final entry in talents) {
    if (entry.id == trimmed) {
      return entry;
    }
  }
  return null;
}

int _clamp(int value, int min, int max) {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}
