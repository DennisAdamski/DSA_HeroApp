import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/attributes_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';

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
    required this.offhandPaBonus,
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
  final int offhandPaBonus;
}

CombatPreviewStats computeCombatPreviewStats(
  HeroSheet sheet,
  HeroState state, {
  CombatConfig? overrideConfig,
  Map<String, HeroTalentEntry>? overrideTalents,
  List<TalentDef> catalogTalents = const <TalentDef>[],
}) {
  final parsed = parseModifierTextsForHero(sheet);
  final effectiveSheet = sheet.copyWith(
    attributes: computeEffectiveAttributes(
      sheet,
      tempAttributeMods: state.tempAttributeMods,
    ),
  );
  final mods = sheet.persistentMods + parsed.statMods + state.tempMods;
  final derived = computeDerivedStats(sheet, state);

  final config = overrideConfig ?? sheet.combatConfig;
  final talents = overrideTalents ?? sheet.talents;
  final main = config.selectedWeapon;
  final offhand = main.isOneHanded ? config.offhand : const OffhandSlot();
  final armor = config.armor;
  final special = config.specialRules;
  final manualMods = config.manualMods;

  final rgReduction = _computeRgReduction(
    level: sheet.level,
    armorTrainingLevel: armor.armorTrainingLevel,
    rgIActive: armor.rgIActive,
  );
  final beKampf = _clampNonNegative(armor.beTotalRaw - rgReduction);
  final selectedTalent = _findTalentDefById(catalogTalents, main.talentId);
  final beMod = selectedTalent == null
      ? main.beTalentMod
      : _parseBeModifier(selectedTalent.be);
  final ebe = _computeEbe(beKampf: beKampf, beMod: beMod);
  final specApplies = _hasCombatSpecialization(
    talents: talents,
    talentId: main.talentId,
    weaponType: main.weaponType.trim().isEmpty ? main.name : main.weaponType,
  );
  final specBonus = specApplies ? 1 : 0;

  final sfIniBonus = _computeSfIniBonus(special);
  final sfAusweichenBonus = _computeSfAusweichenBonus(special);
  final offhandPaBonus = _computeOffhandPaBonus(
    mode: offhand.mode,
    basePaMod: offhand.paMod,
    special: special,
  );

  final atBase = computeAt(effectiveSheet, mods);
  final paBase = computePa(effectiveSheet, mods);
  final talentEntry = main.talentId.trim().isEmpty
      ? null
      : talents[main.talentId.trim()];
  final talentAt = talentEntry?.atValue ?? 0;
  final talentPa = talentEntry?.paValue ?? 0;
  final kkThreshold = main.kkThreshold < 1 ? 1 : main.kkThreshold;
  final tpKk = _roundDownTowardsZero(
    (effectiveSheet.attributes.kk - main.kkBase) / kkThreshold,
  );
  final geBase = 26 - main.kkBase;
  final geThreshold = 7 - kkThreshold;
  final iniGe = geThreshold == 0
      ? 0
      : _roundDownTowardsZero(
          (effectiveSheet.attributes.ge - geBase) / geThreshold,
        );
  final tpCalc = main.tpFlat + tpKk + (special.axxeleratusActive ? 2 : 0);
  final atEbePart = _roundDownTowardsZero(ebe / 2);
  final paEbePart = _roundUpAwayFromZero(ebe / 2);

  final at =
      talentAt +
      atBase +
      main.wmAt +
      atEbePart +
      specBonus +
      offhand.atMod +
      manualMods.atMod;
  final pa =
      talentPa +
      paBase +
      main.wmPa +
      paEbePart +
      specBonus +
      offhandPaBonus +
      manualMods.paMod;

  final initiative = _clampNonNegative(
    derived.iniBase +
        iniGe +
        sfIniBonus +
        main.iniMod +
        offhand.iniMod +
        manualMods.iniMod,
  );
  final iniParadeMod = _max(0, _roundDownTowardsZero((initiative - 11) / 10));

  final ausweichen = _clampNonNegative(
    paBase +
        sfAusweichenBonus +
        _computeAkrobatikBonus(talents) +
        manualMods.ausweichenMod -
        beKampf,
  );

  return CombatPreviewStats(
    rsTotal: _clampNonNegative(armor.rsTotal),
    beTotalRaw: _clampNonNegative(armor.beTotalRaw),
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
    initiative: initiative,
    ausweichen: ausweichen,
    at: at,
    pa: pa,
    ebe: ebe,
    tpExpression: _tpExpression(main, tpCalc),
    specBonus: specBonus,
    akrobatikBonus: _computeAkrobatikBonus(talents),
    sfIniBonus: sfIniBonus,
    sfAusweichenBonus: sfAusweichenBonus,
    offhandPaBonus: offhandPaBonus,
  );
}

int _computeEbe({required int beKampf, required int beMod}) {
  return _min(0, -beKampf - beMod);
}

