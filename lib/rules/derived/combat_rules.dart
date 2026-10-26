import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/armatrutz_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ausweichen_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/epic_main_attribute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/excel_rounding.dart';
import 'package:dsa_heldenverwaltung/rules/derived/fernkampf_ladezeit_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ini_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampf_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampf_ini_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampfbasis_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ruestung_be_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/shield_parry_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_instance_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/two_weapon_combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/waffenmeister_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/unarmed_style_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/waffenlos_slot_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/waffen_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';

part 'combat_offhand_preview_rules.dart';

class CombatPreviewStats {
  const CombatPreviewStats({
    required this.rsTotal,
    required this.armatrutzRsBonus,
    required this.beTotalRaw,
    required this.rgReduction,
    required this.beKampf,
    required this.beMod,
    required this.usesTpKkThreshold,
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
    this.waffenlos = false,
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
    required this.epicFinteDefenseHint,
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
    this.schwertarmWundMalus = 0,
    this.schildarmWundMalus = 0,
    this.offhandPreview,
    this.twoWeaponCombat,
    this.herleitungen,
  });

  /// Erklärbare Herleitungen der Endwerte (ARCH-04); die Felder `at`, `pa`,
  /// `paMitIniParadeMod`, `tpCalc`, `heldenInitiative`, `kampfInitiative`,
  /// `ausweichen`, `rsTotal`, `beKampf` und `ebe` sind ihre Werte.
  /// `computeCombatPreviewStats` setzt sie immer.
  final KampfHerleitungen? herleitungen;

  final int rsTotal;

  /// Wirksamer Anteil des `Armatrutz` an [rsTotal] (hoechstens ZfW/2);
  /// 0, wenn der Zauber nicht laeuft.
  final int armatrutzRsBonus;
  final int beTotalRaw;
  final int rgReduction;
  final int beKampf;
  final int beMod;
  final bool usesTpKkThreshold;
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

  /// Ohne Waffe mit freien Händen: gerechnet wird Raufen (`waffenlos_slot_rules.dart`).
  final bool waffenlos;
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

  /// Armgebundener Wundabzug auf AT und PA der Hauptwaffe (Schwertarm,
  /// WdS S. 109). Bereits in [at] und [pa] enthalten; 0 bei Fernkampf.
  final int schwertarmWundMalus;

  /// Armgebundener Wundabzug auf Schild und Nebenhandwaffe (Schildarm).
  /// Bereits in [shieldPa] bzw. der Nebenhand-Vorschau enthalten.
  final int schildarmWundMalus;
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

  /// Anzeigehinweis der epischen IN-Haupteigenschaft (Finten gegen den
  /// Helden sind erschwert). Leer, wenn der Bonus nicht greift.
  final String epicFinteDefenseHint;
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

  /// Eigenstaendige Nebenhand-Vorschau; `null` = keine Nebenhand belegt.
  final OffhandCombatPreview? offhandPreview;

  /// Verdichtete Aktions- und Konfliktinformation fuer beidhändigen Kampf.
  final TwoWeaponCombatSnapshot? twoWeaponCombat;
}

/// Eigenstaendige Kampfwerte fuer die Nebenhand (Waffe, Schild oder
/// Parierwaffe).
class OffhandCombatPreview {
  const OffhandCombatPreview({
    required this.displayName,
    this.isWeapon = false,
    this.isShield = false,
    this.isParryWeapon = false,
    this.isRangedWeapon = false,
    this.at,
    this.pa,
    this.paMitIniParadeMod,
    this.tpExpression,
    this.tpCalc,
    this.damageDiceSpec,
    this.ebe,
    this.beMod,
    this.specApplies = false,
    this.reloadTime,
    this.reloadTimeDisplay,
    this.activeDistanceLabel,
    this.activeProjectileName,
    this.activeProjectileCount,
    this.mainPaMod,
    this.shieldPa,
    this.shieldPaMitIniParadeMod,
    this.atMod,
    this.iniMod,
    this.waffenmeisterActive = false,
    this.waffenmeisterName = '',
    this.waffenmeisterAdditionalManeuvers = const <String>[],
    this.waffenmeisterManeuverReductions = const <String, int>{},
    this.requiresLinkhandViolation = false,
    this.weaponInitiative,
    this.falseHandAtMod,
    this.falseHandPaMod,
    this.falseHandLabel,
    this.schildarmWundMalus = 0,
    this.herleitungen,
  });

