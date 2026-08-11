import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_variant_rules.dart';

void main() {
  const kulturkunde = SpecialAbilityDef(
    id: 'asf_kulturkunde',
    name: 'Kulturkunde',
    kosten: 'kostenlos (0 AP) für die eigene Kultur; 150 AP für jede weitere',
    mehrfachwaehlbar: true,
    variantenLabel: 'Kultur',
    varianten: ['Novadi', 'Thorwal'],
    apErstwerb: 150,
    apFolgeerwerb: 150,
  );

  const gelaendekunde = SpecialAbilityDef(
    id: 'asf_gelaendekunde',
    name: 'Geländekunde',
    kosten: '150 AP für die erste Geländekunde, je 100 AP für jedes weitere',
    mehrfachwaehlbar: true,
    variantenLabel: 'Gelände',
    varianten: ['Wüstenkundig', 'Waldkundig'],
    variantenFreitext: false,
    apErstwerb: 150,
    apFolgeerwerb: 100,
  );

  const standfest = SpecialAbilityDef(
    id: 'asf_standfest',
    name: 'Standfest',
    kosten: '200 AP (4 GP)',
  );

  group('Namensaufbau und -zerlegung', () {
    test('baut den Anzeigenamen aus Basis und Variante', () {
      expect(
        buildVariantAbilityName('Kulturkunde', 'Novadi'),
        'Kulturkunde (Novadi)',
      );
    });

    test('leere Variante liefert den Basisnamen', () {
      expect(buildVariantAbilityName('Kulturkunde', '   '), 'Kulturkunde');
    });

    test('zerlegt den Anzeigenamen wieder', () {
      expect(specialAbilityBaseName('Kulturkunde (Novadi)'), 'Kulturkunde');
      expect(specialAbilityVariant('Kulturkunde (Novadi)'), 'Novadi');
    });

    test('behandelt Klammern innerhalb der Variante als Teil der Variante', () {
      const stored = 'Ortskenntnis (Gareth (Südquartier))';
      expect(specialAbilityBaseName(stored), 'Ortskenntnis');
      expect(specialAbilityVariant(stored), 'Gareth (Südquartier)');
    });

    test('Namen ohne Variante bleiben unveraendert', () {
      expect(specialAbilityBaseName('Standfest'), 'Standfest');
      expect(specialAbilityVariant('Standfest'), isNull);
    });
  });

  group('Bestandszaehlung', () {
    const owned = <String>[
      'kulturkunde (novadi)',
      'kulturkunde (thorwal)',
      'geländekunde (wüstenkundig)',
      'standfest',
    ];

    test('zaehlt Instanzen ueber den Basisnamen', () {
      expect(countOwnedVariants(owned, 'Kulturkunde'), 2);
      expect(countOwnedVariants(owned, 'Standfest'), 1);
      expect(countOwnedVariants(owned, 'Ortskenntnis'), 0);
    });

    test('ist tolerant gegenueber Umlaut-Schreibweisen', () {
      expect(countOwnedVariants(owned, 'Gelaendekunde'), 1);
      expect(countOwnedVariants(owned, 'Geländekunde'), 1);
    });

    test('zaehlt Altbestand ohne Variante mit', () {
      expect(countOwnedVariants(const ['Kulturkunde'], 'Kulturkunde'), 1);
    });

    test('liefert die belegten Varianten', () {
      expect(
        ownedVariantsFor(owned, 'Kulturkunde'),
        {'novadi', 'thorwal'},
      );
    });
  });

  group('AP-Vorschlag', () {
    test('staffelt Geländekunde von 150 auf 100', () {
      expect(
        suggestVariantApCost(
          def: gelaendekunde,
          bereitsErworben: 0,
          variante: 'Wüstenkundig',
        ),
        150,
      );
      expect(
        suggestVariantApCost(
          def: gelaendekunde,
          bereitsErworben: 1,
          variante: 'Waldkundig',
        ),
        100,
      );
    });

    test('Kulturkunde der eigenen Kultur ist kostenlos', () {
      expect(
        suggestVariantApCost(
          def: kulturkunde,
          bereitsErworben: 0,
          variante: 'Thorwal',
          eigeneKultur: 'Thorwal',
        ),
        0,
      );
    });

    test('Kulturkunde einer fremden Kultur kostet 150 AP', () {
      expect(
        suggestVariantApCost(
          def: kulturkunde,
          bereitsErworben: 0,
          variante: 'Novadi',
          eigeneKultur: 'Thorwal',
        ),
        150,
      );
    });

    test('erkennt die eigene Kultur auch als Teil eines laengeren Textes', () {
      expect(
        suggestVariantApCost(
          def: kulturkunde,
          bereitsErworben: 1,
          variante: 'Mittelreich',
          eigeneKultur: 'Mittelreich (Mittelländische Städte)',
        ),
        0,
      );
    });

    test('faellt ohne AP-Felder auf den Kostentext zurueck', () {
      expect(
        suggestVariantApCost(def: standfest, bereitsErworben: 0),
        200,
      );
      expect(
        suggestVariantApCost(def: standfest, bereitsErworben: 3),
        200,
      );
    });

    test('liefert 0, wenn der Kostentext keinen AP-Betrag enthaelt', () {
      const ohneKosten = SpecialAbilityDef(id: 'x', name: 'X', kosten: 'n. a.');
      expect(suggestVariantApCost(def: ohneKosten, bereitsErworben: 0), 0);
    });
  });

  group('Gruppenkosten', () {
    const hexenfluesche = SpecialAbilityDef(
      id: 'magsf_hexenfluesche',
      name: 'Hexenflüche*',
      kosten: 'je nach Hexenfluch',
      mehrfachwaehlbar: true,
      variantenLabel: 'Hexenfluch',
      variantenGruppen: [
        SpecialAbilityVariantGroup(
          label: '50 AP',
          ap: 50,
          varianten: ['Warzen sprießen', 'Zunge lähmen'],
        ),
        SpecialAbilityVariantGroup(
          label: '150 AP',
          ap: 150,
          varianten: ['Hagelschlag'],
        ),
      ],
      variantenFreitext: false,
      apErstwerb: 999,
      apFolgeerwerb: 999,
    );

    test('nimmt den Preis der Gruppe, in der die Variante liegt', () {
      expect(
        suggestVariantApCost(
          def: hexenfluesche,
          bereitsErworben: 0,
          variante: 'Warzen sprießen',
        ),
        50,
      );
      expect(
        suggestVariantApCost(
          def: hexenfluesche,
          bereitsErworben: 3,
          variante: 'Hagelschlag',
        ),
        150,
      );
    });

    test('der Gruppenpreis schlaegt die Erst-/Folgestaffelung', () {
      // apErstwerb/apFolgeerwerb sind bewusst absurd hoch gesetzt.
      expect(
        suggestVariantApCost(
          def: hexenfluesche,
          bereitsErworben: 0,
          variante: 'Zunge lähmen',
        ),
        isNot(999),
      );
    });

    test('unbekannte Variante faellt auf die Staffelung zurueck', () {
      expect(
        suggestVariantApCost(
          def: hexenfluesche,
          bereitsErworben: 0,
          variante: 'Eigener Fluch',
        ),
        999,
      );
    });

    test('variantGroupFor findet die Gruppe umlauttolerant', () {
      expect(
        variantGroupFor(hexenfluesche, 'Warzen spriessen')?.ap,
        50,
      );
      expect(variantGroupFor(hexenfluesche, 'Unbekannt'), isNull);
      expect(variantGroupFor(hexenfluesche, '  '), isNull);
    });

    test('alleVarianten fuehrt flache Liste und Gruppen zusammen', () {
      const gemischt = SpecialAbilityDef(
        id: 'x',
        name: 'X',
        varianten: ['Flach'],
        variantenGruppen: [
          SpecialAbilityVariantGroup(
            label: '10 AP',
            ap: 10,
            varianten: ['Gruppiert', 'Flach'],
          ),
        ],
      );

      expect(gemischt.alleVarianten, ['Flach', 'Gruppiert']);
    });
  });
}
