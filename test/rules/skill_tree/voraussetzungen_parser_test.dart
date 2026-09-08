import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_models.dart';
import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/voraussetzungen_parser.dart';

void main() {
  group('parseVoraussetzungen', () {
    test('liefert leere Liste fuer leeren Text', () {
      expect(parseVoraussetzungen(''), isEmpty);
      expect(parseVoraussetzungen('   '), isEmpty);
    });

    test('parst eine einzelne Eigenschaftsvoraussetzung', () {
      expect(parseVoraussetzungen('IN 12'), const [
        AttributeRequirement('inn', 12),
      ]);
      expect(parseVoraussetzungen('GE 10'), const [
        AttributeRequirement('ge', 10),
      ]);
      expect(parseVoraussetzungen('KK 12'), const [
        AttributeRequirement('kk', 12),
      ]);
    });

    test('trennt Eigenschaft und SF-Verweis ueber Komma', () {
      expect(parseVoraussetzungen('GE 12, SF Linkhand'), const [
        AttributeRequirement('ge', 12),
        AbilityRequirement('Linkhand'),
      ]);
    });

    test('trennt Eigenschaft und mehrere SF ueber Semikolon und "und"', () {
      expect(
        parseVoraussetzungen('GE 12; SF Ausweichen I und Aufmerksamkeit'),
        const [
          AttributeRequirement('ge', 12),
          AbilityRequirement('Ausweichen I'),
          AbilityRequirement('Aufmerksamkeit'),
        ],
      );
    });

    test('behaelt die Stufe im SF-Namen', () {
      expect(parseVoraussetzungen('KK 12; SF Rüstungsgewöhnung I'), const [
        AttributeRequirement('kk', 12),
        AbilityRequirement('Rüstungsgewöhnung I'),
      ]);
    });

    test('setzt SF-Kontext fuer komma-getrennte Fortsetzungen fort', () {
      expect(
        parseVoraussetzungen('SF Kampfgespür, Klingensturm, Klingenwand'),
        const [
          AbilityRequirement('Kampfgespür'),
          AbilityRequirement('Klingensturm'),
          AbilityRequirement('Klingenwand'),
        ],
      );
    });

    test('parst TaW-Voraussetzungen', () {
      expect(parseVoraussetzungen('TaW Sinnesschärfe 15'), const [
        TalentRequirement('Sinnesschärfe', 15),
      ]);
      expect(parseVoraussetzungen('TaW Raufen 10, TaW Ringen 7'), const [
        TalentRequirement('Raufen', 10),
        TalentRequirement('Ringen', 7),
      ]);
    });

    test('parst TaW und SF gemischt', () {
      expect(parseVoraussetzungen('TaW Speere 10; SF Sturmangriff'), const [
        TalentRequirement('Speere', 10),
        AbilityRequirement('Sturmangriff'),
      ]);
    });

    test('parst Talentwert ohne TaW-Praefix', () {
      expect(parseVoraussetzungen('Selbstbeherrschung 15'), const [
        TalentRequirement('Selbstbeherrschung', 15),
      ]);
    });

    test('parst ZfW-Voraussetzungen', () {
      expect(parseVoraussetzungen('ZfW Arcanovi 21'), const [
        SpellRequirement('Arcanovi', 21),
      ]);
    });

    test('parst Oder-Eigenschaften mit gemeinsamem Wert', () {
      expect(parseVoraussetzungen('KL oder IN 20'), const [
        OrRequirement([
          AttributeRequirement('kl', 20),
          AttributeRequirement('inn', 20),
        ]),
      ]);
    });

    test('parst Vorteil und Rasse', () {
      expect(parseVoraussetzungen('Vorteil Beidhändig'), const [
        TraitRequirement('Beidhändig'),
      ]);
      expect(parseVoraussetzungen('Rasse Achaz'), const [
        RaceRequirement('Achaz'),
      ]);
    });

    test('fuehrt nicht parsbare Segmente als UnknownRequirement', () {
      expect(parseVoraussetzungen('Nachteil Blutrausch'), const [
        UnknownRequirement('Nachteil Blutrausch'),
      ]);
      expect(parseVoraussetzungen('Je nach Waffe'), const [
        UnknownRequirement('Je nach Waffe'),
      ]);
    });
  });
}
