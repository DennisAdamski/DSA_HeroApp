import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

/// Menge der vom Benutzer deaktivierten Hausregel-Paket-IDs.
final disabledHouseRulePackIdsProvider = Provider<Set<String>>((ref) {
  final settings = ref.watch(appSettingsProvider).valueOrNull;
  return settings?.disabledHouseRulePackIds ?? const <String>{};
});

/// Rueckwaertskompatibler Alias fuer bestehende Call-Sites.
final disabledHouseRuleKeysProvider = Provider<Set<String>>((ref) {
  return ref.watch(disabledHouseRulePackIdsProvider);
});

/// Alle aktuell wirksamen Hausregel-Paket-IDs.
final activeHouseRulePackIdsProvider = Provider<Set<String>>((ref) {
  final packCatalog =
      ref.watch(houseRulePackCatalogProvider).valueOrNull ??
      const HouseRulePackCatalog();
  final disabled = ref.watch(disabledHouseRulePackIdsProvider);
  return packCatalog.resolveActivePackIds(disabled);
});

/// Rueckwaertskompatibler Alias fuer bestehende Regelabfragen.
final activeHouseRuleKeysProvider = Provider<Set<String>>((ref) {
  return ref.watch(activeHouseRulePackIdsProvider);
});

/// Reaktiver Einzel-Check fuer eine Hausregel-Paket-ID.
final isHouseRuleActiveProvider = Provider.family<bool, String>((ref, packId) {
  final active = ref.watch(activeHouseRulePackIdsProvider);
  return active.contains(packId.trim());
});
