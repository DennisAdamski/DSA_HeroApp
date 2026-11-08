import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';

HouseRulePackManifest _paket(String id, {String eltern = ''}) =>
    HouseRulePackManifest(
      id: id,
      title: id,
      description: '',
      patches: const <HouseRulePatch>[],
      parentPackId: eltern,
    );

HouseRulePackCatalog _katalog(List<HouseRulePackManifest> pakete) =>
    HouseRulePackCatalog.merge(
      builtIn: const HouseRulePackSourceSnapshot(),
      imported: HouseRulePackSourceSnapshot(packs: pakete),
    );

void main() {
  // Ein importiertes Paket kann sich selbst oder im Kreis als Eltern nennen;
  // das Katalogladen darf daran nicht hängen bleiben (REV-18).
  group('Elternkette der Hausregel-Pakete', () {
    test('folgt der Kette bis zum Root', () {
      final katalog = _katalog([
        _paket('a'),
        _paket('b', eltern: 'a'),
        _paket('c', eltern: 'b'),
      ]);

      expect(katalog.elternKette('c').map((p) => p.id), ['b', 'a']);
      expect(katalog.resolveActivePackIds({'a'}), isEmpty);
      expect(katalog.resolveActivePackIds({'b'}), {'a'});
      expect(katalog.issues, isEmpty);
    });

    test('ein Paket, das sich selbst als Eltern nennt, endet', () {
      final katalog = _katalog([_paket('a', eltern: 'a')]);

      expect(katalog.elternKette('a'), isEmpty);
      expect(katalog.resolveActivePackIds(const {}), {'a'});
      expect(katalog.resolveActivePackIds({'a'}), isEmpty);
      expect(katalog.roots.map((p) => p.id), ['a']);
      expect(katalog.issues.single.packId, 'a');
    });

    test('ein Zweierkreis endet und wird für beide Pakete gemeldet', () {
      final katalog = _katalog([
        _paket('a', eltern: 'b'),
        _paket('b', eltern: 'a'),
        _paket('c', eltern: 'a'),
      ]);

      expect(katalog.elternKette('a').map((p) => p.id), ['b']);
      expect(katalog.elternKette('c').map((p) => p.id), ['a', 'b']);
      expect(katalog.resolveActivePackIds(const {}), {'a', 'b', 'c'});
      expect(katalog.resolveActivePackIds({'b'}), isEmpty);
      expect(katalog.issues.map((i) => i.packId), ['a', 'b']);
      expect(katalog.liegtInZyklus('c'), isFalse);
    });
  });
}
