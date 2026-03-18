import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';

/// Pro-Quellen-Aufschluesselung der geparsten Modifikatoren.
class ModifierSourceBreakdown {
  const ModifierSourceBreakdown({
    this.rasseStatMods = const StatModifiers(),
    this.rasseAttributeMods = const AttributeModifiers(),
    this.kulturStatMods = const StatModifiers(),
    this.kulturAttributeMods = const AttributeModifiers(),
    this.professionStatMods = const StatModifiers(),
    this.professionAttributeMods = const AttributeModifiers(),
    this.vorteileStatMods = const StatModifiers(),
    this.vorteileAttributeMods = const AttributeModifiers(),
    this.nachteileStatMods = const StatModifiers(),
    this.nachteileAttributeMods = const AttributeModifiers(),
  });

  final StatModifiers rasseStatMods;
  final AttributeModifiers rasseAttributeMods;
  final StatModifiers kulturStatMods;
  final AttributeModifiers kulturAttributeMods;
  final StatModifiers professionStatMods;
  final AttributeModifiers professionAttributeMods;
  final StatModifiers vorteileStatMods;
  final AttributeModifiers vorteileAttributeMods;
  final StatModifiers nachteileStatMods;
  final AttributeModifiers nachteileAttributeMods;
}

/// Berechnet die per-Quellen-Aufschluesselung fuer einen Helden.
///
/// Wird nur on-tap berechnet (kein Caching noetig).
ModifierSourceBreakdown computeModifierSourceBreakdown(HeroSheet hero) {
  const empty = '';
  final rasse = parseModifierTexts(
    rasseModText: hero.background.rasseModText,
    kulturModText: empty,
    professionModText: empty,
    vorteileText: empty,
    nachteileText: empty,
  );
  final kultur = parseModifierTexts(
    rasseModText: empty,
    kulturModText: hero.background.kulturModText,
    professionModText: empty,
    vorteileText: empty,
    nachteileText: empty,
  );
  final profession = parseModifierTexts(
    rasseModText: empty,
    kulturModText: empty,
    professionModText: hero.background.professionModText,
    vorteileText: empty,
    nachteileText: empty,
  );
  final vorteile = parseModifierTexts(
    rasseModText: empty,
    kulturModText: empty,
    professionModText: empty,
    vorteileText: hero.vorteileText,
    nachteileText: empty,
  );
  final nachteile = parseModifierTexts(
    rasseModText: empty,
    kulturModText: empty,
    professionModText: empty,
    vorteileText: empty,
    nachteileText: hero.nachteileText,
  );

  return ModifierSourceBreakdown(
    rasseStatMods: rasse.statMods,
    rasseAttributeMods: rasse.attributeMods,
    kulturStatMods: kultur.statMods,
    kulturAttributeMods: kultur.attributeMods,
    professionStatMods: profession.statMods,
    professionAttributeMods: profession.attributeMods,
    vorteileStatMods: vorteile.statMods,
    vorteileAttributeMods: vorteile.attributeMods,
    nachteileStatMods: nachteile.statMods,
    nachteileAttributeMods: nachteile.attributeMods,
  );
}

/// Aggregiert benannte Stat-Modifikatoren zu einem StatModifiers-Objekt.
StatModifiers aggregateNamedStatModifiers(
  Map<String, List<HeroTalentModifier>> statModifiers,
) {
  int sum(String key) {
    final list = statModifiers[key];
    if (list == null || list.isEmpty) {
      return 0;
    }
    var total = 0;
    for (final entry in list) {
      total += entry.modifier;
    }
    return total;
  }

  return StatModifiers(
    lep: sum('lep'),
    au: sum('au'),
    asp: sum('asp'),
    kap: sum('kap'),
    mr: sum('mr'),
    iniBase: sum('iniBase'),
    at: sum('at'),
    pa: sum('pa'),
    fk: sum('fk'),
    gs: sum('gs'),
    ausweichen: sum('ausweichen'),
    rs: sum('rs'),
  );
}

/// Aggregiert benannte Eigenschafts-Modifikatoren zu einem AttributeModifiers-Objekt.
AttributeModifiers aggregateNamedAttributeModifiers(
  Map<String, List<HeroTalentModifier>> attributeModifiers,
) {
  int sum(String key) {
    final list = attributeModifiers[key];
    if (list == null || list.isEmpty) {
      return 0;
    }
    var total = 0;
    for (final entry in list) {
      total += entry.modifier;
    }
    return total;
  }

  return AttributeModifiers(
    mu: sum('mu'),
    kl: sum('kl'),
    inn: sum('inn'),
    ch: sum('ch'),
    ff: sum('ff'),
    ge: sum('ge'),
    ko: sum('ko'),
    kk: sum('kk'),
  );
}

/// Extrahiert einen einzelnen Stat-Wert aus StatModifiers per String-Key.
int statModValue(StatModifiers mods, String statKey) {
  switch (statKey) {
    case 'lep':
      return mods.lep;
    case 'au':
      return mods.au;
    case 'asp':
      return mods.asp;
    case 'kap':
      return mods.kap;
    case 'mr':
      return mods.mr;
    case 'iniBase':
      return mods.iniBase;
    case 'at':
      return mods.at;
    case 'pa':
      return mods.pa;
    case 'fk':
      return mods.fk;
    case 'gs':
      return mods.gs;
    case 'ausweichen':
      return mods.ausweichen;
    case 'rs':
      return mods.rs;
    default:
      return 0;
  }
}

/// Extrahiert einen einzelnen Attribut-Wert aus AttributeModifiers per String-Key.
int attributeModValue(AttributeModifiers mods, String attrKey) {
  switch (attrKey) {
    case 'mu':
      return mods.mu;
    case 'kl':
      return mods.kl;
    case 'inn':
      return mods.inn;
    case 'ch':
      return mods.ch;
    case 'ff':
      return mods.ff;
    case 'ge':
      return mods.ge;
    case 'ko':
      return mods.ko;
    case 'kk':
      return mods.kk;
    default:
      return 0;
  }
}
