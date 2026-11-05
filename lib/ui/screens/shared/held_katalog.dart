import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

/// Katalog, nach dem der Held [heroId] rechnet (Regelprofil, ARCH-04).
///
/// Für Bausteine, die sowohl am Helden als auch heldenlos (etwa in der
/// Katalogpflege) laufen: Ohne Helden-ID gilt der globale Katalog. Held-
/// gebundene Ansichten reichen die ID immer durch, damit ein Held mit eigenem
/// Regelprofil dieselben Einträge sieht wie in der Kartograph-Oberfläche.
AsyncValue<RulesCatalog> beobachteHeldenKatalog(WidgetRef ref, String? heroId) {
  if (heroId == null) {
    return ref.watch(rulesCatalogProvider);
  }
  return ref.watch(heroRulesCatalogProvider(heroId));
}
