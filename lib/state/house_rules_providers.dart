import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

/// Alle aktuell wirksamen Hausregel-Paket-IDs.
final activeHouseRulePackIdsProvider = Provider<Set<String>>((ref) {
  final packCatalog =
      ref.watch(houseRulePackCatalogProvider).valueOrNull ??
      const HouseRulePackCatalog();
  final disabled = ref.watch(catalogDisabledHouseRulePackIdsProvider);
  return packCatalog.resolveActivePackIds(disabled);
});

/// Reaktiver Einzel-Check fuer eine Hausregel-Paket-ID.
final isHouseRuleActiveProvider = Provider.family<bool, String>((ref, packId) {
  final active = ref.watch(activeHouseRulePackIdsProvider);
  return active.contains(packId.trim());
});
