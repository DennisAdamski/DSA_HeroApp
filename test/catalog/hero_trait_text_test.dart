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
      expect(parseTraitFragmentValue('Verbindungen', trait), isNull);
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

  group('Guter-Ruf-Template mit Geltungsbereich', () {
    const guterRuf = HeroTraitDef(
      id: 'adv_guter_ruf',
      name: 'Guter Ruf',
      traitType: 'advantage',
      valueKind: 'points',
      minValue: 1,
      maxValue: 10,
      selectionTemplate: 'Guter Ruf {value} ({choice})',
    );

    test('baut Text mit Geltungsbereich', () {
      expect(
        buildHeroTraitSelectionText(
          trait: guterRuf,
          choice: 'Thorwal',
          value: 4,
        ),
        'Guter Ruf 4 (Thorwal)',
      );
    });

    test('laesst bei leerem Geltungsbereich keine leere Klammer stehen', () {
      expect(
        buildHeroTraitSelectionText(trait: guterRuf, choice: '', value: 4),
        'Guter Ruf 4',
      );
    });

    test('liest Bestandsfragmente ohne Geltungsbereich weiter', () {
      expect(parseTraitFragmentValue('Guter Ruf 4', guterRuf), 4);
      final parts = parseTraitFragmentParts('Guter Ruf 4', guterRuf);
      expect(parts, isNotNull);
      expect(parts!.value, 4);
      expect(parts.choice, isEmpty);
    });

    test('liest Wert und Geltungsbereich aus dem neuen Format', () {
      final parts = parseTraitFragmentParts('Guter Ruf 4 (Thorwal)', guterRuf);
      expect(parts!.value, 4);
      expect(parts.choice, 'Thorwal');
    });
  });

  group('mergeHeroTraitFragment', () {
    const herausragendeEigenschaft = HeroTraitDef(
      id: 'adv_herausragende_eigenschaft',
      name: 'Herausragende Eigenschaft',
      traitType: 'advantage',
      valueKind: 'choice',
      minValue: 1,
      selectionTemplate: 'Herausragende Eigenschaft {choice} {value}',
    );

    test('fasst gleiche Auswahl zu einem Eintrag mit summiertem Wert', () {
      final merged = mergeHeroTraitFragment(
        fragments: <String>['Herausragende Eigenschaft KK 1'],
        fragment: 'Herausragende Eigenschaft KK 2',
        trait: herausragendeEigenschaft,
      );

      expect(merged, <String>['Herausragende Eigenschaft KK 3']);
    });

    test('haengt abweichende Auswahl als eigenes Fragment an', () {
      final merged = mergeHeroTraitFragment(
        fragments: <String>['Herausragende Eigenschaft KK 1'],
        fragment: 'Herausragende Eigenschaft GE 1',
        trait: herausragendeEigenschaft,
      );

      expect(merged, <String>[
        'Herausragende Eigenschaft KK 1',
        'Herausragende Eigenschaft GE 1',
      ]);
    });

    test('laesst fremde Fragmente unberuehrt', () {
      final merged = mergeHeroTraitFragment(
        fragments: <String>['Flink', 'Herausragende Eigenschaft KK 1'],
        fragment: 'Herausragende Eigenschaft KK 1',
        trait: herausragendeEigenschaft,
      );

      expect(merged, <String>['Flink', 'Herausragende Eigenschaft KK 2']);
    });

    test('haengt bei Templates ohne Wert einfach an', () {
      const sinn = HeroTraitDef(
        id: 'adv_herausragender_sinn',
        name: 'Herausragender Sinn',
        traitType: 'advantage',
        valueKind: 'choice',
        selectionTemplate: 'Herausragender Sinn {choice}',
      );

      final merged = mergeHeroTraitFragment(
        fragments: <String>['Herausragender Sinn Gehör'],
        fragment: 'Herausragender Sinn Sicht',
        trait: sinn,
      );

      expect(merged, <String>[
        'Herausragender Sinn Gehör',
        'Herausragender Sinn Sicht',
      ]);
    });
  });
}
