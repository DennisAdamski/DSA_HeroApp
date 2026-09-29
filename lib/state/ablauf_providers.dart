import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/rast_abschliessen.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/schaden_erhalten.dart';
import 'package:dsa_heldenverwaltung/state/hero_base_providers.dart';

/// Bindet den Ablauf „Rast abschließen“ an das aktive Heldenrepository.
///
/// Wechselt das Repository (Anmelden, Abmelden, Speicherort), entsteht ein
/// neuer Ablauf auf dem neuen Speicher.
final rastAbschliessenProvider = Provider<RastAbschliessen>((ref) {
  return RastAbschliessen(
    repository: ref.watch(heroRepositoryProvider),
    uhr: DateTime.now,
  );
});

/// Bindet den Ablauf „Schaden erhalten“ an das aktive Heldenrepository.
final schadenErhaltenProvider = Provider<SchadenErhalten>((ref) {
  return SchadenErhalten(
    repository: ref.watch(heroRepositoryProvider),
    uhr: DateTime.now,
  );
});
