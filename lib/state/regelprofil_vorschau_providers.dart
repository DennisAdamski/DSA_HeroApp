import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/regelprofil_aufloesung.dart';
import 'package:dsa_heldenverwaltung/catalog/regelprofil_vergleich.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/rules/derived/regelprofil_vorschau_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/house_rules_providers.dart';
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
      return ref.watch(
        regelProfilVergleichMitZusatzProvider((profil: profil, zusatz: '')),
      );
    });

/// Schlüssel des Vergleichs: Profil plus kodierte Zusatzpakete
/// ([zusatzPaketSchluessel]).
typedef RegelProfilVergleichSchluessel = ({
  HeroRegelProfil profil,
  String zusatz,
});

/// Kodiert gewählte Zusatzpakete als Familienschlüssel mit Wertgleichheit
/// (sortiert, durch Komma getrennt; leer = keine).
String zusatzPaketSchluessel(Iterable<String> paketIds) {
  final ids = <String>{
    for (final id in paketIds)
      if (id.trim().isNotEmpty) id.trim(),
  }.toList()..sort();
  return ids.join(',');
}

/// Wie [regelProfilVergleichProvider], aber mit zusätzlich gewählten Paketen
/// ([RegelProfilVergleichSchluessel.zusatz] kommt aus
/// [zusatzPaketSchluessel]). Fehlende Elternpakete der Auswahl kommen
/// automatisch hinzu.
final regelProfilVergleichMitZusatzProvider =
    Provider.family<
      AsyncValue<RegelProfilVergleich>,
      RegelProfilVergleichSchluessel
    >((ref, schluessel) {
      final vorschlag = ref.watch(regelProfilVorschlagProvider(schluessel));
      final neu = vorschlag.valueOrNull;
      if (vorschlag.hasError) {
        return AsyncValue<RegelProfilVergleich>.error(
          vorschlag.error!,
          vorschlag.stackTrace ?? StackTrace.current,
        );
      }
      if (neu == null) return const AsyncValue<RegelProfilVergleich>.loading();
      return ref.watch(
        regelProfilWechselVergleichProvider((alt: schluessel.profil, neu: neu)),
      );
    });

/// Vorschlag zum Profil: jedes Paket auf seinem aktuellen Stand, dazu die
/// gewählten Zusatzpakete samt fehlender Elternpakete (`schlageProfilVor`).
/// Er wird nur berechnet, nie geschrieben.
final regelProfilVorschlagProvider =
    Provider.family<
      AsyncValue<HeroRegelProfil>,
      RegelProfilVergleichSchluessel
    >((ref, schluessel) {
      final profil = schluessel.profil;
      final basis = ref.watch(decryptedCatalogSourceDataProvider);
      final paketKatalog = ref.watch(houseRulePackCatalogProvider);
      final fehler = basis.hasError
          ? basis
          : paketKatalog.hasError
          ? paketKatalog
          : null;
      if (fehler != null) {
        return AsyncValue<HeroRegelProfil>.error(
          fehler.error!,
          fehler.stackTrace ?? StackTrace.current,
        );
      }
      final basisDaten = basis.valueOrNull;
      final pakete = paketKatalog.valueOrNull;
      if (basisDaten == null || pakete == null) {
        return const AsyncValue<HeroRegelProfil>.loading();
      }
      final gewaehlt = schluessel.zusatz.isEmpty
          ? const <String>{}
          : schluessel.zusatz.split(',').toSet();
      return AsyncValue<HeroRegelProfil>.data(
        schlageProfilVor(
          profil: profil,
          aktuellerPaketKatalog: pakete,
          catalogVersion: basisDaten.version,
          zusaetzlichePaketIds: zusatzPaketeMitElternpaketen(
            gewaehlt: gewaehlt,
            profil: profil,
            aktuellerPaketKatalog: pakete,
          ),
        ),
      );
    });

/// Schlüssel eines Profilwechsels: bisheriges und neues Profil.
typedef RegelProfilWechsel = ({HeroRegelProfil alt, HeroRegelProfil neu});

/// Katalogvergleich eines beliebigen Profilwechsels [RegelProfilWechsel]
/// (ARCH-04): Update auf den aktuellen Paketstand ebenso wie die Übernahme der
/// Gruppenvorgabe. Beide Seiten kommen aus `regelProfilAufloesungProvider`.
final regelProfilWechselVergleichProvider =
    Provider.family<AsyncValue<RegelProfilVergleich>, RegelProfilWechsel>((
      ref,
      wechsel,
    ) {
      final pakete = ref.watch(houseRulePackCatalogProvider);
      final alt = ref.watch(regelProfilAufloesungProvider(wechsel.alt));
      final neu = ref.watch(regelProfilAufloesungProvider(wechsel.neu));
      final fehler = pakete.hasError
          ? pakete
          : alt.hasError
          ? alt
          : neu.hasError
          ? neu
          : null;
      if (fehler != null) {
        return AsyncValue<RegelProfilVergleich>.error(
          fehler.error!,
          fehler.stackTrace ?? StackTrace.current,
        );
      }
      final paketWert = pakete.valueOrNull;
      final altWert = alt.valueOrNull;
      final neuWert = neu.valueOrNull;
      if (paketWert == null || altWert == null || neuWert == null) {
        return const AsyncValue<RegelProfilVergleich>.loading();
      }
      return AsyncValue<RegelProfilVergleich>.data(
        vergleicheAufloesungen(
          altesProfil: wechsel.alt,
          neuesProfil: wechsel.neu,
          alt: altWert,
          neu: neuWert,
          aktuellerPaketKatalog: paketWert,
        ),
      );
    });

