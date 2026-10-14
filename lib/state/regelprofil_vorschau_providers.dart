import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/regelprofil_aufloesung.dart';
import 'package:dsa_heldenverwaltung/catalog/regelprofil_vergleich.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/rules/derived/regelprofil_vorschau_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/regelprofil_providers.dart';

/// Katalogvergleich eines Profils mit dem aktuellen Paketstand (ARCH-04).
///
/// Schlüssel ist das Profil; Helden mit gleichem Profil teilen den Vergleich.
/// Beide Seiten kommen aus `regelProfilAufloesungProvider`, also aus
/// denselben gemeinsam genutzten Auflösungen, nach denen die Helden rechnen.
/// Der Vorschlag hebt jedes Paket des Profils auf seinen aktuellen Stand
/// (`schlageProfilVor`); er schreibt nichts.
final regelProfilVergleichProvider =
    Provider.family<AsyncValue<RegelProfilVergleich>, HeroRegelProfil>((
      ref,
      profil,
    ) {
      final basis = ref.watch(decryptedCatalogSourceDataProvider);
      final paketKatalog = ref.watch(houseRulePackCatalogProvider);
      final fehler = basis.hasError
          ? basis
          : paketKatalog.hasError
          ? paketKatalog
          : null;
      if (fehler != null) {
        return AsyncValue<RegelProfilVergleich>.error(
          fehler.error!,
          fehler.stackTrace ?? StackTrace.current,
        );
      }
      final basisDaten = basis.valueOrNull;
      final pakete = paketKatalog.valueOrNull;
      if (basisDaten == null || pakete == null) {
        return const AsyncValue<RegelProfilVergleich>.loading();
      }
      final vorschlag = schlageProfilVor(
        profil: profil,
        aktuellerPaketKatalog: pakete,
        catalogVersion: basisDaten.version,
      );
      final alt = ref.watch(regelProfilAufloesungProvider(profil));
      final neu = ref.watch(regelProfilAufloesungProvider(vorschlag));
      final aufloesungsFehler = alt.hasError
          ? alt
          : neu.hasError
          ? neu
          : null;
      if (aufloesungsFehler != null) {
        return AsyncValue<RegelProfilVergleich>.error(
          aufloesungsFehler.error!,
          aufloesungsFehler.stackTrace ?? StackTrace.current,
        );
      }
      final altWert = alt.valueOrNull;
      final neuWert = neu.valueOrNull;
      if (altWert == null || neuWert == null) {
        return const AsyncValue<RegelProfilVergleich>.loading();
      }
      return AsyncValue<RegelProfilVergleich>.data(
        vergleicheAufloesungen(
          altesProfil: profil,
          neuesProfil: vorschlag,
          alt: altWert,
          neu: neuWert,
          aktuellerPaketKatalog: pakete,
        ),
      );
    });

/// Updatevorschau des Regelprofils eines Helden (ARCH-04).
///
/// `null` im Wert heißt: Der Held hat kein (verstandenes) Profil und folgt den
/// globalen Einstellungen; dann gibt es nichts zu übernehmen. Die Vorschau
/// liest nur und ändert den Helden nie; die Übernahme läuft über
/// `regelProfilUebernehmenProvider`.
final regelProfilVorschauProvider =
    Provider.family<AsyncValue<RegelProfilVorschau?>, String>((ref, heroId) {
      final profil = ref.watch(heroRegelProfilProvider(heroId));
      final hero = ref.watch(heroByIdProvider(heroId));
      if (profil == null || hero == null) {
        return const AsyncValue<RegelProfilVorschau?>.data(null);
      }
      final vergleich = ref.watch(regelProfilVergleichProvider(profil));
      if (vergleich.hasError) {
        return AsyncValue<RegelProfilVorschau?>.error(
          vergleich.error!,
          vergleich.stackTrace ?? StackTrace.current,
        );
      }
      final zustand = ref.watch(heroStateProvider(heroId));
      if (zustand.hasError) {
        return AsyncValue<RegelProfilVorschau?>.error(
          zustand.error!,
          zustand.stackTrace ?? StackTrace.current,
        );
      }
      final vergleichWert = vergleich.valueOrNull;
      final zustandWert = zustand.valueOrNull;
      if (vergleichWert == null || zustandWert == null) {
        return const AsyncValue<RegelProfilVorschau?>.loading();
      }
      return AsyncValue<RegelProfilVorschau?>.data(
        erstelleRegelProfilVorschau(
          hero: hero,
          state: zustandWert,
          vergleich: vergleichWert,
          talentBeOverride: ref.watch(talentBeOverrideProvider(heroId)),
        ),
      );
    });
