import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_loader.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';

final catalogLoaderProvider = Provider<CatalogLoader>((ref) {
  return const CatalogLoader();
});

final rulesCatalogProvider = FutureProvider<RulesCatalog>((ref) async {
  final loader = ref.watch(catalogLoaderProvider);
  return loader.loadDefaultCatalog();
});
