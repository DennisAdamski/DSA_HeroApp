import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

import '../shell/karto_test_support.dart';

/// Kontrollierbare Brücke für Abbruch, Start und doppelte Ergebniscallbacks.
class GefechtsTestBestand extends TestBestand implements KartoGefechtsAdapter {
  final anfragen = <ResolvedProbeRequest>[];
  bool abbrechen = false;
  bool doppelt = false;
  int w20Wert = 10;
  Future<void>? vorErgebnis;
  @override
  Future<ProbeResult?> gefechtsProbe({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required ResolvedProbeRequest request,
    void Function(ProbeResult)? onResolved,
  }) async {
    anfragen.add(request);
    await vorErgebnis;
    if (abbrechen) return null;
    final result = evaluateProbe(
      request,
      ProbeRollInput(
        mode: ProbeRollMode.manual,
        diceValues: List.filled(
          request.diceSpec.count,
          request.diceSpec.sides == 6 ? 6 : w20Wert,
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

  // Schreibwege und Eingabedialoge des Wirkabschlusses laufen über die echte
  // Brücke, damit Zauberabläufe den produktiven Fehler- und Speicherweg prüfen.
  static const _bruecke = KartoBestandsAdapterImpl();

  @override
  Future<HeroState?> gefechtsZustand({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required String was,
    required HeroState Function(HeroState aktuell) aenderung,
  }) => _bruecke.gefechtsZustand(
    context: context,
    ref: ref,
    heroId: heroId,
    was: was,
    aenderung: aenderung,
  );

  @override
  Widget gefechtsFehlerBereich({
    required Widget Function(Widget fehleranzeige) builder,
  }) => _bruecke.gefechtsFehlerBereich(builder: builder);

  @override
  Future<ActiveSpellEffectDetail?> gefechtsArmatrutzWerte(
    BuildContext context,
  ) => _bruecke.gefechtsArmatrutzWerte(context);

  @override
  Future<AttributeModifiers?> gefechtsAttributoWerte(BuildContext context) =>
      _bruecke.gefechtsAttributoWerte(context);

  @override
  Future<void> gefechtsWirkkosten({
    required BuildContext context,
    required String heroId,
    required bool karmal,
    required int? kosten,
    required Future<bool> Function(BuildContext blatt) onUebernehmen,
  }) => _bruecke.gefechtsWirkkosten(
    context: context,
    heroId: heroId,
    karmal: karmal,
    kosten: kosten,
    onUebernehmen: onUebernehmen,
  );
}
