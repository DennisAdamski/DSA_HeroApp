import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/data/custom_catalog_repository.dart';
import 'package:dsa_heldenverwaltung/data/house_rule_pack_repository.dart';
import 'package:dsa_heldenverwaltung/rules/house_rules/house_rule_registry.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

/// Echter `house_rules_v1`-Katalog, wie ihn die App ohne Inhaltspasswort und
/// ohne eigene Katalogeintraege sieht.
///
/// Alle eingebauten Hausregel-Pakete sind aktiv (Standard ohne deaktivierte
/// Pakete). Geschuetzte Felder bleiben `enc:`-verschluesselt.
class EchterKatalog {
  /// Buendelt Katalog und Laufzeitdaten eines einzelnen Ladevorgangs.
  const EchterKatalog({required this.catalog, required this.runtimeData});

  /// Wirksamer Regelkatalog (`rulesCatalogProvider`).
  final RulesCatalog catalog;

  /// Aufgeloeste Laufzeitdaten (`catalogRuntimeDataProvider`).
  final CatalogRuntimeData runtimeData;

  /// Ob das Hausregel-Paket fuer epische Vorteile wirksam ist.
  bool get epicAdvantagesActive {
    return runtimeData.activeHouseRulePackIds.contains(EpicRuleKeys.advantages);
  }

  /// Provider-Overrides, mit denen ein Container denselben Katalog nutzt,
  /// ohne die Katalogkette erneut zu laden.
  List<Override> get overrides {
    return <Override>[
      catalogRuntimeDataProvider.overrideWith((ref) async => runtimeData),
      rulesCatalogProvider.overrideWith((ref) async => catalog),
      customCatalogRepositoryProvider.overrideWithValue(
        const CustomCatalogRepository(heroStoragePath: ''),
      ),
    ];
  }
}

Future<EchterKatalog>? _cache;

/// Laedt den echten Katalog einmal pro Test-Isolat.
///
/// Braucht `TestWidgetsFlutterBinding.ensureInitialized()`, weil die Assets
/// ueber `rootBundle` gelesen werden. Gewartet wird ueber `listen` statt
/// `read(provider.future)`: in Riverpod 3.2 wird diese Future bei einem Fehler
/// nie erfuellt (siehe CLAUDE.md), der Test hinge dann bis zum Zeitlimit.
Future<EchterKatalog> ladeEchtenRegelkatalog() {
  return _cache ??= _ladeEchtenRegelkatalog();
}

// Baut die produktive Katalogkette mit leerem Heldenspeicher auf.
Future<EchterKatalog> _ladeEchtenRegelkatalog() async {
  final container = ProviderContainer(
    overrides: [
      customCatalogRepositoryProvider.overrideWithValue(
        const CustomCatalogRepository(heroStoragePath: ''),
      ),
      houseRulePackRepositoryProvider.overrideWithValue(
        const HouseRulePackRepository(heroStoragePath: ''),
      ),
      catalogDisabledHouseRulePackIdsProvider.overrideWithValue(
        const <String>{},
      ),
      catalogContentPasswordProvider.overrideWithValue(null),
    ],
  );
  try {
    final runtimeData = await _warteAuf(container, catalogRuntimeDataProvider);
    final catalog = await _warteAuf(container, rulesCatalogProvider);
    return EchterKatalog(catalog: catalog, runtimeData: runtimeData);
  } finally {
    container.dispose();
  }
}

// Wartet per Abonnement auf den ersten Wert oder Fehler eines Providers.
Future<T> _warteAuf<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
) {
  final completer = Completer<T>();
  void pruefe(AsyncValue<T> value) {
    if (completer.isCompleted) {
      return;
    }
    if (value.hasError) {
      completer.completeError(value.error!, value.stackTrace);
    } else if (value.hasValue) {
      completer.complete(value.requireValue);
    }
  }

  container.listen<AsyncValue<T>>(
    provider,
    (_, next) => pruefe(next),
    fireImmediately: true,
  );
  return completer.future.timeout(const Duration(seconds: 60));
}
