import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/kurzregel_loader.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

/// Kurzregel-Kompendium, entschluesselt sobald ein Katalogpasswort vorliegt.
///
/// Haengt nur am Passwort, nicht am Heldenkatalog: das Kompendium ist
/// heldenunabhaengig und soll auch ohne geladene Wissensbasis funktionieren.
/// Ohne Passwort liefert es Eintraege mit Titel und Beleg, aber gesperrten
/// Texten.
final kurzregelKatalogProvider = FutureProvider<KurzregelKatalog>((ref) {
  final passwort = ref.watch(catalogContentPasswordProvider);
  return ladeKurzregeln(passwort: passwort);
});
