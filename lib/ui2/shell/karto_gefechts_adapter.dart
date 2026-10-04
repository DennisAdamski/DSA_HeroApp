import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

/// Gezielt erweiterte Bestandsbrücke für einmalige Proben und Ausrüstung.
abstract interface class KartoGefechtsAdapter {
  /// Liefert Abbruch oder ein eingefrorenes Ergebnis und protokolliert es.
  Future<ProbeResult?> gefechtsProbe({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required ResolvedProbeRequest request,
    void Function(ProbeResult)? onResolved,
  });

  /// Wendet eine gezielte Ausrüstungsänderung auf den frisch geladenen Stand an.
  Future<bool> gefechtsAusruestung({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required CombatConfig Function(CombatConfig) aenderung,
  });
}
