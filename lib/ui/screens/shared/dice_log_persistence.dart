import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
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
Future<void> persistDiceLogEntries({
  required WidgetRef ref,
  required String heroId,
  required List<DiceLogEntry> entries,
}) async {
  if (entries.isEmpty) {
    return;
  }
  final state = ref.read(heroStateProvider(heroId)).valueOrNull;
  if (state == null) {
    return;
  }
  final updated = state.withAppendedDiceLogEntries(entries);
  await ref.read(heroActionsProvider).saveHeroState(heroId, updated);
}

/// Oeffnet den Probe-Dialog und protokolliert Haupt- und Nebenwuerfe.
Future<void> showLoggedProbeDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required ResolvedProbeRequest request,
  void Function(ProbeResult result)? onResolved,
}) {
  return showProbeDialog(
    context: context,
    request: request,
    onResolved: (result) {
      onResolved?.call(result);
      unawaited(
        persistDiceLogEntry(
          ref: ref,
          heroId: heroId,
          entry: diceLogEntryFromResult(result),
        ),
      );
    },
    onDiceLogEntry: (entry) {
      unawaited(persistDiceLogEntry(ref: ref, heroId: heroId, entry: entry));
    },
  );
}
