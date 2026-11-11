import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/kraeuter_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kraeutersuche_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_probe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_sonderfertigkeit_rules.dart';

// Geländekunde und Ortskenntnis bei Wildnisproben (Wege der Helden S. 276–278;
// Wege des Entdeckers S. 112 f.; Zoo Botanica Aventurica S. 61): Eine
// passende Geländekunde erleichtert um 3 (ähnlich nach Meisterentscheid um 1),
// eine passende Ortskenntnis um 7. Geländekunde wird je Gelände einzeln
// erworben (`Geländekunde (Waldkundig)`), Ortskenntnis je Ort oder Strecke
// (`Ortskenntnis (Gareth)`); sie gilt nur am Ort selbst.

const Attributes _werte = Attributes(
  mu: 12,
  kl: 12,
  inn: 12,
  ch: 12,
  ff: 12,
  ge: 12,
  ko: 12,
  kk: 12,
);

HeroSheet _held(List<String> sonderfertigkeiten) => HeroSheet(
  id: 'h',
  name: 'Held',
  level: 1,
  attributes: _werte,
  apTotal: 0,
  apSpent: 0,
  apAvailable: 0,
  talentSpecialAbilities: <TalentSpecialAbility>[
    for (final name in sonderfertigkeiten) TalentSpecialAbility(name: name),
  ],
);

WildnisSonderfertigkeiten _erkenne(
  List<String> sonderfertigkeiten, {
  Kraeuterlandschaft landschaft = Kraeuterlandschaft.dichterWald,
  String standort = '',
}) => werteWildnisSonderfertigkeitenAus(
  hero: _held(sonderfertigkeiten),
  landschaft: kraeuterLandschaftAlsWildnis(landschaft),
  standort: standort,
  catalog: null,
);

