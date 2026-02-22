import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/bought_stats.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';

void main() {
  test('derived stats compute with current formulas and modifiers', () {
    const hero = HeroSheet(
      id: 'h1',
      name: 'Testheld',
      level: 30,
      attributes: Attributes(mu: 14, kl: 12, inn: 13, ch: 11, ff: 10, ge: 12, ko: 14, kk: 13),
      bought: BoughtStats(lep: 1, au: 2, asp: 3, kap: 4, mr: 5),
      persistentMods: StatModifiers(lep: 1, au: 1, asp: 1, kap: 1, mr: 1, iniBase: 1),
    );

    const state = HeroState(
      currentLep: 0,
      currentAsp: 0,
      currentKap: 0,
      currentAu: 0,
      tempMods: StatModifiers(lep: 1, au: 1, asp: 1, kap: 1, mr: 1, iniBase: 1),
    );

    final d = computeDerivedStats(hero, state);

    expect(d.maxLep, 45);
    expect(d.maxAu, 84);
    expect(d.maxAsp, 84);
    expect(d.maxKap, 6);
    expect(d.mr, 15);
    expect(d.iniBase, 13);
  });

  test('negative resources are clamped to zero', () {
    const hero = HeroSheet(
      id: 'h2',
      name: 'Negativheld',
      level: 1,
      attributes: Attributes(mu: 1, kl: 1, inn: 1, ch: 1, ff: 1, ge: 1, ko: 1, kk: 1),
      persistentMods: StatModifiers(lep: -50, au: -50, asp: -50, kap: -50, mr: -50),
    );

    const state = HeroState(
      currentLep: 0,
      currentAsp: 0,
      currentKap: 0,
      currentAu: 0,
    );

    final d = computeDerivedStats(hero, state);

    expect(d.maxLep, 0);
    expect(d.maxAu, 0);
    expect(d.maxAsp, 0);
    expect(d.maxKap, 0);
    expect(d.mr, 0);
  });
}





