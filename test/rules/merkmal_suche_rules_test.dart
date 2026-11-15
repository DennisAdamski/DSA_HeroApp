import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/hero_trait_def.dart';
import 'package:dsa_heldenverwaltung/rules/derived/merkmal_suche_rules.dart';

HeroTraitDef _def(
  String name, {
  bool active = true,
  String source = '',
  List<String> markers = const <String>[],
}) => HeroTraitDef(
  id: name,
  name: name,
  traitType: 'vorteil',
  active: active,
  source: source,
  markers: markers,
);

void main() {
  final defs = [
    _def('Eisern'),
    _def('Hohe Lebenskraft', source: 'Basisregelwerk'),
    _def('Zäher Hund'),
    _def('Verborgen', active: false),
    _def('Flink', markers: const ['Kampf']),
  ];

  test('findet über Umlaut und Umschreibung', () {
    expect(sucheMerkmale(defs, 'zaeher').map((d) => d.name), ['Zäher Hund']);
    expect(sucheMerkmale(defs, 'ZAHER').map((d) => d.name), ['Zäher Hund']);
  });

  test('durchsucht Quelle und Marker', () {
    expect(sucheMerkmale(defs, 'basisregel').map((d) => d.name), [
      'Hohe Lebenskraft',
    ]);
    expect(sucheMerkmale(defs, 'kampf').map((d) => d.name), ['Flink']);
  });

  test(
    'inaktive Einträge bleiben draußen, leere Suche liefert alle aktiven',
    () {
      expect(sucheMerkmale(defs, 'verborgen'), isEmpty);
      expect(sucheMerkmale(defs, '  ').length, 4);
    },
  );

  test('Treffer sind auf das Höchstmaß gekürzt', () {
    final viele = [for (var i = 0; i < 200; i++) _def('Eintrag $i')];
    expect(sucheMerkmale(viele, '').length, kMerkmalSucheMaxTreffer);
  });
}
