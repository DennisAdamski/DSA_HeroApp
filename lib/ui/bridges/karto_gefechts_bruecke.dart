import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/dice_log_persistence.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_dialog.dart';

/// Probenarten, deren Erschwernis der Gefechtsdialog bereits festlegt.
///
/// Eigenschafts-, INI- und Schadenswürfe haben dort kein eigenes Feld und
/// behalten den freien situativen Modifikator.
const kGefechtsprobenMitFestemModifikator = {
  ProbeType.combatAttack,
  ProbeType.combatParry,
  ProbeType.dodge,
  ProbeType.spell,
  ProbeType.talent,
};

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
  // Zauberproben tragen ihre Zaubereffekte bereits im Zuschlag des
  // Wirkdialogs (`gefechtsZauberZuschlag`); nur Talentproben nicht.
  final mitEffekten = request.type == ProbeType.talent
      ? probeMitZaubereffekten(ref: ref, heroId: heroId, request: request)
      : request;
  // Armwunden: KK/FF gelten nur mit dem verwundeten Arm, der Dialog fragt.
  final angepasst = probeMitArmwunden(
    ref: ref,
    heroId: heroId,
    request: mitEffekten,
  );
  await showProbeDialog(
    context: context,
    request: angepasst,
    singleResolution: true,
    modifikatorGesperrt: kGefechtsprobenMitFestemModifikator.contains(
      request.type,
    ),
    onResolved: (result) {
      if (ergebnis != null) return;
      ergebnis = result;
      eintraege.add(diceLogEntryFromResult(result));
      onResolved?.call(result);
    },
    onDiceLogEntry: eintraege.add,
    contentUnlocked: ref.read(catalogContentVisibleProvider),
    contentPassword: ref.read(catalogContentPasswordProvider),
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
