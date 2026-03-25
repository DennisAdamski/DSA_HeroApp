import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ausweichen_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/excel_rounding.dart';
import 'package:dsa_heldenverwaltung/rules/derived/fernkampf_ladezeit_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/fernkampf_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ini_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampfbasis_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ruestung_be_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/shield_parry_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/waffenmeister_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/unarmed_style_rules.dart';
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
    required this.iniBasis,
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
    required this.paMitIniParadeMod,
    required this.ebe,
    required this.tpExpression,
    required this.specBonus,
    required this.akrobatikBonus,
    required this.sfIniBonus,
    required this.sfAusweichenBonus,
    required this.ausweichenMod,
    required this.axxAusweichenBonus,
    required this.iniAusweichenBonus,
    required this.paBase,
    required this.axxPaBaseBonus,
    required this.offhandPaBonus,
    required this.offhandAtMod,
    required this.offhandIniMod,
    required this.offhandWeaponInitiative,
    required this.shieldPa,
    required this.shieldPaBonus,
    required this.offhandIsShield,
    required this.offhandIsParryWeapon,
    required this.offhandRequiresLinkhand,
    required this.offhandName,
    required this.iniDiceCount,
    required this.initiativeDiceSpec,
    required this.initiativeFixedRollTotal,
    required this.damageDiceSpec,
    required this.axxAttackDefenseHint,
    required this.isRangedWeapon,
    required this.rangedAtBase,
    required this.projectileAtMod,
    required this.distanceTpMod,
    required this.projectileTpMod,
    required this.projectileIniMod,
    required this.baseReloadTime,
    required this.reloadTime,
    required this.reloadTimeDisplay,
    required this.activeDistanceLabel,
    required this.activeProjectileName,
    required this.activeProjectileCount,
    required this.activeProjectileDescription,
    required this.schnellziehenActive,
    required this.schnellziehenTemporary,
    required this.schnellladenBogenActive,
    required this.schnellladenBogenTemporary,
    required this.schnellladenArmbrustActive,
    required this.schnellladenArmbrustTemporary,
    required this.waffenmeisterActive,
    required this.waffenmeisterName,
    required this.waffenmeisterIniBonus,
    required this.waffenmeisterAtBonus,
    required this.waffenmeisterPaBonus,
    required this.waffenmeisterTpKkBaseReduction,
    required this.waffenmeisterTpKkThresholdReduction,
    required this.waffenmeisterAdditionalManeuvers,
    required this.waffenmeisterReloadTimeHalved,
    required this.waffenmeisterManeuverReductions,
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
  final int iniBasis;
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
  final int paMitIniParadeMod;
  final int ebe;
  final String tpExpression;
  final int specBonus;
  final int akrobatikBonus;
  final int sfIniBonus;
  final int sfAusweichenBonus;
  final int ausweichenMod;
  final int axxAusweichenBonus;
  final int iniAusweichenBonus;
  final int paBase;
  final int axxPaBaseBonus;
  final int offhandPaBonus;
  final int offhandAtMod;
  final int offhandIniMod;
  final int? offhandWeaponInitiative;
  final int shieldPa;
  final int shieldPaBonus;
  final bool offhandIsShield;
  final bool offhandIsParryWeapon;
  final bool offhandRequiresLinkhand;
  final String offhandName;
  // Anzahl Ini-Wuerfel: 1 (normal) oder 2 (Klingentaenzer)
  final int iniDiceCount;
  final DiceSpec initiativeDiceSpec;
  final int? initiativeFixedRollTotal;
  final DiceSpec damageDiceSpec;
  final String axxAttackDefenseHint;
  final bool isRangedWeapon;
  final int rangedAtBase;
  final int projectileAtMod;
  final int distanceTpMod;
  final int projectileTpMod;
  final int projectileIniMod;
  final int baseReloadTime;
  final int reloadTime;
  final String reloadTimeDisplay;
  final String activeDistanceLabel;
  final String activeProjectileName;
  final int activeProjectileCount;
  final String activeProjectileDescription;
  final bool schnellziehenActive;
  final bool schnellziehenTemporary;
  final bool schnellladenBogenActive;
  final bool schnellladenBogenTemporary;
  final bool schnellladenArmbrustActive;
  final bool schnellladenArmbrustTemporary;

  /// Waffenmeisterschaft ist fuer die aktive Waffe aktiv.
  final bool waffenmeisterActive;

  /// Anzeigename der aktiven Waffenmeisterschaft.
  final String waffenmeisterName;

  /// INI-Bonus durch Waffenmeisterschaft.
  final int waffenmeisterIniBonus;

  /// AT-WM-Bonus durch Waffenmeisterschaft.
  final int waffenmeisterAtBonus;

  /// PA-WM-Bonus durch Waffenmeisterschaft.
  final int waffenmeisterPaBonus;

  /// TP/KK-Basisreduktion durch Waffenmeisterschaft.
  final int waffenmeisterTpKkBaseReduction;

  /// TP/KK-Schwellenreduktion durch Waffenmeisterschaft.
  final int waffenmeisterTpKkThresholdReduction;

  /// Zusaetzlich freigeschaltete Manoever durch Waffenmeisterschaft.
  final List<String> waffenmeisterAdditionalManeuvers;

  /// Ladezeit-Halbierung durch Waffenmeisterschaft.
  final bool waffenmeisterReloadTimeHalved;

  /// Manoever-Erschwernis-Reduktionen durch Waffenmeisterschaft.
  final Map<String, int> waffenmeisterManeuverReductions;
}

