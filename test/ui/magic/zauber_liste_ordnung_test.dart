import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/spell_def.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_magic/zauber_liste_ordnung.dart';

SpellDef _zauber(String id, String name, String traits) => SpellDef(
  id: id,
  name: name,
  tradition: 'Mag',
  steigerung: 'C',
  attributes: const <String>['Mut', 'Klugheit', 'Charisma'],
  traits: traits,
);

void main() {
  final defs = <String, SpellDef>{
    'a': _zauber('a', 'Attributo', 'Eigenschaften'),
    'b': _zauber('b', 'blitz dich find', 'Einfluss, Herrschaft'),
    'c': _zauber('c', 'Wellenlauf', 'Umwelt, Elementar (Wasser)'),
    'd': _zauber('d', 'Aeolitus', 'Umwelt, Elementar (Luft)'),
  };
  const ids = <String>['a', 'b', 'c', 'd'];

  List<String> ordne({
    ZauberSortierung sortierung = ZauberSortierung.name,
    bool aufsteigend = true,
    Map<String, int> zfw = const <String, int>{},
    String? merkmal,
    Iterable<String> zauberIds = ids,
  }) => ordneZauberliste(
    ids: zauberIds,
    defs: defs,
    zfwJeZauber: zfw,
    sortierung: sortierung,
    aufsteigend: aufsteigend,
    merkmal: merkmal,
  );

  test('Name sortiert ohne Gross-/Kleinschreibung in beide Richtungen', () {
    expect(ordne(), <String>['d', 'a', 'b', 'c']);
    expect(ordne(aufsteigend: false), <String>['c', 'b', 'a', 'd']);
  });

  test('ZfW sortiert nach Wert, Gleichstand nach Name aufsteigend', () {
    const zfw = <String, int>{'a': 7, 'b': 12, 'c': 7};
    expect(
      ordne(sortierung: ZauberSortierung.zfw, aufsteigend: false, zfw: zfw),
      <String>['b', 'a', 'c', 'd'],
    );
    expect(ordne(sortierung: ZauberSortierung.zfw, zfw: zfw), <String>[
      'd',
      'a',
      'c',
      'b',
    ]);
  });

  test('Merkmalsfilter trifft Zauber mit mehreren Merkmalen', () {
    expect(ordne(merkmal: 'Umwelt'), <String>['d', 'c']);
    expect(ordne(merkmal: 'Elementar (Luft)'), <String>['d']);
    expect(ordne(merkmal: 'Antimagie'), isEmpty);
  });

  test(
    'Zauber ohne Katalogeintrag sortiert nach ID, faellt im Filter heraus',
    () {
      expect(ordne(zauberIds: <String>['zz_fehlt', 'a']), <String>[
        'a',
        'zz_fehlt',
      ]);
      expect(
        ordne(zauberIds: <String>['zz_fehlt', 'a'], merkmal: 'Eigenschaften'),
        <String>['a'],
      );
    },
  );

  test('merkmaleDerZauber liefert eindeutige Merkmale alphabetisch', () {
    expect(merkmaleDerZauber(defs.values), <String>[
      'Eigenschaften',
      'Einfluss',
      'Elementar (Luft)',
      'Elementar (Wasser)',
      'Herrschaft',
      'Umwelt',
    ]);
  });
}
