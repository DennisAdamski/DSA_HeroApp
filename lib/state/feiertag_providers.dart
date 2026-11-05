import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/feiertag_loader.dart';

/// Datumsfeste Feiertage aus dem Katalog (`feiertage.json`).
final feiertagKatalogProvider = FutureProvider<FeiertagKatalog>(
  (ref) => ladeFeiertage(),
);