void main() {
  group('Geländekunde', () {
    test('passende Variante ergibt −3', () {
      final ergebnis = _erkenne(<String>['Geländekunde (Waldkundig)']);
      expect(ergebnis.gelaendekunde, Gelaendekunde.passend);
      expect(ergebnis.gelaendekundeHerkunft, 'Geländekunde (Waldkundig)');
    });

    test('gilt für dichten wie lichten Wald', () {
      for (final landschaft in <Kraeuterlandschaft>[
        Kraeuterlandschaft.dichterWald,
        Kraeuterlandschaft.lichterWald,
      ]) {
        expect(
          _erkenne(<String>[
            'Geländekunde (Waldkundig)',
          ], landschaft: landschaft).gelaendekunde,
          Gelaendekunde.passend,
        );
      }
    });

    test('Hochgebirge zählt zu Gebirgskundig', () {
      expect(
        _erkenne(<String>[
          'Geländekunde (Gebirgskundig)',
        ], landschaft: Kraeuterlandschaft.hochgebirge).gelaendekunde,
        Gelaendekunde.passend,
      );
    });

    test('andere Geländekunde passt nicht', () {
      final ergebnis = _erkenne(<String>['Geländekunde (Wüstenkundig)']);
      expect(ergebnis.gelaendekunde, Gelaendekunde.keine);
      expect(ergebnis.gelaendekundeHerkunft, isNull);
    });

    test('benachbartes Gelände ist ähnlich (−1)', () {
      expect(
        _erkenne(<String>[
          'Geländekunde (Maraskankundig)',
        ], landschaft: Kraeuterlandschaft.dschungel).gelaendekunde,
        Gelaendekunde.aehnlich,
      );
      expect(
        _erkenne(<String>[
          'Geländekunde (Steppenkundig)',
        ], landschaft: Kraeuterlandschaft.graslandHeide).gelaendekunde,
        Gelaendekunde.aehnlich,
      );
    });

    test('die beste Stufe gewinnt', () {
      final ergebnis = _erkenne(<String>[
        'Geländekunde (Maraskankundig)',
        'Geländekunde (Dschungelkundig)',
      ], landschaft: Kraeuterlandschaft.dschungel);
      expect(ergebnis.gelaendekunde, Gelaendekunde.passend);
      expect(ergebnis.gelaendekundeHerkunft, 'Geländekunde (Dschungelkundig)');
    });

    test('mehrere Geländekunden nebeneinander', () {
      final held = <String>[
        'Geländekunde (Sumpfkundig)',
        'Geländekunde (Waldkundig)',
      ];
      expect(
        _erkenne(
          held,
          landschaft: Kraeuterlandschaft.suempfeNord,
        ).gelaendekunde,
        Gelaendekunde.passend,
      );
      expect(
        _erkenne(held, landschaft: Kraeuterlandschaft.wueste).gelaendekunde,
        Gelaendekunde.keine,
      );
    });

    test('Umlaute und Kurzform werden erkannt', () {
      expect(
        _erkenne(<String>['Gelaendekunde (Waldkundig)']).gelaendekunde,
        Gelaendekunde.passend,
      );
      expect(
        _erkenne(<String>['Geländekunde (Wald)']).gelaendekunde,
        Gelaendekunde.passend,
      );
    });

    test(
      'Altbestand ohne Variante oder mit unbekannter Variante zählt nicht',
      () {
        expect(
          _erkenne(<String>['Geländekunde']).gelaendekunde,
          Gelaendekunde.keine,
        );
        expect(
          _erkenne(<String>['Geländekunde (Unterwasserkundig)']).gelaendekunde,
          Gelaendekunde.keine,
        );
      },
    );

    test('ohne Sonderfertigkeiten ist nichts erkannt', () {
      final ergebnis = _erkenne(const <String>[]);
      expect(ergebnis.gelaendekunde, Gelaendekunde.keine);
      expect(ergebnis.ortskenntnis, isFalse);
    });
  });

  group('Ortskenntnis', () {
    test('passt zum Standort, unabhängig von Schreibweise', () {
      final ergebnis = _erkenne(<String>[
        'Ortskenntnis (Gareth)',
      ], standort: 'gareth');
      expect(ergebnis.ortskenntnis, isTrue);
      expect(ergebnis.ortskenntnisHerkunft, 'Ortskenntnis (Gareth)');
    });

    test('Umlaut-Schreibung und Leerraum spielen keine Rolle', () {
      expect(
        _erkenne(<String>[
          'Ortskenntnis (Nostria)',
        ], standort: '  Nostria ').ortskenntnis,
        isTrue,
      );
      expect(
        _erkenne(<String>[
          'Ortskenntnis (Südquartier)',
        ], standort: 'Suedquartier').ortskenntnis,
        isTrue,
      );
    });

    test('Klammerzusatz der Variante wird übergangen', () {
      expect(
        _erkenne(<String>[
          'Ortskenntnis (Gareth (Südquartier))',
        ], standort: 'Gareth').ortskenntnis,
        isTrue,
      );
      expect(
        _erkenne(<String>[
          'Ortskenntnis (Gareth (Südquartier))',
        ], standort: 'Gareth (Südquartier)').ortskenntnis,
        isTrue,
      );
    });

    test('anderer Ort oder fehlender Standort ergibt keine Ortskenntnis', () {
      expect(
        _erkenne(<String>[
          'Ortskenntnis (Gareth)',
        ], standort: 'Havena').ortskenntnis,
        isFalse,
      );
      expect(_erkenne(<String>['Ortskenntnis (Gareth)']).ortskenntnis, isFalse);
    });

    test('Altbestand ohne Ortsangabe lässt sich nicht zuordnen', () {
      expect(
        _erkenne(<String>['Ortskenntnis'], standort: 'Gareth').ortskenntnis,
        isFalse,
      );
    });

    test('unabhängig von der gewählten Landschaft', () {
      expect(
        _erkenne(
          <String>['Ortskenntnis (Reichsforst)'],
          standort: 'Reichsforst',
          landschaft: Kraeuterlandschaft.lichterWald,
        ).ortskenntnis,
        isTrue,
      );
    });

    test('mehrere Ortskenntnisse: die passende zählt', () {
      final ergebnis = _erkenne(<String>[
        'Ortskenntnis (Gareth)',
        'Ortskenntnis (Havena)',
      ], standort: 'Havena');
      expect(ergebnis.ortskenntnis, isTrue);
      expect(ergebnis.ortskenntnisHerkunft, 'Ortskenntnis (Havena)');
    });
  });

  test('Geländekunde und Ortskenntnis gelten zugleich', () {
    final ergebnis = _erkenne(<String>[
      'Geländekunde (Waldkundig)',
      'Ortskenntnis (Reichsforst)',
    ], standort: 'Reichsforst');
    expect(ergebnis.gelaendekunde, Gelaendekunde.passend);
    expect(ergebnis.ortskenntnis, isTrue);
  });

  group('gelaendeartAusVariante', () {
    test('liest Katalogvariante und Kurzform', () {
      expect(gelaendeartAusVariante('Waldkundig'), Gelaendeart.wald);
      expect(gelaendeartAusVariante('Wüste'), Gelaendeart.wueste);
      expect(gelaendeartAusVariante('Wuestenkundig'), Gelaendeart.wueste);
      expect(gelaendeartAusVariante(''), isNull);
      expect(gelaendeartAusVariante('Luftkundig'), isNull);
    });

    test('jede Geländeart hat eine eindeutige Variante', () {
      final varianten = <String>{
        for (final art in Gelaendeart.values) art.variante,
      };
      expect(varianten.length, Gelaendeart.values.length);
      for (final art in Gelaendeart.values) {
        expect(gelaendeartAusVariante(art.variante), art);
      }
    });
  });
}