CombatPreviewStats computeCombatPreviewStats(
  HeroSheet sheet,
  HeroState state, {
  CombatConfig? overrideConfig,
  Map<String, HeroTalentEntry>? overrideTalents,
  List<TalentDef> catalogTalents = const <TalentDef>[],
  List<ManeuverDef> catalogManeuvers = const <ManeuverDef>[],
  List<CombatSpecialAbilityDef> catalogCombatSpecialAbilities =
      const <CombatSpecialAbilityDef>[],
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
  final offhandWeapon =
      config.offhandAssignment.usesWeapon &&
          config.offhandAssignment.weaponIndex >= 0 &&
          config.offhandAssignment.weaponIndex < config.weaponSlots.length
      ? config.weaponSlots[config.offhandAssignment.weaponIndex]
      : null;
  final offhandEquipment =
      config.offhandAssignment.usesEquipment &&
          config.offhandAssignment.equipmentIndex >= 0 &&
          config.offhandAssignment.equipmentIndex <
              config.offhandEquipment.length
      ? config.offhandEquipment[config.offhandAssignment.equipmentIndex]
      : null;
  final armor = config.armor;
  final special = config.specialRules;
  final manualMods = config.manualMods;
  final axxeleratusActive = isAxxeleratusEffectActive(
    sheet: sheet,
    state: state,
  );

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
  final legacyRanged = isRangedCombatTalent(selectedTalent);
  final isRangedWeapon = main.isRanged || legacyRanged;
  final beMod = selectedTalent == null
      ? main.beTalentMod
      : parseBeModifier(selectedTalent.be);
  final ebe = computeEbe(beKampf: beKampf, beMod: beMod);
  final atEbePart = computeAtEbePart(ebe);
  final paEbePart = computePaEbePart(ebe);
  final rangedAtEbePart = isRangedWeapon ? ebe : atEbePart;

  // --- Waffenmeister-Effekte ---
  final wmEffects = computeWaffenmeisterEffects(
    waffenmeisterschaften: config.waffenmeisterschaften,
    activeWeaponType: main.weaponType.trim().isEmpty
        ? main.name
        : main.weaponType,
    activeTalentId: main.talentId,
  );

  // --- Waffe: Spezialisierung & TP (waffen_rules) ---
  final specApplies = hasCombatSpecialization(
    talents: talents,
    talentId: main.talentId,
    weaponType: main.weaponType.trim().isEmpty ? main.name : main.weaponType,
  );
  final atSpecBonus = specApplies ? (isRangedWeapon ? 2 : 1) : 0;
  final paSpecBonus = specApplies && !isRangedWeapon ? 1 : 0;
  final wmKkBase = main.kkBase + wmEffects.tpKkBaseReduction;
  final wmKkThreshold = main.kkThreshold + wmEffects.tpKkThresholdReduction;
  final kkThreshold = wmKkThreshold < 1 ? 1 : wmKkThreshold;
  final tpKk = computeTpKk(
    kk: effectiveSheet.attributes.kk,
    kkBase: wmKkBase,
    kkThreshold: kkThreshold,
  );
  final axxTpBonus = isRangedWeapon
      ? 0
      : computeAxxeleratusTpBonus(axxeleratusActive: axxeleratusActive);
  final activeDistanceBand = main.rangedProfile.selectedDistanceBand;
  final activeProjectile = main.rangedProfile.selectedProjectileOrNull;
  final selectedTalentName = selectedTalent?.name ?? '';
  final unarmedStyleEffects = computeActiveUnarmedStyleEffects(
    specialRules: special,
    catalogCombatSpecialAbilities: catalogCombatSpecialAbilities,
    catalogManeuvers: catalogManeuvers,
    activeTalentName: selectedTalentName,
  );
  final reloadTimeResult = computeRangedReloadTime(
    weapon: main,
    specialRules: special,
    axxeleratusActive: axxeleratusActive,
    talentName: selectedTalent?.name,
    reloadDivisor: wmEffects.reloadTimeHalved ? 2 : 1,
  );
  final distanceTpMod = isRangedWeapon ? activeDistanceBand.tpMod : 0;
  final projectileTpMod = isRangedWeapon ? (activeProjectile?.tpMod ?? 0) : 0;
  final projectileIniMod = isRangedWeapon ? (activeProjectile?.iniMod ?? 0) : 0;
  final projectileAtMod = isRangedWeapon ? (activeProjectile?.atMod ?? 0) : 0;
  final baseTpCalc = main.tpFlat + tpKk + axxTpBonus;
  final tpCalc = isRangedWeapon
      ? computeRangedTpCalc(
          baseTpCalc: baseTpCalc,
          distanceTpMod: distanceTpMod,
          projectileTpMod: projectileTpMod,
        )
      : baseTpCalc;

  // --- Sonderfertigkeit-Boni (ini_rules, ausweichen_rules, waffen_rules) ---
  final sfIniBonus = computeSfIniBonus(
    special,
    hasFlinkFromVorteile: parsed.hasFlinkFromVorteile,
    hasBehaebigFromNachteile: parsed.hasBehaebigFromNachteile,
  );
  final sfAusweichenBonus = computeSfAusweichenBonus(special);
  final ausweichenTextMod =
      (parsed.hasFlinkFromVorteile ? 1 : 0) +
      (parsed.hasBehaebigFromNachteile ? -1 : 0);
  final ausweichenMod = manualMods.ausweichenMod + ausweichenTextMod;
  final offhandModifiers = computeOffhandModifierSnapshot(
    equipment: offhandEquipment,
    specialRules: special,
    paBase:
        computePa(effectiveSheet, mods) +
        computeAxxeleratusPaBaseBonus(axxeleratusActive: axxeleratusActive),
  );

  // --- Kampfbasiswerte (kampfbasis_rules) ---
  final atBase = computeAt(effectiveSheet, mods);
  final basePa = computePa(effectiveSheet, mods);
  final axxPaBaseBonus = computeAxxeleratusPaBaseBonus(
    axxeleratusActive: axxeleratusActive,
  );
  final paBase = basePa + axxPaBaseBonus;

  // --- Endwerte AT & PA ---
  final talentEntry = main.talentId.trim().isEmpty
      ? null
      : talents[main.talentId.trim()];
  final talentAt = talentEntry?.atValue ?? 0;
  final talentPa = talentEntry?.paValue ?? 0;
  final rangedAtBase = isRangedWeapon ? derived.fkBase : 0;
  final at = isRangedWeapon
      ? computeRangedAtValue(
          rangedAtBase: rangedAtBase,
          talentAtValue: talentAt,
          weaponAtMod: main.wmAt,
          ebeAttackPart: rangedAtEbePart,
          specializationBonus: atSpecBonus,
          projectileAtMod: projectileAtMod,
          manualAtMod: manualMods.atMod,
        )
      : talentAt +
            atBase +
            main.wmAt +
            wmEffects.atWmBonus +
            atEbePart +
            atSpecBonus +
            unarmedStyleEffects.atBonus +
            offhandModifiers.atMod +
            manualMods.atMod;
  final pa = isRangedWeapon
      ? 0
      : talentPa +
            paBase +
            main.wmPa +
            wmEffects.paWmBonus +
            paEbePart +
            paSpecBonus +
            unarmedStyleEffects.paBonus +
            offhandModifiers.mainPaMod +
            manualMods.paMod;

  // --- Initiative-Kette (ini_rules) ---
  final iniDiceCount = computeIniDiceCount(special);
  final maxIniRoll = iniDiceCount * 6;
  final iniWurfEffective = manualMods.iniWurf.clamp(0, maxIniRoll);
  final initiativeFixedRollTotal = special.aufmerksamkeit ? maxIniRoll : null;
  final eigenschaftsIni = computeIniBase(effectiveSheet, mods);
  final iniBasis = derived.iniBase;
  final axxIniBonus = computeAxxeleratusIniBonus(
    iniBase: iniBasis,
    axxeleratusActive: axxeleratusActive,
  );
  final heldenInitiative = clampNonNegative(
    iniBasis +
        ebe +
        sfIniBonus +
        unarmedStyleEffects.iniMod +
        iniWurfEffective +
        axxIniBonus +
        manualMods.iniMod,
  );
  final initiativeSnapshot = _computeWeaponInitiativeSnapshot(
    slot: main,
    heldenInitiative: heldenInitiative,
    effectiveGe: effectiveSheet.attributes.ge,
    catalogTalents: catalogTalents,
    waffenmeisterschaften: config.waffenmeisterschaften,
  );
  final geBase = initiativeSnapshot.geBase;
  final geThreshold = initiativeSnapshot.geThreshold;
  final iniGe = initiativeSnapshot.iniGe;
  final kombinierteHeldenWaffenIni = initiativeSnapshot.kombinierteIni;
  final offhandWeaponInitiative = offhandWeapon == null
      ? null
      : _computeWeaponInitiativeSnapshot(
          slot: offhandWeapon,
          heldenInitiative: heldenInitiative,
          effectiveGe: effectiveSheet.attributes.ge,
          catalogTalents: catalogTalents,
          waffenmeisterschaften: config.waffenmeisterschaften,
        ).kombinierteIni;
  final kampfInitiative = offhandWeaponInitiative == null
      ? clampNonNegative(kombinierteHeldenWaffenIni + offhandModifiers.iniMod)
      : (kombinierteHeldenWaffenIni > offhandWeaponInitiative
            ? kombinierteHeldenWaffenIni
            : offhandWeaponInitiative);
  final initiative = kampfInitiative;
  final iniParadeMod = computeIniParadeMod(kampfInitiative);
  final paMitIniParadeMod = isRangedWeapon ? 0 : pa + iniParadeMod;

  // --- Ausweichen (ausweichen_rules) ---
  final akrobatikBonusValue = computeAkrobatikBonus(talents);
  final axxAusweichenBonus = computeAxxeleratusAusweichenBonus(
    axxeleratusActive: axxeleratusActive,
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
    ausweichenMod: ausweichenMod,
    beKampf: beKampf,
  );
  final axxAttackDefenseHint = buildAxxeleratusDefenseHint(
    axxeleratusActive: axxeleratusActive,
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
    iniBasis: iniBasis,
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
    paMitIniParadeMod: paMitIniParadeMod,
    ebe: ebe,
    tpExpression: buildTpExpression(main, tpCalc),
    specBonus: atSpecBonus,
    akrobatikBonus: akrobatikBonusValue,
    sfIniBonus: sfIniBonus,
    sfAusweichenBonus: sfAusweichenBonus,
    ausweichenMod: ausweichenMod,
    axxAusweichenBonus: axxAusweichenBonus,
    iniAusweichenBonus: iniAusweichenBonus,
    paBase: paBase,
    axxPaBaseBonus: axxPaBaseBonus,
    offhandPaBonus: offhandModifiers.mainPaMod,
    offhandAtMod: offhandModifiers.atMod,
    offhandIniMod: offhandModifiers.iniMod,
    offhandWeaponInitiative: offhandWeaponInitiative,
    shieldPa: offhandModifiers.shieldPa,
    shieldPaBonus: offhandModifiers.shieldPaBonus,
    offhandIsShield: offhandModifiers.isShield,
    offhandIsParryWeapon: offhandModifiers.isParryWeapon,
    offhandRequiresLinkhand: offhandModifiers.requiresLinkhandViolation,
    offhandName: offhandModifiers.displayName,
    iniDiceCount: iniDiceCount,
    initiativeDiceSpec: DiceSpec(count: iniDiceCount, sides: 6),
    initiativeFixedRollTotal: initiativeFixedRollTotal,
    damageDiceSpec: DiceSpec(
      count: main.tpDiceCount < 1 ? 1 : main.tpDiceCount,
      sides: main.tpDiceSides < 1 ? 6 : main.tpDiceSides,
      modifier: tpCalc,
    ),
    axxAttackDefenseHint: axxAttackDefenseHint,
    isRangedWeapon: isRangedWeapon,
    rangedAtBase: rangedAtBase,
    projectileAtMod: projectileAtMod,
    distanceTpMod: distanceTpMod,
    projectileTpMod: projectileTpMod,
    projectileIniMod: projectileIniMod,
    baseReloadTime: isRangedWeapon ? reloadTimeResult.baseReloadTime : 0,
    reloadTime: isRangedWeapon ? reloadTimeResult.effectiveReloadTime : 0,
    reloadTimeDisplay: isRangedWeapon
        ? reloadTimeResult.displayLabel
        : formatReloadTimeActions(0),
    activeDistanceLabel: isRangedWeapon ? activeDistanceBand.label : '',
    activeProjectileName: isRangedWeapon ? (activeProjectile?.name ?? '') : '',
    activeProjectileCount: isRangedWeapon ? (activeProjectile?.count ?? 0) : 0,
    activeProjectileDescription: isRangedWeapon
        ? (activeProjectile?.description ?? '')
        : '',
    schnellziehenActive: reloadTimeResult.schnellziehen.isActive,
    schnellziehenTemporary: reloadTimeResult.schnellziehen.isTemporary,
    schnellladenBogenActive: reloadTimeResult.schnellladenBogen.isActive,
    schnellladenBogenTemporary: reloadTimeResult.schnellladenBogen.isTemporary,
    schnellladenArmbrustActive: reloadTimeResult.schnellladenArmbrust.isActive,
    schnellladenArmbrustTemporary:
        reloadTimeResult.schnellladenArmbrust.isTemporary,
    waffenmeisterActive: wmEffects.isActive,
    waffenmeisterName: wmEffects.isActive
        ? 'Waffenmeister (${main.weaponType.trim().isEmpty ? main.name : main.weaponType})'
        : '',
    waffenmeisterIniBonus: wmEffects.iniBonus,
    waffenmeisterAtBonus: wmEffects.atWmBonus,
    waffenmeisterPaBonus: wmEffects.paWmBonus,
    waffenmeisterTpKkBaseReduction: wmEffects.tpKkBaseReduction,
    waffenmeisterTpKkThresholdReduction: wmEffects.tpKkThresholdReduction,
    waffenmeisterAdditionalManeuvers: wmEffects.additionalManeuvers,
    waffenmeisterReloadTimeHalved: wmEffects.reloadTimeHalved,
    waffenmeisterManeuverReductions: wmEffects.maneuverReductions,
  );
}

class _WeaponInitiativeSnapshot {
  const _WeaponInitiativeSnapshot({
    required this.geBase,
    required this.geThreshold,
    required this.iniGe,
    required this.projectileIniMod,
    required this.waffenmeisterIniBonus,
    required this.kombinierteIni,
  });

  final int geBase;
  final int geThreshold;
  final int iniGe;
  final int projectileIniMod;
  final int waffenmeisterIniBonus;
  final int kombinierteIni;
}

_WeaponInitiativeSnapshot _computeWeaponInitiativeSnapshot({
  required MainWeaponSlot slot,
  required int heldenInitiative,
  required int effectiveGe,
  required List<TalentDef> catalogTalents,
  required List<WaffenmeisterConfig> waffenmeisterschaften,
}) {
  final selectedTalent = _findTalentDefById(catalogTalents, slot.talentId);
  final legacyRanged = isRangedCombatTalent(selectedTalent);
  final isRangedWeapon = slot.isRanged || legacyRanged;
  final wmEffects = computeWaffenmeisterEffects(
    waffenmeisterschaften: waffenmeisterschaften,
    activeWeaponType: slot.weaponType.trim().isEmpty ? slot.name : slot.weaponType,
    activeTalentId: slot.talentId,
  );
  final wmKkBase = slot.kkBase + wmEffects.tpKkBaseReduction;
  final wmKkThreshold = slot.kkThreshold + wmEffects.tpKkThresholdReduction;
  final kkThreshold = wmKkThreshold < 1 ? 1 : wmKkThreshold;
  final geBase = 26 - wmKkBase;
  final geThreshold = 7 - kkThreshold;
  final iniGe = computeIniGe(
    ge: effectiveGe,
    kkBase: wmKkBase,
    kkThreshold: kkThreshold,
  );
  final activeProjectile = slot.rangedProfile.selectedProjectileOrNull;
  final projectileIniMod = isRangedWeapon ? (activeProjectile?.iniMod ?? 0) : 0;
  final kombinierteIni = clampNonNegative(
    heldenInitiative +
        slot.iniMod +
        iniGe +
        projectileIniMod +
        wmEffects.iniBonus,
  );

  return _WeaponInitiativeSnapshot(
    geBase: geBase,
    geThreshold: geThreshold,
    iniGe: iniGe,
    projectileIniMod: projectileIniMod,
    waffenmeisterIniBonus: wmEffects.iniBonus,
    kombinierteIni: kombinierteIni,
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

