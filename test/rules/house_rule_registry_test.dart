import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';

void main() {
  const catalog = HouseRulePackCatalog(
    packs: <HouseRulePackManifest>[
      HouseRulePackManifest(
        id: 'epic_rules_v1',
        title: 'Epische Stufen',
        description: 'Root',
        patches: <HouseRulePatch>[],
      ),
      HouseRulePackManifest(
        id: 'epic_rules_v1.advantages',
        parentPackId: 'epic_rules_v1',
        title: 'Vorteile',
        description: 'Child',
        patches: <HouseRulePatch>[],
      ),
      HouseRulePackManifest(
        id: 'epic_rules_v1.disadvantages',
        parentPackId: 'epic_rules_v1',
        title: 'Nachteile',
        description: 'Child',
        patches: <HouseRulePatch>[],
      ),
      HouseRulePackManifest(
        id: 'epic_rules_v1.combat_sf',
        parentPackId: 'epic_rules_v1',
        title: 'Kampf',
        description: 'Child',
        patches: <HouseRulePatch>[],
      ),
    ],
  );

  test('all pack ids are unique', () {
    final keys = catalog.packs.map((e) => e.id).toList();
    expect(keys.toSet().length, keys.length);
  });

  test('every parent reference resolves to a registered root', () {
    for (final descriptor in catalog.packs) {
      final parentKey = descriptor.parentPackId;
      if (parentKey.isEmpty) continue;
      final parent = catalog.find(parentKey);
      expect(
        parent,
        isNotNull,
        reason: 'Parent $parentKey fuer ${descriptor.id} fehlt',
      );
      expect(
        parent!.isRoot,
        isTrue,
        reason: 'Parent $parentKey sollte ein Root sein',
      );
    }
  });

  test('epic master pack is a root', () {
    final master = catalog.find('epic_rules_v1');
    expect(master, isNotNull);
    expect(master!.isRoot, isTrue);
  });

  test('epic child packs reference the master', () {
    const subKeys = <String>[
      'epic_rules_v1.combat_sf',
      'epic_rules_v1.advantages',
      'epic_rules_v1.disadvantages',
    ];
    for (final key in subKeys) {
      final descriptor = catalog.find(key);
      expect(descriptor, isNotNull, reason: 'Key $key fehlt im Katalog');
      expect(descriptor!.parentPackId, 'epic_rules_v1');
    }
  });

  test('childrenOf master returns all direct child packs', () {
    final children = catalog
        .childrenOf('epic_rules_v1')
        .map((e) => e.id)
        .toSet();
    expect(children, contains('epic_rules_v1.combat_sf'));
    expect(children, contains('epic_rules_v1.advantages'));
    expect(children, contains('epic_rules_v1.disadvantages'));
  });
}
