import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_source_breakdown.dart';

const _defaultAttributes = Attributes(
  mu: 10, kl: 10, inn: 10, ch: 10, ff: 10, ge: 10, ko: 10, kk: 10,
);

HeroSheet _makeHero({
  String rasseModText = '',
  String kulturModText = '',
  String professionModText = '',
  String vorteileText = '',
  String nachteileText = '',
  Map<String, List<HeroTalentModifier>> statModifiers =
      const <String, List<HeroTalentModifier>>{},
  Map<String, List<HeroTalentModifier>> attributeModifiers =
      const <String, List<HeroTalentModifier>>{},
}) {
  return HeroSheet(
    id: 'test',
    name: 'Test',
    level: 1,
    attributes: _defaultAttributes,
    background: HeroBackground(
      rasseModText: rasseModText,
      kulturModText: kulturModText,
      professionModText: professionModText,
    ),
    vorteileText: vorteileText,
    nachteileText: nachteileText,
    statModifiers: statModifiers,
    attributeModifiers: attributeModifiers,
  );
}

void main() {
  group('computeModifierSourceBreakdown', () {
    test('trennt Quellen korrekt', () {
      final hero = _makeHero(
        rasseModText: 'LE+2',
        kulturModText: 'MU+1',
        professionModText: 'GS+1',
        vorteileText: 'KL+3',
        nachteileText: 'KK-1',
      );
      final breakdown = computeModifierSourceBreakdown(hero);

      expect(breakdown.rasseStatMods.lep, 2);
      expect(breakdown.kulturAttributeMods.mu, 1);
      expect(breakdown.professionStatMods.gs, 1);
      expect(breakdown.vorteileAttributeMods.kl, 3);
      expect(breakdown.nachteileAttributeMods.kk, -1);
    });

    test('Summe der Quellen entspricht aggregiertem Ergebnis', () {
      final hero = _makeHero(
        rasseModText: 'LE+2, MU-1',
        kulturModText: 'LE+1',
        professionModText: 'MR+1',
        vorteileText: 'KL+1, LE+3',
        nachteileText: 'GS-1',
      );
      final breakdown = computeModifierSourceBreakdown(hero);
      final aggregated = parseModifierTextsForHero(hero);

      final totalLep =
          breakdown.rasseStatMods.lep +
          breakdown.kulturStatMods.lep +
          breakdown.professionStatMods.lep +
          breakdown.vorteileStatMods.lep +
          breakdown.nachteileStatMods.lep;
      expect(totalLep, aggregated.statMods.lep);

      final totalMu =
          breakdown.rasseAttributeMods.mu +
          breakdown.kulturAttributeMods.mu +
          breakdown.professionAttributeMods.mu +
          breakdown.vorteileAttributeMods.mu +
          breakdown.nachteileAttributeMods.mu;
      expect(totalMu, aggregated.attributeMods.mu);

      final totalGs =
          breakdown.rasseStatMods.gs +
          breakdown.kulturStatMods.gs +
          breakdown.professionStatMods.gs +
          breakdown.vorteileStatMods.gs +
          breakdown.nachteileStatMods.gs;
      expect(totalGs, aggregated.statMods.gs);
    });

    test('leere Texte erzeugen Null-Breakdown', () {
      final hero = _makeHero();
      final breakdown = computeModifierSourceBreakdown(hero);

      expect(breakdown.rasseStatMods.lep, 0);
      expect(breakdown.vorteileAttributeMods.mu, 0);
    });
  });

  group('aggregateNamedStatModifiers', () {
    test('summiert benannte Modifikatoren pro Stat-Key', () {
      final mods = <String, List<HeroTalentModifier>>{
        'lep': [
          HeroTalentModifier(modifier: 2, description: 'Artefakt'),
          HeroTalentModifier(modifier: 1, description: 'Segen'),
        ],
        'mr': [
          HeroTalentModifier(modifier: -1, description: 'Fluch'),
        ],
      };
      final result = aggregateNamedStatModifiers(mods);

      expect(result.lep, 3);
      expect(result.mr, -1);
      expect(result.au, 0);
    });

    test('leere Map ergibt Null-StatModifiers', () {
      final result = aggregateNamedStatModifiers(
        const <String, List<HeroTalentModifier>>{},
      );
      expect(result.lep, 0);
      expect(result.mr, 0);
    });
  });

  group('aggregateNamedAttributeModifiers', () {
    test('summiert benannte Modifikatoren pro Eigenschaft', () {
      final mods = <String, List<HeroTalentModifier>>{
        'mu': [
          HeroTalentModifier(modifier: 1, description: 'Mut-Amulett'),
        ],
        'ge': [
          HeroTalentModifier(modifier: -2, description: 'Verletzung'),
          HeroTalentModifier(modifier: 1, description: 'Training'),
        ],
      };
      final result = aggregateNamedAttributeModifiers(mods);

      expect(result.mu, 1);
      expect(result.ge, -1);
      expect(result.kl, 0);
    });
  });

  group('statModValue', () {
    test('extrahiert korrekten Wert per Key', () {
      const mods = StatModifiers(lep: 5, mr: -2, gs: 1);
      expect(statModValue(mods, 'lep'), 5);
      expect(statModValue(mods, 'mr'), -2);
      expect(statModValue(mods, 'gs'), 1);
      expect(statModValue(mods, 'au'), 0);
      expect(statModValue(mods, 'unbekannt'), 0);
    });
  });

  group('attributeModValue', () {
    test('extrahiert korrekten Wert per Key', () {
      const mods = AttributeModifiers(mu: 3, kk: -1);
      expect(attributeModValue(mods, 'mu'), 3);
      expect(attributeModValue(mods, 'kk'), -1);
      expect(attributeModValue(mods, 'kl'), 0);
      expect(attributeModValue(mods, 'unbekannt'), 0);
    });
  });
}
