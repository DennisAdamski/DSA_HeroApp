import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/vitalwirkung_anwenden.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/artefakt_protokollieren.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/auxiliator_einsetzen.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/heilung_erhalten.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/matrix_ausloesen.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/rast_abschliessen.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/regelprofil_uebernehmen.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/ruhe_koerper_erhalten.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/schaden_erhalten.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/schaden_zuruecknehmen.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/steigerungsrunde_uebernehmen.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/vertrauten_vereinigung.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

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

/// Bindet den Ablauf „Vereinigung bei Vollmond“ (V2) an das aktive
/// Heldenrepository.
final vertrautenVereinigungProvider = Provider<VertrautenVereinigung>((ref) {
  return VertrautenVereinigung(
    repository: ref.watch(heroRepositoryProvider),
    uhr: DateTime.now,
  );
});

/// Bindet den Ablauf „Matrixgeber auslösen“ an das aktive Heldenrepository.
final matrixAusloesenProvider = Provider<MatrixAusloesen>((ref) {
  return MatrixAusloesen(
    repository: ref.watch(heroRepositoryProvider),
    uhr: DateTime.now,
  );
});

/// Bindet den Ablauf „Auxiliator einsetzen“ an das aktive Heldenrepository.
final auxiliatorEinsetzenProvider = Provider<AuxiliatorEinsetzen>((ref) {
  return AuxiliatorEinsetzen(
    repository: ref.watch(heroRepositoryProvider),
    uhr: DateTime.now,
  );
});

/// Bindet den Ablauf „Artefaktvorgang protokollieren“ an das aktive
/// Heldenrepository.
final artefaktProtokollierenProvider = Provider<ArtefaktProtokollieren>((ref) {
  return ArtefaktProtokollieren(
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

/// Bindet den Ablauf „Heilung erhalten“ (MAG-EFF-05) an das aktive
/// Heldenrepository.
final heilungErhaltenProvider = Provider<HeilungErhalten>((ref) {
  return HeilungErhalten(
    repository: ref.watch(heroRepositoryProvider),
    uhr: DateTime.now,
  );
});

/// Bindet den Ablauf „Gegenstand anwenden“ (Heiltrank, Verband …) an das
/// aktive Heldenrepository.
final vitalwirkungAnwendenProvider = Provider<VitalwirkungAnwenden>((ref) {
  return VitalwirkungAnwenden(
    repository: ref.watch(heroRepositoryProvider),
    uhr: DateTime.now,
  );
});

/// Bindet den Ablauf „Ruhe Körper“ (MAG-EFF-05) an das aktive
/// Heldenrepository.
final ruheKoerperErhaltenProvider = Provider<RuheKoerperErhalten>((ref) {
  return RuheKoerperErhalten(
    repository: ref.watch(heroRepositoryProvider),
    uhr: DateTime.now,
  );
});

/// Bindet den Ablauf „Schaden zurücknehmen“ (ARCH-06) an das aktive
/// Heldenrepository.
final schadenZuruecknehmenProvider = Provider<SchadenZuruecknehmen>((ref) {
  return SchadenZuruecknehmen(
    repository: ref.watch(heroRepositoryProvider),
    uhr: DateTime.now,
  );
});

/// Bindet den Ablauf „Regelprofil übernehmen“ (ARCH-04) an den frischen
/// Schreibweg des Bogens.
final regelProfilUebernehmenProvider = Provider<RegelProfilUebernehmen>((ref) {
  return RegelProfilUebernehmen(
    aendere: ref.watch(heroActionsProvider).updateHero,
  );
});

/// Bindet den Ablauf „Steigerungsrunde übernehmen“ an das aktive
/// Heldenrepository und die Normalisierung von `HeroActions.saveHero`.
final steigerungsrundeUebernehmenProvider =
    Provider<SteigerungsrundeUebernehmen>((ref) {
      return SteigerungsrundeUebernehmen(
        repository: ref.watch(heroRepositoryProvider),
        speichere: ref.watch(heroActionsProvider).saveHero,
      );
    });
