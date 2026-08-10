import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_matching.dart';

void main() {
  const catalog = <SpecialAbilityDef>[
    SpecialAbilityDef(id: 'asf_kulturkunde', name: 'Kulturkunde'),
    SpecialAbilityDef(id: 'asf_gelaendekunde', name: 'Geländekunde'),
    SpecialAbilityDef(id: 'asf_standfest', name: 'Standfest'),
  ];

  test('findet einen Eintrag ueber den exakten Namen', () {
    expect(matchCatalogSpecialAbility(catalog, 'standfest')?.id, 'asf_standfest');
  });

  test('findet den Katalogeintrag zu einem Namen mit Auswahlvariante', () {
    expect(
      matchCatalogSpecialAbility(catalog, 'Kulturkunde (Novadi)')?.id,
      'asf_kulturkunde',
    );
    expect(
      matchCatalogSpecialAbility(catalog, 'Geländekunde (Wüstenkundig)')?.id,
      'asf_gelaendekunde',
    );
  });

  test('ist beim Basisnamen-Fallback umlauttolerant', () {
    expect(
      matchCatalogSpecialAbility(catalog, 'Gelaendekunde (Waldkundig)')?.id,
      'asf_gelaendekunde',
    );
  });

  test('liefert null fuer unbekannte Namen', () {
    expect(matchCatalogSpecialAbility(catalog, 'Rosstäuscher (Pferd)'), isNull);
    expect(matchCatalogSpecialAbility(catalog, '   '), isNull);
  });
}