int _computeSfIniBonus(CombatSpecialRules special) {
  var total = 0;
  if (special.kampfreflexe) {
    total += 4;
  }
  if (special.kampfgespuer) {
    total += 2;
  }
  if (special.flink) {
    total += 1;
  }
  if (special.behaebig) {
    total -= 1;
  }
  if (special.axxeleratusActive) {
    total += 2;
  }
  return total;
}

int _computeSfAusweichenBonus(CombatSpecialRules special) {
  var total = 0;
  if (special.ausweichenI) {
    total += 3;
  }
  if (special.ausweichenII) {
    total += 3;
  }
  if (special.ausweichenIII) {
    total += 3;
  }
  if (special.flink) {
    total += 1;
  }
  if (special.behaebig) {
    total -= 1;
  }
  return total;
}

int _computeOffhandPaBonus({
  required OffhandMode mode,
  required int basePaMod,
  required CombatSpecialRules special,
}) {
  switch (mode) {
    case OffhandMode.none:
      return 0;
    case OffhandMode.linkhand:
      return basePaMod + 1;
    case OffhandMode.shield:
      if (special.schildkampfII) {
        return basePaMod + 5;
      }
      if (special.schildkampfI) {
        return basePaMod + 3;
      }
      if (special.linkhandActive) {
        return basePaMod + 1;
      }
      return basePaMod;
    case OffhandMode.parryWeapon:
      if (special.parierwaffenII) {
        return basePaMod + 2;
      }
      if (special.parierwaffenI) {
        return basePaMod - 1;
      }
      if (special.linkhandActive) {
        return basePaMod - 4;
      }
      return basePaMod;
  }
}

int _computeRgReduction({
  required int level,
  required int armorTrainingLevel,
  required bool rgIActive,
}) {
  if (!rgIActive) {
    return 0;
  }
  final normalizedTraining = _clamp(armorTrainingLevel, 0, 4);
  // TODO: Model RG IV exactly once the final house-rule formula is fixed.
  final effectiveTraining = normalizedTraining > 3 ? 3 : normalizedTraining;

  var maxByLevel = 0;
  if (level >= 7) {
    maxByLevel = 1;
  }
  if (level >= 14) {
    maxByLevel = 2;
  }
  if (level >= 21) {
    maxByLevel = 3;
  }
  return _min(effectiveTraining, maxByLevel);
}

int _computeAkrobatikBonus(Map<String, HeroTalentEntry> talents) {
  var akrobatikTaw = 0;
  for (final entry in talents.entries) {
    if (entry.key.toLowerCase().contains('akrobatik')) {
      akrobatikTaw = entry.value.talentValue + entry.value.modifier;
      break;
    }
  }
  return _max(0, ((akrobatikTaw - 9) / 3).floor());
}

bool _hasCombatSpecialization({
  required Map<String, HeroTalentEntry> talents,
  required String talentId,
  required String weaponType,
}) {
  final id = talentId.trim();
  final type = weaponType.trim();
  if (id.isEmpty || type.isEmpty) {
    return false;
  }

  final talentEntry = talents[id];
  if (talentEntry == null) {
    return false;
  }

  final weaponToken = _normalizeToken(type);
  if (weaponToken.isEmpty) {
    return false;
  }

  final specs = talentEntry.combatSpecializations.isEmpty
      ? talentEntry.specializations.split(RegExp(r'[\n,;]+'))
      : talentEntry.combatSpecializations;
  for (final raw in specs) {
    final token = _normalizeToken(raw);
    if (token.isEmpty) {
      continue;
    }
    if (token == weaponToken) {
      return true;
    }
    if (token.length >= 4 && weaponToken.contains(token)) {
      return true;
    }
    if (weaponToken.length >= 4 && token.contains(weaponToken)) {
      return true;
    }
  }

  return false;
}

String _normalizeToken(String raw) {
  var value = raw.trim().toLowerCase();
  value = value
      .replaceAll(String.fromCharCode(228), 'ae')
      .replaceAll(String.fromCharCode(246), 'oe')
      .replaceAll(String.fromCharCode(252), 'ue')
      .replaceAll(String.fromCharCode(223), 'ss');
  return value.replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

String _tpExpression(MainWeaponSlot main, int tpCalc) {
  final count = main.tpDiceCount < 1 ? 1 : main.tpDiceCount;
  if (tpCalc == 0) {
    return '${count}W6';
  }
  final sign = tpCalc > 0 ? '+' : '';
  return '${count}W6$sign$tpCalc';
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

int _parseBeModifier(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == '-') {
    return 0;
  }
  final parsed = int.tryParse(trimmed);
  return parsed ?? 0;
}

int _roundDownTowardsZero(num value) => value.truncate();

int _roundUpAwayFromZero(num value) {
  if (value == value.truncateToDouble()) {
    return value.toInt();
  }
  if (value > 0) {
    return value.ceil();
  }
  return value.floor();
}

int _max(int a, int b) => a > b ? a : b;
int _min(int a, int b) => a < b ? a : b;
int _clamp(int value, int min, int max) =>
    value < min ? min : (value > max ? max : value);
int _clampNonNegative(int value) => value < 0 ? 0 : value;
