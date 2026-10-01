import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

import '../shell/karto_test_support.dart';

/// Kontrollierbare Brücke für Abbruch, Start und doppelte Ergebniscallbacks.
class GefechtsTestBestand extends TestBestand implements KartoGefechtsAdapter {
  final anfragen = <ResolvedProbeRequest>[];
  bool abbrechen = false;
  bool doppelt = false;
  @override
  Future<ProbeResult?> gefechtsProbe({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required ResolvedProbeRequest request,
    void Function(ProbeResult)? onResolved,
  }) async {
    anfragen.add(request);
    if (abbrechen) return null;
    final result = evaluateProbe(
      request,
      ProbeRollInput(
        mode: ProbeRollMode.manual,
        diceValues: List.filled(
          request.diceSpec.count,
          request.diceSpec.sides == 6 ? 6 : 10,
        ),
        situationalModifier: request.initialSituationalModifier,
        specializationApplied: false,
      ),
    );
    onResolved?.call(result);
    if (doppelt) onResolved?.call(result);
    return result;
  }

  @override
  Future<bool> gefechtsAusruestung({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required CombatConfig Function(CombatConfig) aenderung,
  }) async => false;
}
