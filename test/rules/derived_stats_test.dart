import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
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
      attributes: Attributes(
        mu: 14,
        kl: 12,
        inn: 13,
        ch: 11,
        ff: 10,
        ge: 12,
        ko: 14,
        kk: 13,
      ),
      bought: BoughtStats(lep: 1, au: 2, asp: 3, kap: 4, mr: 5),
      persistentMods: StatModifiers(
        lep: 1,
        au: 1,
        asp: 1,
        kap: 1,
        mr: 1,
        iniBase: 1,
      ),
    );

    const state = HeroState(
      currentLep: 0,
      currentAsp: 0,
      currentKap: 0,
      currentAu: 0,
      tempMods: StatModifiers(lep: 1, au: 1, asp: 1, kap: 1, mr: 1, iniBase: 1),
      tempAttributeMods: AttributeModifiers(mu: 4),
    );

    final d = computeDerivedStats(hero, state);

    expect(d.maxLep, 45);
    // Au und AsP nutzen permanente Attribute (ohne tempAttributeMods MU+4):
    // Au  = round((14+14+12)/2) + 2 + 2 + 60 = 84
    // AsP = round((14+13+11)/2) + 2 + 3 + 60 = 84
    expect(d.maxAu, 84);
    expect(d.maxAsp, 84);
    expect(d.maxKap, 6);
    // MR nutzt effektive Attribute (mit MU+4): round((18+12+14)/5) + 2 + 5 = 16
    expect(d.mr, 16);
    // INI nutzt effektive Attribute (mit MU+4): round((18+18+13+12)/5) + 2 = 14
    expect(d.iniBase, 14);
  });

  test(
    'tempAttributeMods beeinflussen LeP/Au/AsP nicht, aber AT und INI schon',
    () {
      // Attributo: MU+4 und KO+3 – Ressourcen-Maxima bleiben an permanenten
      // Attributen, Kampfwerte werden mit den effektiven Attributen berechnet.
      const hero = HeroSheet(
        id: 'h3',
        name: 'Attributo-Held',
        level: 0,
        attributes: Attributes(
          mu: 14,
          kl: 12,
          inn: 13,
          ch: 11,
          ff: 10,
          ge: 12,
          ko: 14,
          kk: 13,
        ),
        bought: BoughtStats(),
        persistentMods: StatModifiers(),
      );
      const state = HeroState(
        currentLep: 0,
        currentAsp: 0,
        currentKap: 0,
        currentAu: 0,
        tempAttributeMods: AttributeModifiers(mu: 4, ko: 3),
      );

      final d = computeDerivedStats(hero, state);

      // Ressourcen-Maxima: permanente Attribute (ohne Attributo-Boni)
      // LeP = round((14+14+13)/2) = round(20.5) = 21
      expect(d.maxLep, 21);
      // Au  = round((14+14+12)/2) = round(20.0) = 20
      expect(d.maxAu, 20);
      // AsP = round((14+13+11)/2) = round(19.0) = 19
      expect(d.maxAsp, 19);

      // Kampfwerte: effektive Attribute (mit MU+4, KO+3)
      // INI = round((18+18+13+12)/5) = round(12.2) = 12
      expect(d.iniBase, 12);
      // AT  = round((18+12+13)/5)  = round(8.6)  = 9
      expect(d.atBase, 9);
    },
  );

  test('negative resources are clamped to zero', () {
    const hero = HeroSheet(
      id: 'h2',
      name: 'Negativheld',
      level: 1,
      attributes: Attributes(
        mu: 1,
        kl: 1,
        inn: 1,
        ch: 1,
        ff: 1,
        ge: 1,
        ko: 1,
        kk: 1,
      ),
      persistentMods: StatModifiers(
        lep: -50,
        au: -50,
        asp: -50,
        kap: -50,
        mr: -50,
      ),
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

  test('standard named advantages and disadvantages affect resources', () {
    const hero = HeroSheet(
      id: 'h4',
      name: 'Standardmods',
      level: 0,
      attributes: Attributes(
        mu: 12,
        kl: 12,
        inn: 13,
        ch: 11,
        ff: 10,
        ge: 12,
        ko: 14,
        kk: 12,
      ),
      vorteileText:
          'Hohe Lebenskraft 3, Ausdauernd 4, Astralmacht 5, '
          'Hohe Magieresistenz 2',
      nachteileText:
          'Niedrige Lebenskraft 1, Kurzatmig 2, '
          'Niedrige Astralenergie 3, Niedrige Magieresistenz 1',
    );
    const state = HeroState(
      currentLep: 0,
      currentAsp: 0,
      currentKap: 0,
      currentAu: 0,
    );

    final d = computeDerivedStats(hero, state);

    expect(d.maxLep, 22);
    expect(d.maxAu, 21);
    expect(d.maxAsp, 20);
    expect(d.mr, 9);
  });
}
