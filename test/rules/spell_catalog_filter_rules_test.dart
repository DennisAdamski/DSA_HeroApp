import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/spell_def.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_catalog_filter_rules.dart';

void main() {
  const borrowed = SpellDef(
    id: 'borrowed',
    name: 'Entlehnter Zauber',
    tradition: 'Dru',
    steigerung: 'B',
    attributes: [],
    availability: 'Dru(Elf)2, Mag5',
    traits: 'Elementar (Feuer), Umwelt',
  );
  const incomplete = SpellDef(
    id: 'incomplete',
    name: 'Unvollständiger Zauber',
    tradition: '',
    steigerung: 'A',
    attributes: [],
  );

  test('Klammernotation filtert nach Zielrepräsentation statt Herkunft', () {
    for (final (representations, matches) in [
      (['Dru'], false),
      (['Elf'], true),
      (['Dru', 'Mag'], true),
      (<String>[], false),
    ]) {
      expect(
        matchesSpellCatalogFilters(
          spell: borrowed,
          representations: representations,
          onlyLearnedRepresentations: true,
        ),
        matches,
      );
    }
  });

  test('Mindestverbreitung nutzt denselben Eintrag wie die Repräsentation', () {
    expect(
      matchesSpellCatalogFilters(
        spell: borrowed,
        representations: ['Elf'],
        onlyLearnedRepresentations: true,
        minimumSpread: 5,
      ),
      isFalse,
    );
    expect(
      matchesSpellCatalogFilters(
        spell: borrowed,
        representations: ['Mag'],
        onlyLearnedRepresentations: true,
        minimumSpread: 5,
      ),
      isTrue,
    );
    expect(
      matchesSpellCatalogFilters(
        spell: borrowed,
        representations: ['Elf'],
        onlyLearnedRepresentations: false,
        minimumSpread: 5,
      ),
      isTrue,
    );
  });

  test('Merkmale treffen vollständig und behalten Untermerkmale', () {
    for (final (trait, matches) in [
      ('Elementar (Feuer)', true),
      ('Umwelt', true),
      ('Feuer', false),
      ('Heilung', false),
    ]) {
      expect(
        matchesSpellCatalogFilters(
          spell: borrowed,
          representations: ['Mag'],
          onlyLearnedRepresentations: true,
          trait: trait,
        ),
        matches,
      );
    }
  });

  test(
    'Alle zeigt auch Einträge ohne Angaben, aktive Filter schließen sie aus',
    () {
      expect(
        matchesSpellCatalogFilters(
          spell: incomplete,
          representations: [],
          onlyLearnedRepresentations: false,
        ),
        isTrue,
      );
      expect(
        matchesSpellCatalogFilters(
          spell: incomplete,
          representations: ['Mag'],
          onlyLearnedRepresentations: true,
        ),
        isFalse,
      );
      expect(
        matchesSpellCatalogFilters(
          spell: incomplete,
          representations: [],
          onlyLearnedRepresentations: false,
          minimumSpread: 1,
        ),
        isFalse,
      );
    },
  );

  test('Filterauswahl entfernt Duplikate und leere Angaben und sortiert', () {
    const other = SpellDef(
      id: 'other',
      name: 'Anderer Zauber',
      tradition: 'Elf',
      steigerung: 'A',
      attributes: [],
      availability: 'Elf2, Mag6',
      traits: 'Umwelt, Heilung, ',
    );
    expect(spellCatalogFilterTraits([borrowed, other, incomplete]), [
      'Elementar (Feuer)',
      'Heilung',
      'Umwelt',
    ]);
    expect(spellCatalogFilterSpreads([borrowed, other, incomplete]), [2, 5, 6]);
  });
}
