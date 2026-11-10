import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/kraeuter_loader.dart';
import 'package:dsa_heldenverwaltung/domain/kraeuter_eintrag.dart';

/// Kräutertabellen aus dem Katalog (`kraeuter.json`) für die Kräutersuche.
final kraeuterKatalogProvider = FutureProvider<KraeuterKatalog>(
  (ref) => ladeKraeuter(),
);
