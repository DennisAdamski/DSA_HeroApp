import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';

import 'package:dsa_heldenverwaltung/rules/derived/attributes_rules.dart';
import 'modifier_parser.dart';

class DerivedStats {
  const DerivedStats({
    required this.maxLep,
    required this.maxAu,
    required this.maxAsp,
    required this.maxKap,
    required this.mr,
    required this.iniBase,
    required this.gs,
    required this.ausweichen,
  });

  final int maxLep;
  final int maxAu;
  final int maxAsp;
  final int maxKap;
  final int mr;
  final int iniBase;
  final int gs;
  final int ausweichen;
}

DerivedStats computeDerivedStats(HeroSheet sheet, HeroState state) {
  final parsed = parseModifierTextsForHero(sheet);
  final effectiveSheet = sheet.copyWith(attributes: _applyAttributeModifiers(sheet.attributes, parsed.attributeMods));
  final mods = sheet.persistentMods + parsed.statMods + state.tempMods;

  return DerivedStats(
    maxLep: computeMaxLep(effectiveSheet, mods),
    maxAu: computeMaxAu(effectiveSheet, mods),
    maxAsp: computeMaxAsp(effectiveSheet, mods),
    maxKap: computeMaxKap(effectiveSheet, mods),
    mr: computeMr(effectiveSheet, mods),
    iniBase: computeIniBase(effectiveSheet, mods),
    gs: computeGs(effectiveSheet, mods),
    ausweichen: computeAusweichen(effectiveSheet, mods),
  );
}

Attributes _applyAttributeModifiers(Attributes base, AttributeModifierSums mods) {
  return base.copyWith(
    mu: base.mu + mods.mu,
    kl: base.kl + mods.kl,
    inn: base.inn + mods.inn,
    ch: base.ch + mods.ch,
    ff: base.ff + mods.ff,
    ge: base.ge + mods.ge,
    ko: base.ko + mods.ko,
    kk: base.kk + mods.kk,
  );
}