  /// Erklärbare Herleitungen einer Nebenhandwaffe (ARCH-04); `null` bei
  /// Schild oder Parierwaffe.
  final NebenhandHerleitungen? herleitungen;

  final String displayName;
  final bool isWeapon;
  final bool isShield;
  final bool isParryWeapon;
  final bool isRangedWeapon;

  // Eigenstaendige Werte (nur bei Waffe)
  final int? at;
  final int? pa;
  final int? paMitIniParadeMod;
  final String? tpExpression;
  final int? tpCalc;
  final DiceSpec? damageDiceSpec;
  final int? ebe;
  final int? beMod;
  final bool specApplies;

  // Fernkampf (nur bei Fernkampf-Nebenhand)
  final int? reloadTime;
  final String? reloadTimeDisplay;
  final String? activeDistanceLabel;
  final String? activeProjectileName;
  final int? activeProjectileCount;

  /// Armgebundener Wundabzug des Schildarms, bereits in AT/PA bzw. Schild-PA
  /// enthalten (WdS S. 109).
  final int schildarmWundMalus;

  // Modifikator-basiert (Parierwaffe/Schild)
  final int? mainPaMod;
  final int? shieldPa;

  /// Schild-PA mit dem INI-Parade-Bonus der Kampfinitiative; `null` ohne Schild.
  final int? shieldPaMitIniParadeMod;
  final int? atMod;
  final int? iniMod;

  // Waffenmeister
  final bool waffenmeisterActive;
  final String waffenmeisterName;
  final List<String> waffenmeisterAdditionalManeuvers;
  final Map<String, int> waffenmeisterManeuverReductions;

  // Warnungen
  final bool requiresLinkhandViolation;

  // Waffen-INI (fuer Referenz)
  final int? weaponInitiative;