/// Schlüssel der Wechselvorschau: Held und Profilwechsel.
typedef RegelProfilWechselVorschauSchluessel = ({
  String heroId,
  HeroRegelProfil alt,
  HeroRegelProfil neu,
});

/// Vorschau, was sich für den Helden durch einen Profilwechsel ändert
/// (ARCH-04). Sie liest nur; geschrieben wird ausschließlich durch die
/// ausdrückliche Übernahme. Wert `null`, solange der Held fehlt.
final regelProfilWechselVorschauProvider =
    Provider.family<
      AsyncValue<RegelProfilVorschau?>,
      RegelProfilWechselVorschauSchluessel
    >((ref, schluessel) {
      final hero = ref.watch(heroByIdProvider(schluessel.heroId));
      if (hero == null) {
        return const AsyncValue<RegelProfilVorschau?>.data(null);
      }
      final vergleich = ref.watch(
        regelProfilWechselVergleichProvider((
          alt: schluessel.alt,
          neu: schluessel.neu,
        )),
      );
      final zustand = ref.watch(heroStateProvider(schluessel.heroId));
      final fehler = vergleich.hasError
          ? vergleich
          : zustand.hasError
          ? zustand
          : null;
      if (fehler != null) {
        return AsyncValue<RegelProfilVorschau?>.error(
          fehler.error!,
          fehler.stackTrace ?? StackTrace.current,
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
          talentBeOverride: ref.watch(
            talentBeOverrideProvider(schluessel.heroId),
          ),
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
      return ref.watch(
        regelProfilVorschauMitZusatzProvider((heroId: heroId, zusatz: '')),
      );
    });

/// Schlüssel der Vorschau: Held plus kodierte Zusatzpakete
/// ([zusatzPaketSchluessel]).
typedef RegelProfilVorschauSchluessel = ({String heroId, String zusatz});

/// Wie [regelProfilVorschauProvider], aber mit zusätzlich gewählten Paketen.
/// Die Auswahl hält der Dialog selbst; sie ist flüchtig und schreibt nichts.
final regelProfilVorschauMitZusatzProvider =
    Provider.family<
      AsyncValue<RegelProfilVorschau?>,
      RegelProfilVorschauSchluessel
    >((ref, schluessel) {
      final heroId = schluessel.heroId;
      final profil = ref.watch(heroRegelProfilProvider(heroId));
      if (profil == null || ref.watch(heroByIdProvider(heroId)) == null) {
        return const AsyncValue<RegelProfilVorschau?>.data(null);
      }
      final vorschlag = ref.watch(
        regelProfilVorschlagProvider((
          profil: profil,
          zusatz: schluessel.zusatz,
        )),
      );
      if (vorschlag.hasError) {
        return AsyncValue<RegelProfilVorschau?>.error(
          vorschlag.error!,
          vorschlag.stackTrace ?? StackTrace.current,
        );
      }
      final neu = vorschlag.valueOrNull;
      if (neu == null) return const AsyncValue<RegelProfilVorschau?>.loading();
      return ref.watch(
        regelProfilWechselVorschauProvider((
          heroId: heroId,
          alt: profil,
          neu: neu,
        )),
      );
    });

/// Regelstand, den ein Held ohne Profil heute tatsächlich hat (ARCH-04).
///
/// Das Profil, das die Erstübernahme (`null → Profil`) festhalten würde: die
/// aktiven Hausregelpakete der globalen Einstellungen mit Manifestkopie und
/// Prüfsumme. Es wird nur berechnet; geschrieben wird erst durch die bewusste
/// Übernahme des Nutzers.
final globalesRegelProfilProvider = Provider<AsyncValue<HeroRegelProfil>>((
  ref,
) {
  final basis = ref.watch(decryptedCatalogSourceDataProvider);
  final paketKatalog = ref.watch(houseRulePackCatalogProvider);
  final fehler = basis.hasError
      ? basis
      : paketKatalog.hasError
      ? paketKatalog
      : null;
  if (fehler != null) {
    return AsyncValue<HeroRegelProfil>.error(
      fehler.error!,
      fehler.stackTrace ?? StackTrace.current,
    );
  }
  final basisDaten = basis.valueOrNull;
  final pakete = paketKatalog.valueOrNull;
  if (basisDaten == null || pakete == null) {
    return const AsyncValue<HeroRegelProfil>.loading();
  }
  return AsyncValue<HeroRegelProfil>.data(
    regelProfilAusGlobalemStand(
      catalogVersion: basisDaten.version,
      paketKatalog: pakete,
      aktivePaketIds: ref.watch(activeHouseRulePackIdsProvider),
    ),
  );
});
