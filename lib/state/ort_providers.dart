import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/ort_loader.dart';
import 'package:dsa_heldenverwaltung/catalog/ortsfakten_loader.dart';
import 'package:dsa_heldenverwaltung/domain/ortsfakten.dart';

/// Ortsverzeichnis aus dem Katalog (`orte.json`) für die Ortsauswahl.
final ortKatalogProvider = FutureProvider<OrtKatalog>((ref) => ladeOrte());

/// Kurzfakten und Bauwerke der Siedlungen (`ortsfakten.json`), geladen erst,
/// wenn eine Ortsansicht sie braucht.
final ortsfaktenProvider = FutureProvider<OrtsfaktenKatalog>(
  (ref) => ladeOrtsfakten(),
);
