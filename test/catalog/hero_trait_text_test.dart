import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/hero_trait_def.dart';
import 'package:dsa_heldenverwaltung/catalog/hero_trait_text.dart';

void main() {
  group('parseTraitFragmentValue', () {
    test('Rundtrip mit buildHeroTraitSelectionText (nur {value})', () {
      const trait = HeroTraitDef(
        id: 'nd_jaehzorn',
        name: 'Jähzorn',
        traitType: 'disadvantage',
        valueKind: 'level',
        selectionTemplate: 'Jähzorn {value}',
        minValue: 1,
        maxValue: 3,
      );
      final fragment = buildHeroTraitSelectionText(trait: trait, value: 3);
      expect(fragment, 'Jähzorn 3');
      expect(parseTraitFragmentValue(fragment, trait), 3);
    });

    test('Rundtrip mit {choice} und {value} gemeinsam', () {
      const trait = HeroTraitDef(
        id: 'nd_angst',
        name: 'Angst vor',
        traitType: 'disadvantage',
        valueKind: 'level',
        selectionTemplate: 'Angst vor {choice} {value}',
        minValue: 1,
        maxValue: 3,
      );
      final fragment = buildHeroTraitSelectionText(
        trait: trait,
        choice: 'Spinnen',
        value: 2,
      );
      expect(fragment, 'Angst vor Spinnen 2');
      expect(parseTraitFragmentValue(fragment, trait), 2);
    });

    test('liefert null ohne {value} im Template', () {
      const trait = HeroTraitDef(
        id: 'vt_verbindungen',
        name: 'Verbindungen',
        traitType: 'advantage',
        valueKind: 'binary',
        selectionTemplate: 'Verbindungen',
      );
      expect(
        parseTraitFragmentValue('Verbindungen', trait),
        isNull,
      );
    });

    test('liefert null bei nicht passendem Fragment', () {
      const trait = HeroTraitDef(
        id: 'nd_jaehzorn',
        name: 'Jähzorn',
        traitType: 'disadvantage',
        valueKind: 'level',
        selectionTemplate: 'Jähzorn {value}',
      );
      expect(parseTraitFragmentValue('Etwas ganz anderes', trait), isNull);
    });

    test('faellt auf trait.name zurueck, wenn Template leer ist', () {
      const trait = HeroTraitDef(
        id: 'nd_x',
        name: 'X {value}',
        traitType: 'disadvantage',
        valueKind: 'level',
      );
      expect(parseTraitFragmentValue('X 5', trait), 5);
    });
  });
}
