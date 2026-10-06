import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_magie_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../ui2/shell/karto_test_support.dart';

SpellDef _z(String id, String name, String dauer, String kosten) =>
    SpellDef.fromJson({
      'id': id,
      'name': name,
      'attributes': ['MU', 'KL', 'CH'],
      'castingTime': dauer,
      'aspCost': kosten,
    });

void main() {
  final katalog = RulesCatalog(
    version: 'test',
    source: 'test',
    talents: const [],
    spells: [
      _z('z_ignifaxius', 'Ignifaxius', '2 Aktionen', '4 AsP'),
      _z('z_armatrutz', 'Armatrutz', '1 Aktion', '1 AsP pro RS'),
      _z('z_balsam', 'Balsam Salabunde', '20 Aktionen', '7 AsP'),
      _z('z_fremd', 'Ungelernt', '1 Aktion', '1 AsP'),
    ],
    weapons: const [],
  );
  final snapshot = buildHeroComputedSnapshot(
    hero: testHero().copyWith(
      spells: const {
        'z_ignifaxius': HeroSpellEntry(spellValue: 8, modifier: 1),
        'z_armatrutz': HeroSpellEntry(spellValue: 5),
        'z_balsam': HeroSpellEntry(spellValue: 10),
      },
    ),
    state: const HeroState.empty(),
    catalog: katalog,
    epicAdvantagesActive: false,
  );

  test('Gelernte Zauber alphabetisch mit ZfW*, Dauer und Kosten', () {
    final liste = gefechtsZauberliste(snapshot, katalog);
    expect(liste.map((e) => e.zauber.name), [
      'Armatrutz',
      'Balsam Salabunde',
      'Ignifaxius',
    ]);
    final igni = liste.last;
    expect(igni.zfw, 9);
    expect(igni.detail, 'ZfW* 9 · 2 Aktionen · 4 AsP');
  });

  test('Zuletzt gewirkte Zauber stehen vorn, Suche filtert', () {
    final zuletzt = gefechtsZuletztGewirkt(
      gefechtsZuletztGewirkt(const [], 'z_balsam'),
      'z_ignifaxius',
    );
    expect(zuletzt, ['z_ignifaxius', 'z_balsam']);
    final liste = gefechtsZauberliste(snapshot, katalog, zuletzt: zuletzt);
    expect(liste.map((e) => e.zauber.id), [
      'z_ignifaxius',
      'z_balsam',
      'z_armatrutz',
    ]);
    expect(liste.first.zuletzt, isTrue);
    expect(liste.last.zuletzt, isFalse);
    expect(
      gefechtsZauberliste(snapshot, katalog, suche: 'arma').single.zauber.id,
      'z_armatrutz',
    );
    // Höchstens fünf, ohne Dopplung.
    var viele = <String>[];
    for (final id in ['a', 'b', 'c', 'd', 'e', 'f', 'a']) {
      viele = gefechtsZuletztGewirkt(viele, id);
    }
    expect(viele, ['a', 'f', 'e', 'd', 'c']);
  });

  test('Nicht aktivierte Zauber erscheinen nicht mit ZfW* 0', () {
    // Review R12: ein eingeblendeter Zauber ohne Wert ist nicht wirkbar.
    final mitOffenem = buildHeroComputedSnapshot(
      hero: testHero().copyWith(
        spells: const {
          'z_armatrutz': HeroSpellEntry(spellValue: 5),
          'z_fremd': HeroSpellEntry(),
        },
      ),
      state: const HeroState.empty(),
      catalog: katalog,
      epicAdvantagesActive: false,
    );
    final liste = gefechtsZauberliste(mitOffenem, katalog);
    expect(liste.map((e) => e.zauber.id), ['z_armatrutz']);
  });
}
