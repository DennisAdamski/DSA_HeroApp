import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/ort_loader.dart';

/// Ortsverzeichnis aus dem Katalog (`orte.json`) für die Ortsauswahl.
final ortKatalogProvider = FutureProvider<OrtKatalog>((ref) => ladeOrte());
