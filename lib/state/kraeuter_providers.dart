import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';
import 'package:dsa_heldenverwaltung/catalog/kraeuter_loader.dart';
import 'package:dsa_heldenverwaltung/domain/kraeuter_eintrag.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';

/// Kräutertabellen aus dem Katalog (`kraeuter.json`) für die Kräutersuche.
///
/// Mit Katalogpasswort sind die Kurzbeschreibungen entschlüsselt. Scheitert
/// die Schlüsselableitung, lädt der Katalog trotzdem: die Suche selbst braucht
/// kein Passwort, nur die Beschreibungen bleiben gesperrt.
final kraeuterKatalogProvider = FutureProvider<KraeuterKatalog>((ref) async {
  CatalogKey? schluessel;
  try {
    schluessel = await ref.watch(catalogKeyV3Provider.future);
  } on Object {
    schluessel = null;
  }
  return ladeKraeuter(schluessel: schluessel);
});
