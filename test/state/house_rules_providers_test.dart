import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/house_rules_providers.dart';

void main() {
  const epicMaster = HouseRulePackManifest(
    id: 'epic_rules_v1',
    title: 'Epische Stufen',
    description: 'Root',
    patches: <HouseRulePatch>[],
  );
  const epicAdvantages = HouseRulePackManifest(
    id: 'epic_rules_v1.advantages',
    parentPackId: 'epic_rules_v1',
    title: 'Vorteile',
    description: 'Child',
    patches: <HouseRulePatch>[],
  );
  const epicDisadvantages = HouseRulePackManifest(
    id: 'epic_rules_v1.disadvantages',
    parentPackId: 'epic_rules_v1',
    title: 'Nachteile',
    description: 'Child',
    patches: <HouseRulePatch>[],
  );
  const epicCombat = HouseRulePackManifest(
    id: 'epic_rules_v1.combat_sf',
    parentPackId: 'epic_rules_v1',
    title: 'Kampf',
    description: 'Child',
    patches: <HouseRulePatch>[],
  );
  const packCatalog = HouseRulePackCatalog(
    packs: <HouseRulePackManifest>[
      epicMaster,
      epicAdvantages,
      epicDisadvantages,
      epicCombat,
    ],
  );

  ProviderContainer buildContainer(Set<String> disabled) {
    final container = ProviderContainer(
      overrides: [
        disabledHouseRulePackIdsProvider.overrideWithValue(disabled),
        houseRulePackCatalogProvider.overrideWith((ref) async => packCatalog),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('empty disabled set activates all known pack ids', () async {
    final container = buildContainer(const <String>{});
    await container.read(houseRulePackCatalogProvider.future);
    final active = container.read(activeHouseRulePackIdsProvider);
    for (final descriptor in packCatalog.packs) {
      expect(
        active,
        contains(descriptor.id),
        reason: 'Pack ${descriptor.id} sollte aktiv sein',
      );
    }
  });

  test('disabled master cascades to all sub-keys', () async {
    final container = buildContainer(const {'epic_rules_v1'});
    await container.read(houseRulePackCatalogProvider.future);
    final active = container.read(activeHouseRulePackIdsProvider);
    expect(active, isEmpty);
    expect(container.read(isHouseRuleActiveProvider('epic_rules_v1')), isFalse);
    expect(
      container.read(isHouseRuleActiveProvider('epic_rules_v1.combat_sf')),
      isFalse,
    );
    expect(
      container.read(isHouseRuleActiveProvider('epic_rules_v1.advantages')),
      isFalse,
    );
  });

  test('single sub-key disabled leaves siblings and master active', () async {
    final container = buildContainer(const {'epic_rules_v1.advantages'});
    await container.read(houseRulePackCatalogProvider.future);
    expect(container.read(isHouseRuleActiveProvider('epic_rules_v1')), isTrue);
    expect(
      container.read(isHouseRuleActiveProvider('epic_rules_v1.advantages')),
      isFalse,
    );
    expect(
      container.read(isHouseRuleActiveProvider('epic_rules_v1.disadvantages')),
      isTrue,
    );
    expect(
      container.read(isHouseRuleActiveProvider('epic_rules_v1.combat_sf')),
      isTrue,
    );
  });

  test('unknown sourceKey is inactive', () async {
    final container = buildContainer(const <String>{});
    await container.read(houseRulePackCatalogProvider.future);
    expect(
      container.read(isHouseRuleActiveProvider('does_not_exist')),
      isFalse,
    );
  });

  test(
    're-enabling master restores previously un-disabled sub-state',
    () async {
      // Sub-Key `advantages` ist weiterhin in disabled, aber master ist aktiv
      // -> advantages bleibt aus, disadvantages und combatSf aktiv.
      final container = buildContainer(const {'epic_rules_v1.advantages'});
      await container.read(houseRulePackCatalogProvider.future);
      final active = container.read(activeHouseRulePackIdsProvider);
      expect(active, contains('epic_rules_v1'));
      expect(active, contains('epic_rules_v1.disadvantages'));
      expect(active, isNot(contains('epic_rules_v1.advantages')));
    },
  );
}
