import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/combat_special_ability_def.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_chain_rules.dart';

void main() {
  const willeI = SpecialAbilityDef(
    id: 'magsf_eiserner_wille_i',
    name: 'Eiserner Wille I',
    kategorie: 'Geistestechnik',
    kette: SpecialAbilityChainRef(
      id: 'eiserner_wille',
      stufe: 1,
      label: 'Eiserner Wille',
    ),
    aliasNamen: <String>['Eiserner Wille I / II'],
  );
  const willeII = SpecialAbilityDef(
    id: 'magsf_eiserner_wille_ii',
    name: 'Eiserner Wille II',
    kategorie: 'Geistestechnik',
    kette: SpecialAbilityChainRef(id: 'eiserner_wille', stufe: 2),
  );
  const gedankenschutz = SpecialAbilityDef(
    id: 'magsf_gedankenschutz',
    name: 'Gedankenschutz',
    kategorie: 'Geistestechnik',
  );
  const katalog = <SpecialAbilityDef>[willeII, gedankenschutz, willeI];

  group('buildSpecialAbilityChains', () {
    test('gruppiert Eintraege derselben Kette und sortiert nach Stufe', () {
      final ketten = buildSpecialAbilityChains(katalog);

      expect(ketten, hasLength(1));
      expect(ketten.single.id, 'eiserner_wille');
      expect(ketten.single.stufen.map((def) => def.name), <String>[
        'Eiserner Wille I',
        'Eiserner Wille II',
      ]);
    });

    test('nimmt das Label der ersten Stufe', () {
      expect(buildSpecialAbilityChains(katalog).single.label, 'Eiserner Wille');
    });

    test('faellt ohne Label auf den Namen der ersten Stufe zurueck', () {
      const ohneLabel = <SpecialAbilityDef>[
        SpecialAbilityDef(
          id: 'a',
          name: 'Regeneration I',
          kette: SpecialAbilityChainRef(id: 'regeneration', stufe: 1),
        ),
        SpecialAbilityDef(
          id: 'b',
          name: 'Regeneration II',
          kette: SpecialAbilityChainRef(id: 'regeneration', stufe: 2),
        ),
      ];

      expect(buildSpecialAbilityChains(ohneLabel).single.label, 'Regeneration');
    });

    test('eine einzelne Stufe bildet keine Kette', () {
      const einzeln = <SpecialAbilityDef>[
        SpecialAbilityDef(
          id: 'a',
          name: 'Solo I',
          kette: SpecialAbilityChainRef(id: 'solo', stufe: 1),
        ),
      ];

      expect(buildSpecialAbilityChains(einzeln), isEmpty);
    });
  });

  group('kettenloseEintraege', () {
    test('liefert alles, was zu keiner Kette gehoert', () {
      expect(
        kettenloseEintraege(katalog).map((def) => def.id),
        <String>['magsf_gedankenschutz'],
      );
    });
  });

  group('erworbeneKettenstufe', () {
    final kette = buildSpecialAbilityChains(katalog).single;

    test('ohne Eintraege ist die Stufe 0', () {
      expect(erworbeneKettenstufe(kette, const <String>[]), 0);
    });

    test('erkennt die erworbene Stufe', () {
      expect(
        erworbeneKettenstufe(kette, const <String>['Eiserner Wille I']),
        1,
      );
    });

    test('erkennt die hoechste erworbene Stufe', () {
      expect(
        erworbeneKettenstufe(kette, const <String>[
          'Eiserner Wille I',
          'Eiserner Wille II',
        ]),
        2,
      );
    });

    test('erkennt den alten Sammelnamen ueber den Alias', () {
      expect(
        erworbeneKettenstufe(kette, const <String>['Eiserner Wille I / II']),
        1,
      );
    });

    test('ignoriert fremde Eintraege', () {
      expect(
        erworbeneKettenstufe(kette, const <String>['Gedankenschutz']),
        0,
      );
    });
  });

  group('naechsteKettenstufe', () {
    final kette = buildSpecialAbilityChains(katalog).single;

    test('ohne Erwerb ist die erste Stufe faellig', () {
      expect(naechsteKettenstufe(kette, const <String>[])?.name, 'Eiserner Wille I');
    });

    test('nach Stufe I folgt Stufe II', () {
      expect(
        naechsteKettenstufe(kette, const <String>['Eiserner Wille I'])?.name,
        'Eiserner Wille II',
      );
    });

    test('eine vollstaendige Kette hat keine naechste Stufe', () {
      expect(
        naechsteKettenstufe(kette, const <String>[
          'Eiserner Wille I',
          'Eiserner Wille II',
        ]),
        isNull,
      );
    });

    test('eine Luecke wird zuerst geschlossen', () {
      expect(
        naechsteKettenstufe(kette, const <String>['Eiserner Wille II'])?.name,
        'Eiserner Wille I',
      );
    });
  });

  group('istEintragErworben', () {
    test('trifft ueber den Anzeigenamen', () {
      expect(
        istEintragErworben(willeI, const <String>['eiserner wille i']),
        isTrue,
      );
    });

    test('trifft ueber einen Alias-Namen', () {
      expect(
        istEintragErworben(willeI, const <String>['Eiserner Wille I / II']),
        isTrue,
      );
    });

    test('trifft nicht bei einer anderen Stufe', () {
      expect(
        istEintragErworben(willeII, const <String>['Eiserner Wille I']),
        isFalse,
      );
    });
  });

  group('Kampf-Sonderfertigkeiten', () {
    // Die Kettenlogik ist generisch ueber SpecialAbilityEntry, damit
    // Kampf-Ketten dieselbe Darstellung bekommen wie die magischen.
    const ausweichenI = CombatSpecialAbilityDef(
      id: 'ksf_ausweichen_i',
      name: 'Ausweichen I',
      kosten: '100 AP',
      kette: SpecialAbilityChainRef(
        id: 'ausweichen',
        stufe: 1,
        label: 'Ausweichen',
      ),
    );
    const ausweichenII = CombatSpecialAbilityDef(
      id: 'ksf_ausweichen_ii',
      name: 'Ausweichen II',
      kosten: '200 AP',
      kette: SpecialAbilityChainRef(id: 'ausweichen', stufe: 2),
    );
    const linkhand = CombatSpecialAbilityDef(
      id: 'ksf_linkhand',
      name: 'Linkhand',
    );
    const kampfKatalog = <CombatSpecialAbilityDef>[
      ausweichenII,
      linkhand,
      ausweichenI,
    ];

    test('bildet Ketten und behaelt den konkreten Typ', () {
      final ketten = buildSpecialAbilityChains(kampfKatalog);

      expect(ketten, hasLength(1));
      final SpecialAbilityChain<CombatSpecialAbilityDef> kette = ketten.single;
      expect(kette.label, 'Ausweichen');
      expect(kette.stufen.first.kosten, '100 AP');
    });

    test('laesst kettenlose Eintraege uebrig', () {
      expect(
        kettenloseEintraege(kampfKatalog).map((def) => def.id),
        <String>['ksf_linkhand'],
      );
    });

    test('findet die naechste offene Stufe', () {
      final kette = buildSpecialAbilityChains(kampfKatalog).single;

      expect(erworbeneKettenstufe(kette, const <String>['Ausweichen I']), 1);
      expect(
        naechsteKettenstufe(kette, const <String>['Ausweichen I'])?.id,
        'ksf_ausweichen_ii',
      );
    });
  });
}
