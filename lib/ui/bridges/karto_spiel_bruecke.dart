/// Bestandsbausteine des Spielbereichs, getrennt vom übrigen Adapter.
///
/// Die Spec sieht diese Aufteilung der Brückenschicht ausdrücklich vor: der
/// Spielbereich bringt mehrere Bausteine mit, die sonst
/// `karto_bestands_adapter_impl.dart` aufblähen würden.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_belastung_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_statuswerte_block.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_vital_block.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector_wunden_card.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';

/// Öffnet die vorhandene Ressourcenbedienung als aufgelegtes Blatt.
///
/// Bewusst der `InspectorVitalBlock` und nicht `showResourceStepperDialog`:
/// nur er kennt ±5/±1, Zurücksetzen auf das Maximum, Überheilung und die
/// Untergrenze [kVitalFloor]. Der Stepper klemmt hart auf `0..max` und könnte
/// negative Lebenspunkte gar nicht erzeugen.
Future<void> zeigeRessourcenBlatt({
  required BuildContext context,
  required String heroId,
  required KartoRessource ressource,
}) {
  return showAdaptiveDetailSheet<void>(
    context: context,
    builder: (_) => _RessourcenBlatt(heroId: heroId, ressource: ressource),
  );
}

// Liest den gemeinsamen Snapshot und speichert über den vorhandenen Schreibweg.
class _RessourcenBlatt extends ConsumerWidget {
  const _RessourcenBlatt({required this.heroId, required this.ressource});

  final String heroId;
  final KartoRessource ressource;

  String get _kurz => switch (ressource) {
    KartoRessource.lebensenergie => 'LeP',
    KartoRessource.ausdauer => 'AuP',
    KartoRessource.astralenergie => 'AsP',
    KartoRessource.karma => 'KaP',
  };

  String get _lang => switch (ressource) {
    KartoRessource.lebensenergie => 'Lebenspunkte',
    KartoRessource.ausdauer => 'Ausdauer',
    KartoRessource.astralenergie => 'Astralpunkte',
    KartoRessource.karma => 'Karmapunkte',
  };

  VitalKind get _art => switch (ressource) {
    KartoRessource.lebensenergie => VitalKind.lep,
    KartoRessource.ausdauer => VitalKind.aup,
    KartoRessource.astralenergie => VitalKind.asp,
    KartoRessource.karma => VitalKind.kap,
  };

  int _aktuell(HeroState state) => switch (ressource) {
    KartoRessource.lebensenergie => state.currentLep,
    KartoRessource.ausdauer => state.currentAu,
    KartoRessource.astralenergie => state.currentAsp,
    KartoRessource.karma => state.currentKap,
  };

  HeroState _mitWert(HeroState state, int wert) => switch (ressource) {
    KartoRessource.lebensenergie => state.copyWith(currentLep: wert),
    KartoRessource.ausdauer => state.copyWith(currentAu: wert),
    KartoRessource.astralenergie => state.copyWith(currentAsp: wert),
    KartoRessource.karma => state.copyWith(currentKap: wert),
  };

  // Ein fehlgeschlagener Write darf nie als stille Uebernahme erscheinen.
  Future<void> _speichere(
    BuildContext context,
    WidgetRef ref,
    HeroState state,
    int wert,
  ) async {
    final bote = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(heroActionsProvider)
          .saveHeroState(heroId, _mitWert(state, wert));
    } catch (fehler) {
      bote.showSnackBar(
        SnackBar(content: Text('$_kurz nicht gespeichert: $fehler')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final werte = ref.watch(heroComputedProvider(heroId)).valueOrNull;
    final state = werte?.state;
    final derived = werte?.derivedStats;
    final maximum = switch (ressource) {
      KartoRessource.lebensenergie => derived?.maxLep ?? 0,
      KartoRessource.ausdauer => derived?.maxAu ?? 0,
      KartoRessource.astralenergie => derived?.maxAsp ?? 0,
      KartoRessource.karma => derived?.maxKap ?? 0,
    };

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kDialogWidthSmall),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$_lang anpassen',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (state == null)
                const Center(child: CircularProgressIndicator())
              else
                InspectorVitalBlock(
                  label: _kurz,
                  subtitle: _lang,
                  current: _aktuell(state),
                  max: maximum,
                  kind: _art,
                  onChanged: (naechster) =>
                      _speichere(context, ref, state, naechster),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey<String>('karto-ressource-schliessen'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Schließen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baut Belastung, Wunden und Statuswerte als einen Block.
///
/// Fasst genau die Teile des Vitals-Tabs zusammen, die nicht Ressourcen sind.
/// Die Bausteine bleiben die vorhandenen: Wunden bringen ihren eigenen
/// Detaildialog mit, Belastung ihren eigenen Schreibweg.
class KartoZustandsblock extends StatelessWidget {
  /// Erstellt den Zustandsblock aus dem bereits gelesenen Snapshot.
  const KartoZustandsblock({
    super.key,
    required this.heroId,
    required this.werte,
  });

  /// ID im gemeinsam genutzten Heldenspeicher.
  final String heroId;

  /// Gemeinsamer Snapshot des Spielbereichs.
  final HeroComputedSnapshot werte;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorBelastungSection(heroId: heroId, heroState: werte.state),
        const SizedBox(height: 14),
        InspectorWundenSection(
          heroId: heroId,
          heroState: werte.state,
          wundEffekte: werte.wundEffekte,
          wundschwelle: werte.wundschwelle,
        ),
        const SizedBox(height: 14),
        InspectorStatuswerteBlock(
          heroId: heroId,
          hero: werte.hero,
          derived: werte.derivedStats,
          combat: werte.combatPreviewStats,
        ),
      ],
    );
  }
}
