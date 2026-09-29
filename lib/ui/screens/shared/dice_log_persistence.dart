import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
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

/// Oeffnet den Probe-Dialog und protokolliert Haupt- und Nebenwuerfe.
///
/// Protokolliert wird ohne Warten, damit der Dialog sofort weiterlaeuft;
/// ein Speicherfehler erscheint trotzdem als Snackbar.
Future<void> showLoggedProbeDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required ResolvedProbeRequest request,
  void Function(ProbeResult result)? onResolved,
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

  return showProbeDialog(
    context: context,
    request: request,
    onResolved: (result) {
      onResolved?.call(result);
      protokolliere(diceLogEntryFromResult(result));
    },
    onDiceLogEntry: protokolliere,
  );
}
