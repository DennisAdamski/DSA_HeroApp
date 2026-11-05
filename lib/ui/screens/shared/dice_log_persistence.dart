import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/meisterhandwerk_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_probe_rules.dart';
import 'package:dsa_heldenverwaltung/state/ablauf_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_dialog.dart';

/// Haengt einen Wuerfelprotokoll-Eintrag an den Laufzeitzustand des Helden an.
Future<void> persistDiceLogEntry({
  required WidgetRef ref,
  required String heroId,
  required DiceLogEntry entry,
}) {
  return persistDiceLogEntries(
    ref: ref,
    heroId: heroId,
    entries: <DiceLogEntry>[entry],
  );
}

/// Haengt mehrere Wuerfelprotokoll-Eintraege in einem Speichervorgang an.
///
/// Haengt an den **gespeicherten** Zustand an, nicht an den Stand der
/// Oberflaeche: Zwei kurz nacheinander protokollierte Wuerfe laufen je Held
/// nacheinander (`aendereGespeichertenZustand`) und ueberschreiben einander
/// nicht. Speicherfehler werden an den Aufrufer weitergereicht.
Future<void> persistDiceLogEntries({
  required WidgetRef ref,
  required String heroId,
  required List<DiceLogEntry> entries,
}) async {
  if (entries.isEmpty) {
    return;
  }
  await ref
      .read(heroActionsProvider)
      .updateHeroState(
        heroId,
        (aktuell) => aktuell.withAppendedDiceLogEntries(entries),
      );
}

/// Schreibt die Beiträge laufender Zauberwirkungen (Adlerauge, Blitz) in den
/// Startmodifikator von Talent- und Zauberproben des Helden [heroId].
///
/// Ohne berechneten Helden oder ohne passenden Beitrag bleibt [request]
/// unverändert. Der Nutzer kann den Wert im Dialog noch ändern.
ResolvedProbeRequest probeMitZaubereffekten({
  required WidgetRef ref,
  required String heroId,
  required ResolvedProbeRequest request,
}) {
  final snapshot = ref.read(heroComputedProvider(heroId)).asData?.value;
  if (snapshot == null) {
    return request;
  }
  return probeMitSpellEffekten(request, snapshot.derivedStats.zauberEffekte);
}

/// Bietet die KK-/FF-Abzüge verwundeter Arme des Helden [heroId] als
/// Schalter im Probendialog an (WdS S. 108 f.: „wenn er diesen Arm benutzt“).
///
/// Ohne berechneten Helden, ohne Armwunden oder ohne KK-/FF-Ziel bleibt
/// [request] unverändert.
ResolvedProbeRequest probeMitArmwunden({
  required WidgetRef ref,
  required String heroId,
  required ResolvedProbeRequest request,
}) {
  final snapshot = ref.read(heroComputedProvider(heroId)).asData?.value;
  if (snapshot == null) {
    return request;
  }
  return probeMitArmwundenAbzug(request, snapshot.wundEffekte);
}

/// Das Meisterhandwerk-Angebot des Helden [heroId] für [request].
///
/// `null` ohne berechneten Helden oder Katalog, bei abgeschalteter Magie und
/// wenn die Regeln für diese Probe nichts anbieten.
MeisterhandwerkAngebot? meisterhandwerkFuerProbe({
  required WidgetRef ref,
  required String heroId,
  required ResolvedProbeRequest request,
}) {
  final snapshot = ref.read(heroComputedProvider(heroId)).asData?.value;
  final catalog = ref.read(heroRulesCatalogProvider(heroId)).asData?.value;
  if (snapshot == null ||
      catalog == null ||
      !snapshot.resourceActivation.magic.isEnabled) {
    return null;
  }
  return meisterhandwerkAngebotFuer(
    request: request,
    wirkungen: meisterhandwerkWirkungen(snapshot.hero, catalog: catalog),
    verfuegbareAsp: snapshot.state.currentAsp,
  );
}

/// Oeffnet den Probe-Dialog und protokolliert Haupt- und Nebenwuerfe.
///
/// [zaubereffekteAnwenden] ist für Proben fremder Wesen (Vertraute) `false`:
/// Die Zauberwirkungen, Armwunden und das Meisterhandwerk des Helden gelten
/// nur für seine eigenen Proben. AsP-Einsätze des Meisterhandwerks bucht der
/// Ablauf `MeisterhandwerkEinsetzen`.
///
/// Protokolliert wird ohne Warten, damit der Dialog sofort weiterlaeuft;
/// ein Speicherfehler erscheint trotzdem als Snackbar.
Future<void> showLoggedProbeDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required ResolvedProbeRequest request,
  void Function(ProbeResult result)? onResolved,
  bool zaubereffekteAnwenden = true,
}) {
  final bote = ScaffoldMessenger.maybeOf(context);
  void protokolliere(DiceLogEntry entry) {
    final speichern = persistDiceLogEntry(
      ref: ref,
      heroId: heroId,
      entry: entry,
    );
    unawaited(
      speichern.catchError((Object fehler) {
        bote?.showSnackBar(
          SnackBar(content: Text('Würfelprotokoll nicht gespeichert: $fehler')),
        );
      }),
    );
  }

  void bucheMeisterhandwerk(MeisterhandwerkBuchung buchung) {
    final buchen = ref
        .read(meisterhandwerkEinsetzenProvider)
        .buche(heroId: heroId, buchung: buchung);
    unawaited(
      buchen.then<void>(
        (_) {},
        onError: (Object fehler) {
          bote?.showSnackBar(
            SnackBar(content: Text('Meisterhandwerk nicht gebucht: $fehler')),
          );
        },
      ),
    );
  }

  final angepasst = zaubereffekteAnwenden
      ? probeMitArmwunden(
          ref: ref,
          heroId: heroId,
          request: probeMitZaubereffekten(
            ref: ref,
            heroId: heroId,
            request: request,
          ),
        )
      : request;
  return showProbeDialog(
    context: context,
    request: angepasst,
    onResolved: (result) {
      onResolved?.call(result);
      protokolliere(diceLogEntryFromResult(result));
    },
    onDiceLogEntry: protokolliere,
    contentUnlocked: ref.read(catalogContentVisibleProvider),
    contentPassword: ref.read(catalogContentPasswordProvider),
    meisterhandwerk: zaubereffekteAnwenden
        ? meisterhandwerkFuerProbe(ref: ref, heroId: heroId, request: angepasst)
        : null,
    onMeisterhandwerk: bucheMeisterhandwerk,
  );
}
