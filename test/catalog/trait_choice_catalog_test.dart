import 'package:dsa_heldenverwaltung/catalog/hero_trait_choices.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_reference_names.dart';

/// Prueft die Auswahllisten der Vor- und Nachteile gegen den echten Katalog.
///
/// Ein Tippfehler in `choiceSource` faellt sonst erst im Betrieb auf, und dort
/// nur als leeres Auswahlfeld — dieselbe Begruendung wie bei den Katalogtests
/// der Erwerbsvoraussetzungen.
void main() {
  final advantages = ladeKatalogDatei(
    'vorteile.json',
  ).map(HeroTraitDef.fromJson).toList(growable: false);
  final disadvantages = ladeKatalogDatei(
    'nachteile.json',
  ).map(HeroTraitDef.fromJson).toList(growable: false);

  final catalog = RulesCatalog(
    version: 'house_rules_v1',
    source: 'test',
    talents: <TalentDef>[
      for (final json in ladeKatalogDatei('talente.json'))
        TalentDef.fromJson(json),
      for (final json in ladeKatalogDatei('waffentalente.json'))
        TalentDef.fromJson(json),
    ],
    spells: ladeKatalogDatei(
      'magie.json',
    ).map(SpellDef.fromJson).toList(growable: false),
    weapons: const [],
    magicSpecialAbilities: ladeKatalogDatei(
      'magische_sonderfertigkeiten.json',
    ).map(SpecialAbilityDef.fromJson).toList(growable: false),
    advantages: advantages,
    disadvantages: disadvantages,
  );

  final alle = <HeroTraitDef>[...advantages, ...disadvantages];
  final mitAuswahl = alle
      .where((trait) => trait.selectionTemplate.contains('{choice}'))
      .toList(growable: false);

  test('jeder Auswahl-Eintrag traegt eine Beschriftung', () {
    expect(mitAuswahl, hasLength(48));
    final ohneLabel = mitAuswahl
        .where((trait) => trait.choiceLabel.trim().isEmpty)
        .map((trait) => trait.id)
        .toList();
    expect(ohneLabel, isEmpty);
  });

  test('jede choiceSource ist bekannt', () {
    final unbekannt = alle
        .where(
          (trait) =>
              trait.choiceSource.isNotEmpty &&
              !kKnownTraitChoiceSources.contains(trait.choiceSource),
        )
        .map((trait) => '${trait.id} -> ${trait.choiceSource}')
        .toList();
    expect(unbekannt, isEmpty);
  });

  test('jede choiceSource liefert im echten Katalog eine nichtleere Liste', () {
    final leer = alle
        .where((trait) => trait.choiceSource.isNotEmpty)
        .where((trait) => resolveTraitChoices(trait, catalog).isEmpty)
        .map((trait) => '${trait.id} -> ${trait.choiceSource}')
        .toList();
    expect(leer, isEmpty);
  });

  test('ein Eintrag ohne Liste erlaubt Freitext', () {
    // Sonst waere er nicht mehr ausfuellbar: kein Dropdown, kein Textfeld.
    final gesperrt = mitAuswahl
        .where(
          (trait) =>
              trait.choices.isEmpty &&
              trait.choiceSource.isEmpty &&
              !trait.choiceFreeText,
        )
        .map((trait) => trait.id)
        .toList();
    expect(gesperrt, isEmpty);
  });

  test('die drei angefragten Eintraege tragen ihre Regellisten', () {
    HeroTraitDef byId(String id) => alle.firstWhere((t) => t.id == id);

    // Wege der Helden S. 254: genau vier Bereiche.
    final sinn = byId('adv_herausragender_sinn');
    expect(resolveTraitChoices(sinn, catalog), <String>[
      'Gehör',
      'Sicht',
      'Tastsinn',
      'Geruchssinn',
    ]);
    expect(sinn.choiceFreeText, isFalse);
    expect(
      resolveTraitChoices(byId('dis_eingeschraenkter_sinn'), catalog),
      resolveTraitChoices(sinn, catalog),
    );

    final eigenschaft = byId('adv_herausragende_eigenschaft');
    expect(resolveTraitChoices(eigenschaft, catalog), <String>[
      'MU',
      'KL',
      'IN',
      'CH',
      'FF',
      'GE',
      'KO',
      'KK',
    ]);
    expect(eigenschaft.choiceFreeText, isFalse);

    // Wege der Helden S. 253: gilt fuer die eigene Kultur, fremde Kulturen
    // nach Meisterentscheid — deshalb Vorschlaege plus Freitext.
    final ruf = byId('adv_guter_ruf');
    expect(ruf.selectionTemplate, 'Guter Ruf {value} ({choice})');
    expect(ruf.choiceLabel, 'Geltungsbereich');
    expect(ruf.choiceFreeText, isTrue);
    expect(resolveTraitChoices(ruf, catalog), contains('Eigene Kultur'));
  });

  test('katalogabgeleitete Quellen loesen plausibel auf', () {
    final talentgruppen = resolveTraitChoices(
      const HeroTraitDef(
        id: 'x',
        name: 'x',
        traitType: 'advantage',
        choiceSource: 'talentgruppen_kampf_koerper',
      ),
      catalog,
    );
    expect(talentgruppen, containsAll(<String>['Kampftalent']));

    final schlechteEigenschaften = resolveTraitChoices(
      const HeroTraitDef(
        id: 'x',
        name: 'x',
        traitType: 'disadvantage',
        choiceSource: 'schlechte_eigenschaften',
      ),
      catalog,
    );
    expect(schlechteEigenschaften, contains('Goldgier'));
    expect(schlechteEigenschaften, contains('Jähzorn'));
    // Platzhalter-Eintraege bleiben draussen.
    expect(
      schlechteEigenschaften.any((name) => name.contains('[')),
      isFalse,
    );
  });

  test('unbekannte Quelle liefert eine leere Liste statt zu werfen', () {
    expect(
      resolveTraitChoices(
        const HeroTraitDef(
          id: 'x',
          name: 'x',
          traitType: 'advantage',
          choiceSource: 'gibt_es_nicht',
        ),
        catalog,
      ),
      isEmpty,
    );
  });

  test('feste Vorschlaege stehen vorne und werden nicht dupliziert', () {
    const trait = HeroTraitDef(
      id: 'x',
      name: 'x',
      traitType: 'advantage',
      choices: <String>['Eigene Kultur', 'MU'],
      choiceSource: 'eigenschaften',
    );

    final choices = resolveTraitChoices(trait, catalog);

    expect(choices.first, 'Eigene Kultur');
    expect(choices.where((c) => c == 'MU'), hasLength(1));
  });

  test('ohne Katalog bleiben nur die festen Vorschlaege', () {
    const trait = HeroTraitDef(
      id: 'x',
      name: 'x',
      traitType: 'advantage',
      choices: <String>['Eigene Kultur'],
      choiceSource: 'talente',
    );

    expect(resolveTraitChoices(trait, null), <String>['Eigene Kultur']);
    // Eigenschaften und Merkmale stehen im Code, nicht im Katalog.
    expect(
      resolveTraitChoices(
        const HeroTraitDef(
          id: 'y',
          name: 'y',
          traitType: 'advantage',
          choiceSource: 'eigenschaften',
        ),
        null,
      ),
      hasLength(8),
    );
  });
}
