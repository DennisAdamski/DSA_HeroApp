import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/dice_log_persistence.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_dialog.dart';

/// Ein Auftrag ergibt genau eine Probe; Protokollfehler bleiben sichtbar.
Future<ProbeResult?> zeigeGefechtsprobe({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required ResolvedProbeRequest request,
  void Function(ProbeResult)? onResolved,
}) async {
  ProbeResult? ergebnis;
  final eintraege = <DiceLogEntry>[];
  await showProbeDialog(
    context: context,
    request: request,
    singleResolution: true,
    onResolved: (result) {
      if (ergebnis != null) return;
      ergebnis = result;
      eintraege.add(diceLogEntryFromResult(result));
      onResolved?.call(result);
    },
    onDiceLogEntry: eintraege.add,
  );
  try {
    await persistDiceLogEntries(ref: ref, heroId: heroId, entries: eintraege);
  } catch (fehler) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Würfelprotokoll nicht gespeichert: $fehler')),
      );
    }
  }
  return ergebnis;
}
