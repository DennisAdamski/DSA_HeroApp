import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/regelprofil_vergleich.dart';
import 'package:dsa_heldenverwaltung/domain/hero_gruppen_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/rules/derived/regelprofil_vorschau_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/externe_helden_providers.dart';
import 'package:dsa_heldenverwaltung/state/firebase_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/regelprofil_providers.dart';
import 'package:dsa_heldenverwaltung/state/regelprofil_vorschau_providers.dart';

/// Primäre Konto-Gruppe des Helden (ARCH-04); `null`, wenn er keine hat.
///
/// Ein Held kann mehreren Gruppen angehören, folgt aber nur dem Regelprofil
/// der primären. Altgruppen (gesperrter Legacy-Pfad) zählen nie.
final heroPrimaereGruppeProvider =
    Provider.family<HeroGruppenMitgliedschaft?, String>((ref, heroId) {
      final gruppen = ref.watch(
        heroByIdProvider(heroId).select((hero) => hero?.gruppen),
      );
      if (gruppen == null) return null;
      for (final gruppe in gruppen) {
        if (gruppe.kontoGruppe && gruppe.primaer) return gruppe;
      }
      return null;
    });

/// Regelprofil-Vorgabe einer Konto-Gruppe (`shared_info/regelprofil`).
///
/// `null` ohne Vorgabe oder wenn Firestore nicht verfügbar ist (Windows): Dann
/// gilt die eigene Auswahl des Helden. Ohne Verbindung erscheint ein
/// `AsyncError`; der Held rechnet unverändert mit seinem gespeicherten Profil
/// weiter.
final gruppenRegelVorgabeProvider = FutureProvider.autoDispose
    .family<HeroRegelProfil?, String>((ref, groupId) async {
      final firebase = ref.watch(firebaseBootstrapProvider);
      if (!firebase.isFirestoreAvailable) {
        return null;
      }
      return ref.watch(gruppenSyncServiceProvider).ladeRegelVorgabe(groupId);
    });

/// Eine abweichende Regelprofil-Vorgabe der primären Gruppe als Vorschau.
typedef GruppenVorgabeVorschau = ({
  String gruppenCode,
  String gruppenName,
  RegelProfilVorschau vorschau,
});

/// Vorschau der Gruppenvorgabe für den Helden (ARCH-04).
///
/// `null` im Wert heißt: nichts anzubieten – keine primäre Gruppe, keine
/// Vorgabe, kein Firestore oder der Held rechnet bereits mit der Vorgabe. Die
/// Vorschau liest nur: Das Profil des Helden ändert sich ausschließlich durch
/// die ausdrückliche Übernahme (`uebernehmeRegelProfil`). Ein Held ohne eigenes
/// Profil wird mit dem globalen Stand verglichen, den er heute tatsächlich hat.
final gruppenVorgabeVorschauProvider = Provider.autoDispose
    .family<AsyncValue<GruppenVorgabeVorschau?>, String>((ref, heroId) {
      final hero = ref.watch(heroByIdProvider(heroId));
      final primaer = ref.watch(heroPrimaereGruppeProvider(heroId));
      final eigenes = ref.watch(heroRegelProfilProvider(heroId));
      // Ein von einer neueren App geschriebenes Profil bleibt unangetastet.
      if (hero == null ||
          primaer == null ||
          (hero.regelProfil != null && eigenes == null)) {
        return const AsyncValue<GruppenVorgabeVorschau?>.data(null);
      }

      final vorgabeAsync = ref.watch(
        gruppenRegelVorgabeProvider(primaer.gruppenCode),
      );
      if (vorgabeAsync.hasError) {
        return AsyncValue<GruppenVorgabeVorschau?>.error(
          vorgabeAsync.error!,
          vorgabeAsync.stackTrace ?? StackTrace.current,
        );
      }
      if (vorgabeAsync.isLoading) {
        return const AsyncValue<GruppenVorgabeVorschau?>.loading();
      }
      final vorgabe = vorgabeAsync.valueOrNull;
      if (vorgabe == null || (eigenes != null && eigenes == vorgabe)) {
        return const AsyncValue<GruppenVorgabeVorschau?>.data(null);
      }

      final HeroRegelProfil bisher;
      if (eigenes != null) {
        bisher = eigenes;
      } else {
        final global = ref.watch(globalesRegelProfilProvider);
        if (global.hasError) {
          return AsyncValue<GruppenVorgabeVorschau?>.error(
            global.error!,
            global.stackTrace ?? StackTrace.current,
          );
        }
        final wert = global.valueOrNull;
        if (wert == null) {
          return const AsyncValue<GruppenVorgabeVorschau?>.loading();
        }
        bisher = wert;
      }

      final alt = ref.watch(regelProfilAufloesungProvider(bisher));
      final neu = ref.watch(regelProfilAufloesungProvider(vorgabe));
      final aufloesungsFehler = alt.hasError
          ? alt
          : neu.hasError
          ? neu
          : null;
      if (aufloesungsFehler != null) {
        return AsyncValue<GruppenVorgabeVorschau?>.error(
          aufloesungsFehler.error!,
          aufloesungsFehler.stackTrace ?? StackTrace.current,
        );
      }
      final zustand = ref.watch(heroStateProvider(heroId));
      if (zustand.hasError) {
        return AsyncValue<GruppenVorgabeVorschau?>.error(
          zustand.error!,
          zustand.stackTrace ?? StackTrace.current,
        );
      }
      final paketKatalog = ref.watch(houseRulePackCatalogProvider).valueOrNull;
      final altWert = alt.valueOrNull;
      final neuWert = neu.valueOrNull;
      final zustandWert = zustand.valueOrNull;
      if (altWert == null ||
          neuWert == null ||
          zustandWert == null ||
          paketKatalog == null) {
        return const AsyncValue<GruppenVorgabeVorschau?>.loading();
      }

      final vergleich = vergleicheAufloesungen(
        altesProfil: bisher,
        neuesProfil: vorgabe,
        alt: altWert,
        neu: neuWert,
        aktuellerPaketKatalog: paketKatalog,
      );
      final vorschau = erstelleRegelProfilVorschau(
        hero: hero,
        state: zustandWert,
        vergleich: vergleich,
        talentBeOverride: ref.watch(talentBeOverrideProvider(heroId)),
      );
      // Gleicher Stand wie die Vorgabe und nichts zu melden: nichts anbieten.
      if (!vorschau.uebernehmbar && vorschau.istLeer) {
        return const AsyncValue<GruppenVorgabeVorschau?>.data(null);
      }
      return AsyncValue<GruppenVorgabeVorschau?>.data((
        gruppenCode: primaer.gruppenCode,
        gruppenName: primaer.gruppenName,
        vorschau: vorschau,
      ));
    });