  // Falsche-Hand-Mali fuer attackefaehige Nebenhandwaffen.
  final int? falseHandAtMod;
  final int? falseHandPaMod;
  final String? falseHandLabel;
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
  WundEffekte wunden = const WundEffekte(),
  bool epicAdvantagesRuleActive = true,
  RulesCatalog? catalog,
}) {
  // [catalog] dient nur der Ersatzauswertung ohne [parsedModifiers]: Vor- und
  // Nachteile wirken damit über ihre Katalog-ID (ARCH-02).
  final parsed =
      parsedModifiers ?? parseModifierTextsForHero(sheet, catalog: catalog);
  final effective =
      effectiveAttributes ??
      applyAttributeModifiers(
        sheet.attributes,
        parsed.attributeMods + effektiveTempAttributeMods(state),
      );
  final effectiveSheet = sheet.copyWith(attributes: effective);
  final derived =
      derivedStats ??
      computeDerivedStatsFromInputs(
        sheet: sheet,
        state: state,
        parsedModifiers: parsed,
        effectiveAttributes: effective,
        wundStatMods: wundEffekteToStatModifiers(wunden),
      );
  // Dieselbe Modifikatorsumme wie die Basiswerte (benannte, Inventar- und
  // Wundmodifikatoren eingeschlossen); eine eigene, kleinere Summe liess
  // Wunden in AT/PA fehlen, obwohl AT-Basis und INI sie enthielten.
  final mods = derived.modifiers;

  final config = overrideConfig ?? sheet.combatConfig;
  final talents = overrideTalents ?? sheet.talents;
  // Ohne Waffe mit freien Händen kämpft der Held waffenlos (Raufen).
  final waffenlos = haendeFrei(config);
  final main = vorschauHauptwaffe(config);
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
  final falseHandModifiers = computeFalseHandModifiers(specialRules: special);
  final axxeleratusActive = isAxxeleratusEffectActive(
    sheet: sheet,
    state: state,
  );

  // --- Ruestung & Behinderung (ruestung_be_rules) ---
  final activeArmorPieces = armor.pieces
      .where((piece) => piece.isActive)
      .toList(growable: false);
  // Der Armatrutz legt eine rein magische Ruestung auf: Sein RS zaehlt zur
  // getragenen Ruestung hinzu, erzeugt aber bewusst keine Behinderung.
  // Gespeichert bleibt der eingetragene Wert; wirksam ist höchstens ZfW/2.
  final armatrutzGespeichert = computeArmatrutzRsBonus(
    sheet: sheet,
    state: state,
  );
  final armatrutzGrenze = armatrutzGespeichert > 0
      ? armatrutzRsGrenze(sheet: sheet)
      : null;
  final armatrutzRsBonus = begrenzeArmatrutzRs(
    gespeichert: armatrutzGespeichert,
    grenze: armatrutzGrenze,
  );
  final rsHerleitung = herleiteRuestungsschutz(
    aktiveTeile: activeArmorPieces,
    modifikatoren: mods.rs,
    armatrutz: armatrutzGespeichert,
    armatrutzGrenze: armatrutzGrenze,
    armatrutzZfw: armatrutzZfw(sheet),
  );
  final rsTotal = rsHerleitung.wert;
  final beTotalRaw = computeBeTotalRaw(activeArmorPieces);
  final rgReduction = computeRgReduction(
    globalArmorTrainingLevel: armor.globalArmorTrainingLevel,
    activePieces: activeArmorPieces,
  );
  final beHerleitung = herleiteBeKampf(
    aktiveTeile: activeArmorPieces,
    rgReduktion: rgReduction,
    ruestungsgewoehnung: armor.globalArmorTrainingLevel,
  );
  final beKampf = beHerleitung.wert;
  final selectedTalent = _findTalentDefById(catalogTalents, main.talentId);
  final legacyRanged = isRangedCombatTalent(selectedTalent);
  final isRangedWeapon = main.isRanged || legacyRanged;
  final beMod = selectedTalent == null
      ? main.beTalentMod
      : parseBeModifier(selectedTalent.be);
  final ebeHerleitung = herleiteEbe(
    beKampf: beKampf,
    beMod: beMod,
    talentName: selectedTalent?.name,
    talentBe: selectedTalent?.be,
  );
  final ebe = ebeHerleitung.wert;
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
  final usesTpKkThreshold = _usesTpKkThreshold(
    kkBase: main.kkBase,
    kkThreshold: main.kkThreshold,
  );
  final kkThreshold = usesTpKkThreshold && wmKkThreshold < 1
      ? 1
      : wmKkThreshold;
  // Karnifilo: KK +5 verbessert die TP (LC S. 136), ohne AT/PA neu zu rechnen.
  final zauberKk = derived.zauberEffekte.eigenschaftsMods.kk;
  final tpKkOhneZauber = usesTpKkThreshold
      ? computeTpKk(
          kk: effectiveSheet.attributes.kk,
          kkBase: wmKkBase,
          kkThreshold: kkThreshold,
        )
      : 0;
  final tpKk = usesTpKkThreshold && zauberKk != 0
      ? computeTpKk(
          kk: effectiveSheet.attributes.kk + zauberKk,
          kkBase: wmKkBase,
          kkThreshold: kkThreshold,
        )
      : tpKkOhneZauber;
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
    beKampf: beKampf,
  );
  final distanceTpMod = isRangedWeapon ? activeDistanceBand.tpMod : 0;
  final projectileTpMod = isRangedWeapon ? (activeProjectile?.tpMod ?? 0) : 0;
  final projectileIniMod = isRangedWeapon ? (activeProjectile?.iniMod ?? 0) : 0;
  final projectileAtMod = isRangedWeapon ? (activeProjectile?.atMod ?? 0) : 0;
  final tpHerleitung = herleiteTpZuschlag(
    tpGrundwert: main.tpFlat,
    waffenName: main.name,
    nutztTpKk: usesTpKkThreshold,
    tpKk: tpKkOhneZauber,
    kk: effectiveSheet.attributes.kk,
    kkBasis: wmKkBase,
    kkSchwelle: kkThreshold,
    waffenmeisterKkBasis: wmEffects.tpKkBaseReduction,
    waffenmeisterKkSchwelle: wmEffects.tpKkThresholdReduction,
    zauberTpKk: tpKk - tpKkOhneZauber,
    zauberKk: zauberKk,
    zauberName: zauberEigenschaftsName(derived.zauberEffekte),
    axxeleratus: axxTpBonus,
    entfernung: distanceTpMod,
    entfernungLabel: isRangedWeapon ? activeDistanceBand.label : null,
    geschoss: projectileTpMod,
    geschossName: activeProjectile?.name,
  );
  final tpCalc = tpHerleitung.wert;

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
    paBasis: computePa(effectiveSheet, mods),
    axxeleratusPa: computeAxxeleratusPaBaseBonus(
      axxeleratusActive: axxeleratusActive,
    ),
    schildarmWundMalus: wunden.schildarmAtPaMalus,
    paradeBehinderung: paEbePart,
    ebe: ebe,
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
  // Armwunden treffen AT/PA im Nahkampf, nicht den Fernkampf (WdS S. 109).
  final schwertarmWundMalus = isRangedWeapon ? 0 : wunden.schwertarmAtPaMalus;
  final waffenName = main.name;
  final atHerleitung = isRangedWeapon
      ? herleiteFernkampfAt(
          fkBasis: rangedAtBase,
          talentAt: talentAt,
          talentName: selectedTalent?.name,
          waffenWm: main.wmAt,
          waffenName: waffenName,
          waffenmeister: wmEffects.atWmBonus,
          ebe: rangedAtEbePart,
          spezialisierung: atSpecBonus,
          geschoss: projectileAtMod,
          geschossName: activeProjectile?.name,
          manuell: manualMods.atMod,
          zauberMalus: derived.zauberEffekte.fernkampfMalus,
          zauberName: derived.zauberEffekte.fernkampfQuelle,
        )
      : herleiteNahkampfAt(
          atBasis: atBase,
          talentAt: talentAt,
          talentName: selectedTalent?.name,
          waffenWm: main.wmAt,
          waffenName: waffenName,
          waffenmeister: wmEffects.atWmBonus,
          ebe: ebe,
          ebeAnteil: atEbePart,
          spezialisierung: atSpecBonus,
          kampfstil: unarmedStyleEffects.atBonus,
          nebenhand: offhandModifiers.atMod,
          nebenhandName: offhandModifiers.displayName,
          armWunden: schwertarmWundMalus,
          manuell: manualMods.atMod,
        );
  final at = atHerleitung.wert;
  final paHerleitung = isRangedWeapon
      ? null
      : herleiteNahkampfPa(
          paBasis: basePa,
          axxeleratus: axxPaBaseBonus,
          talentPa: talentPa,
          talentName: selectedTalent?.name,
          waffenWm: main.wmPa,
          waffenName: waffenName,
          waffenmeister: wmEffects.paWmBonus,
          ebe: ebe,
          ebeAnteil: paEbePart,
          spezialisierung: paSpecBonus,
          kampfstil: unarmedStyleEffects.paBonus,
          nebenhand: offhandModifiers.isParryWeapon
              ? offhandModifiers.parierwaffeWm
              : offhandModifiers.mainPaMod,
          nebenhandName: offhandModifiers.displayName,
          parierwaffeSf: offhandModifiers.parierwaffeSf,
          parierwaffeSfName: offhandModifiers.parierwaffeSfName,
          armWunden: schwertarmWundMalus,
          manuell: manualMods.paMod,
        );
  final pa = paHerleitung?.wert ?? 0;

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
  final heldenIniHerleitung = herleiteHeldenIni(
    iniBasis: iniBasis,
    beKampf: beKampf,
    sfBonus: sfIniBonus,
    kampfstil: unarmedStyleEffects.iniMod,
    iniWurf: iniWurfEffective,
    wuerfel: iniDiceCount,
    axxeleratus: axxIniBonus,
    zauberMalus: derived.zauberEffekte.heldenIniMalus,
    zauberName: derived.zauberEffekte.heldenIniQuelle,
    manuell: manualMods.iniMod,
  );
  final heldenInitiative = heldenIniHerleitung.wert;
  final initiativeSnapshot = _computeWeaponInitiativeSnapshot(
    slot: main,
    heldenIni: heldenIniHerleitung,
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
          heldenIni: heldenIniHerleitung,
          effectiveGe: effectiveSheet.attributes.ge,
          catalogTalents: catalogTalents,
          waffenmeisterschaften: config.waffenmeisterschaften,
        ).kombinierteIni;
  final kampfIniHerleitung = herleiteKampfIni(
    waffenIni: initiativeSnapshot.herleitung,
    nebenhandWaffenIni: offhandWeaponInitiative,
    nebenhandIniMod: offhandModifiers.iniMod,
    nebenhandName: offhandWeapon?.name ?? offhandModifiers.displayName,
  );
  final kampfInitiative = kampfIniHerleitung.wert;
  final initiative = kampfInitiative;
  final iniParadeMod = computeIniParadeMod(kampfInitiative);
  final paMitIniHerleitung = paHerleitung == null
      ? null
      : herleitePaMitIniParade(
          pa: paHerleitung,
          iniParadeMod: iniParadeMod,
          kampfInitiative: kampfInitiative,
        );
  final paMitIniParadeMod = paMitIniHerleitung?.wert ?? 0;

  // --- Ausweichen (ausweichen_rules) ---
  final akrobatikBonusValue = computeAkrobatikBonus(talents);
  final axxAusweichenBonus = computeAxxeleratusAusweichenBonus(
    axxeleratusActive: axxeleratusActive,
  );
  final iniAusweichenBonus = computeIniAusweichenBonus(
    kampfInitiative: kampfInitiative,
  );
  final ausweichenHerleitung = herleiteAusweichen(
    paBasis: basePa,
    axxeleratusPaBasis: axxPaBaseBonus,
    sfBonus: sfAusweichenBonus,
    akrobatik: akrobatikBonusValue,
    axxeleratus: axxAusweichenBonus,
    iniBonus: iniAusweichenBonus,
    kampfInitiative: kampfInitiative,
    manuell: manualMods.ausweichenMod,
    flink: parsed.hasFlinkFromVorteile,
    behaebig: parsed.hasBehaebigFromNachteile,
    beKampf: beKampf,
  );
  final ausweichen = ausweichenHerleitung.wert;
  final axxAttackDefenseHint = buildAxxeleratusDefenseHint(
    axxeleratusActive: axxeleratusActive,
  );
  final epicFinteDefenseHint = buildEpicFinteDefenseHint(
    ruleActive: epicAdvantagesRuleActive,
    isEpisch: sheet.isEpisch,
    mainAttributes: sheet.epicMainAttributes,
  );

  // --- Nebenhand-Vorschau ---
  final offhandPreview = _buildOffhandPreview(
    offhandWeapon: offhandWeapon,
    offhandEquipment: offhandEquipment,
    offhandModifiers: offhandModifiers,
    falseHandModifiers: falseHandModifiers,
    talents: talents,
    catalogTalents: catalogTalents,
    config: config,
    effectiveSheet: effectiveSheet,
    derived: derived,
    beKampf: beKampf,
    atBase: atBase,
    basePa: basePa,
    axxPaBaseBonus: axxPaBaseBonus,
    iniParadeMod: iniParadeMod,
    kampfInitiative: kampfInitiative,
    axxeleratusActive: axxeleratusActive,
    axxTpBonus: axxTpBonus,
    schildarmWundMalus: wunden.schildarmAtPaMalus,
  );
  final offhandAttackTarget = offhandPreview?.at;
  final offhandParryTarget =
      offhandPreview?.paMitIniParadeMod ?? offhandPreview?.pa;
  final twoWeaponCombat = (offhandWeapon == null && offhandEquipment == null)
      ? null
      : computeTwoWeaponCombatSnapshot(
          specialRules: special,
          mainWeapon: main,
          offhandWeapon: offhandWeapon,
          offhandEquipment: offhandEquipment,
          falseHandModifiers: falseHandModifiers,
          mainAttackTarget: at,
          mainParryTarget: paMitIniParadeMod,
          offhandAttackTarget: offhandAttackTarget,
          offhandParryTarget: offhandParryTarget,
          offhandRequiresLinkhandViolation:
              offhandModifiers.requiresLinkhandViolation,
        );

  return CombatPreviewStats(
    herleitungen: KampfHerleitungen(
      rs: rsHerleitung,
      beKampf: beHerleitung,
      ebe: ebeHerleitung,
      at: atHerleitung,
      pa: paHerleitung,
      paMitIniParade: paMitIniHerleitung,
      tpZuschlag: tpHerleitung,
      heldenIni: heldenIniHerleitung,
      kampfIni: kampfIniHerleitung,
      ausweichen: ausweichenHerleitung,
      schildPa: offhandModifiers.schildPaHerleitung,
      schildPaMitIniParade: offhandModifiers.schildPaHerleitung == null
          ? null
          : herleitePaMitIniParade(
              pa: offhandModifiers.schildPaHerleitung!,
              iniParadeMod: iniParadeMod,
              kampfInitiative: kampfInitiative,
              bezeichnung: 'Schild-PA',
            ),
    ),
    rsTotal: rsTotal,
    armatrutzRsBonus: armatrutzRsBonus,
    beTotalRaw: clampNonNegative(beTotalRaw),
    rgReduction: rgReduction,
    beKampf: beKampf,
    beMod: beMod,
    usesTpKkThreshold: usesTpKkThreshold,
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
    waffenlos: waffenlos,
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
    epicFinteDefenseHint: epicFinteDefenseHint,
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
    offhandPreview: offhandPreview,
    twoWeaponCombat: twoWeaponCombat,
    schwertarmWundMalus: schwertarmWundMalus,
    schildarmWundMalus: wunden.schildarmAtPaMalus,
  );
}
