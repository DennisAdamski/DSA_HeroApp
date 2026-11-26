import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spiel_zauber_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../ui2/shell/karto_test_support.dart';

// Zauberkachel am Spieltisch: gelernte Zauber, Suche, Merkmalsfilter,
// Sortierung und Kopfdaten. ZfW* kommt aus `herleiteZfw`.

const _katalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: [],
  weapons: [],
  spells: <SpellDef>[
    SpellDef(
      id: 'spell_ignifaxius',
      name: 'Ignifaxius Flammenstrahl',
      tradition: 'Gildenmagie',
      steigerung: 'D',
      attributes: <String>['KL', 'IN', 'FF'],
      traits: 'Elementar (Feuer), Schaden',
      castingTime: '2 Aktionen',
      aspCost: '4 AsP',
      range: '8 Schritt',
      duration: 'sofort',
    ),
    SpellDef(
      id: 'spell_armatrutz',
      name: 'Armatrutz',
      tradition: 'Gildenmagie',
      steigerung: 'D',
      attributes: <String>['KL', 'IN', 'FF'],
      traits: 'Metamagie',
    ),
    SpellDef(
      id: 'spell_balsam',
      name: 'Balsam Salabunde',
      tradition: 'Gildenmagie',
      steigerung: 'D',
      attributes: <String>['KL', 'IN', 'FF'],
      traits: 'Heilung, Metamagie',
    ),
    SpellDef(
      id: 'spell_ungelernt',
      name: 'Ungelernt',
      tradition: 'Gildenmagie',
      steigerung: 'C',
      attributes: <String>['KL', 'IN', 'FF'],
    ),
  ],
);

HeroComputedSnapshot _werte(HeroSheet held) => buildHeroComputedSnapshot(
  hero: held,
  state: const HeroState.empty(),
  catalog: _katalog,
  epicAdvantagesActive: false,
);

HeroSheet _magier() => testHero().copyWith(
  spells: const <String, HeroSpellEntry>{
    'spell_ignifaxius': HeroSpellEntry(
      spellValue: 12,
      modifier: 2,
      hauszauber: true,
      learnedRepresentation: 'Mag',
      specializations: <String>['Fernziel', '  '],
    ),
    'spell_armatrutz': HeroSpellEntry(spellValue: 7),
    'spell_balsam': HeroSpellEntry(spellValue: 7),
    // Eingetragen, aber nicht aktiviert: nicht wirkbar.
    'spell_ungelernt': HeroSpellEntry(),
  },
);

void main() {
  group('spielZauberListe', () {
    test('nur Zauber mit ZfW, ZfW* aus Wert und Modifikator', () {
      final liste = spielZauberListe(_werte(_magier()), _katalog);
      expect(liste.map((e) => e.zauber.id), <String>[
        'spell_armatrutz',
        'spell_balsam',
        'spell_ignifaxius',
      ]);
      final ignifaxius = liste.last;
      expect(ignifaxius.zfw, 14);
      expect(ignifaxius.hauszauber, isTrue);
      expect(ignifaxius.repraesentation, 'Mag');
      expect(ignifaxius.spezialisierungen, <String>['Fernziel']);
      expect(ignifaxius.eigenschaften, 'KL/IN/FF');
      expect(ignifaxius.merkmale, <String>['Elementar (Feuer)', 'Schaden']);
    });

    test('Suche ohne Groß-/Kleinschreibung', () {
      final liste = spielZauberListe(
        _werte(_magier()),
        _katalog,
        suche: ' BALSAM ',
      );
      expect(liste.map((e) => e.zauber.id), <String>['spell_balsam']);
    });

    test('Merkmalsfilter nimmt nur Zauber mit genau diesem Merkmal', () {
      final liste = spielZauberListe(
        _werte(_magier()),
        _katalog,
        merkmal: 'Metamagie',
      );
      expect(liste.map((e) => e.zauber.id), <String>[
        'spell_armatrutz',
        'spell_balsam',
      ]);
    });

    test('ZfW-Sortierung, Gleichstand nach Name, Richtung drehbar', () {
      final absteigend = spielZauberListe(
        _werte(_magier()),
        _katalog,
        sortierung: SpielZauberSortierung.zfw,
        aufsteigend: false,
      );
      expect(absteigend.map((e) => e.zauber.id), <String>[
        'spell_ignifaxius',
        'spell_armatrutz',
        'spell_balsam',
      ]);
      final aufsteigend = spielZauberListe(
        _werte(_magier()),
        _katalog,
        sortierung: SpielZauberSortierung.zfw,
      );
      expect(aufsteigend.map((e) => e.zauber.id), <String>[
        'spell_armatrutz',
        'spell_balsam',
        'spell_ignifaxius',
      ]);
    });

    test('Name absteigend dreht nur das Hauptkriterium', () {
      final liste = spielZauberListe(
        _werte(_magier()),
        _katalog,
        aufsteigend: false,
      );
      expect(liste.first.zauber.id, 'spell_ignifaxius');
    });
  });

  test('spielZauberMerkmale: eindeutig und alphabetisch', () {
    final liste = spielZauberListe(_werte(_magier()), _katalog);
    expect(spielZauberMerkmale(liste), <String>[
      'Elementar (Feuer)',
      'Heilung',
      'Metamagie',
      'Schaden',
    ]);
  });

  group('fuehrtZauber', () {
    test('ein Held ohne Magie und ohne Zauber führt keine', () {
      expect(fuehrtZauber(_werte(testHero())), isFalse);
    });

    test('aktivierte Magie genügt', () {
      final held = testHero().copyWith(
        resourceActivationConfig: const HeroResourceActivationConfig(
          magicEnabledOverride: true,
        ),
      );
      expect(fuehrtZauber(_werte(held)), isTrue);
    });

    test('ein Zauber mit ZfW genügt auch ohne Magie', () {
      expect(fuehrtZauber(_werte(_magier())), isTrue);
    });
  });

  group('spielZauberKopf', () {
    test('Tradition, Leiteigenschaft und Merkmalskenntnisse', () {
      final held = _magier().copyWith(
        representationen: const <String>['Mag'],
        merkmalskenntnisse: const <String>['Heilung'],
      );
      final kopf = spielZauberKopf(_werte(held));
      expect(kopf.traditionen, <String>['Gildenmagier']);
      expect(kopf.leiteigenschaften, <String>['KL']);
      expect(kopf.merkmalskenntnisse, <String>['Heilung']);
      expect(kopf.leer, isFalse);
    });

    test('das manuelle Feld des Helden schlägt die Tradition', () {
      final held = _magier().copyWith(
        representationen: const <String>['Mag'],
        magicLeadAttribute: 'in',
      );
      expect(spielZauberKopf(_werte(held)).leiteigenschaften, <String>['IN']);
    });

    test('ohne Angaben ist der Kopf leer', () {
      expect(spielZauberKopf(_werte(testHero())).leer, isTrue);
    });
  });
}
