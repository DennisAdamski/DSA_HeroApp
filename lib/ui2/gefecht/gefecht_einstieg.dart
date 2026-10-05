import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_vorgaben_rules.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielansicht.dart';

import 'gefecht_ansicht.dart';

/// Startet oder öffnet die erhaltene Sitzung ohne die Kampfverwaltung zu ersetzen.
class GefechtEinstieg extends ConsumerWidget {
  /// Verwendet den vorhandenen Guard vor Dialogen und Navigation.
  const GefechtEinstieg({
    super.key,
    required this.heroId,
    required this.werte,
    required this.bestand,
    required this.aktion,
    required this.vorBearbeitung,
  });
  final String heroId;
  final HeroComputedSnapshot werte;
  final KartoBestandsAdapter bestand;
  final KartoLaufzeitAktion aktion;
  final Future<bool> Function() vorBearbeitung;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final laeuft = ref.watch(gefechtMitInitiativeProvider(heroId)) != null;
    return TextButton(
      key: const ValueKey('gefecht-beginnen'),
      onPressed: () => aktion(() async {
        if (!await vorBearbeitung() || !context.mounted) return;
        final controller = ref.read(gefechtProvider(heroId).notifier);
        if (!laeuft) {
          final c = werte.combatPreviewStats;
          int? wurf = c.initiativeFixedRollTotal;
          if (wurf == null) {
            if (bestand is! KartoGefechtsAdapter) {
              throw StateError('Gefechtsbrücke fehlt.');
            }
            final probe = await (bestand as KartoGefechtsAdapter).gefechtsProbe(
              context: context,
              ref: ref,
              heroId: heroId,
              request: ResolvedProbeRequest(
                type: ProbeType.initiative,
                title: 'Gefecht beginnen · Initiative',
                subtitle: c.initiativeDiceSpec.label,
                ruleHint: 'INI-Wurf einmalig würfeln oder manuell eingeben.',
                diceSpec: c.initiativeDiceSpec,
                targets: const [],
              ),
            );
            if (probe == null || !context.mounted) return;
            wurf = probe.total;
          }
          controller.beginnen(
            wurf,
            dk: gefechtsStartDkFuer(
              werte.hero.combatConfig.selectedWeaponOrNull,
            ),
          );
        }
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GefechtAnsicht(heroId: heroId, bestand: bestand),
          ),
        );
      }),
      child: Text(laeuft ? 'Gefecht läuft' : 'Gefecht beginnen'),
    );
  }
}
