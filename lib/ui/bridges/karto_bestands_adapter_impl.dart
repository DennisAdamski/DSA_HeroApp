import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/ui/bridges/karto_compat_theme.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_spiel_bruecke.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_catalog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_history_panel.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/settings_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/active_spell_effects_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_arcane_effects_block.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_attribute_probes.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_combat_probes.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_dice_log_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/probe_quick_search.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/rest_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_management_body.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';

/// Bindet den neuen Rahmen an die vorhandenen, fachlich vollständigen Ansichten.
class KartoBestandsAdapterImpl implements KartoBestandsAdapter {
  /// Erstellt die vorübergehende Brücke ohne eigenes Repository.
  const KartoBestandsAdapterImpl();

  /// Baut die gemeinsame Verwaltungsfläche und reicht den Leave-Guard weiter.
  @override
  Widget verwaltung({
    required String heroId,
    required bool korrekturenGesperrt,
    required ValueChanged<KartoVerlassenPruefung?> onVerlassenRegistriert,
  }) {
    return _KartoCompatHost(
      child: WorkspaceManagementBody(
        heroId: heroId,
        korrekturenGesperrt: korrekturenGesperrt,
        onVerlassenRegistriert: onVerlassenRegistriert,
      ),
    );
  }

  /// Baut den vorhandenen Katalog für die aktive Planung.
  @override
  Widget planKatalog(String heroId) {
    return _KartoCompatHost(child: AdvancementCatalog(heroId: heroId));
  }

  /// Baut die vorhandene Vorschau und Historie der aktiven Planung.
  @override
  Widget planHistorie(String heroId) {
    return _KartoCompatHost(child: AdvancementHistoryPanel(heroId: heroId));
  }

  /// Baut die vorhandenen Eigenschafts-Schnellproben.
  @override
  Widget spielEigenschaftsproben({
    required String heroId,
    required HeroComputedSnapshot werte,
  }) {
    return _KartoCompatHost(
      child: InspectorAttributeProbes(
        heroId: heroId,
        effectiveAttributes: werte.effectiveAttributes,
      ),
    );
  }

  /// Baut die vorhandenen Kampf-Schnellproben.
  @override
  Widget spielKampfproben({
    required String heroId,
    required HeroComputedSnapshot werte,
  }) {
    return _KartoCompatHost(
      child: InspectorCombatProbes(
        heroId: heroId,
        combat: werte.combatPreviewStats,
      ),
    );
  }

  /// Baut die vorhandene Effektanzeige ohne eigene Schaltfläche.
  @override
  Widget spielEffekte({
    required String heroId,
    required HeroComputedSnapshot werte,
  }) {
    return _KartoCompatHost(
      child: InspectorArcaneEffectsView(
        sheet: werte.hero,
        state: werte.state,
        combat: werte.combatPreviewStats,
      ),
    );
  }

  /// Baut das vorhandene Würfelprotokoll mit den Einträgen des Zustands.
  @override
  Widget spielProtokoll(HeroComputedSnapshot werte) => _KartoCompatHost(
    child: InspectorDiceLogSection(entries: werte.state.diceLog),
  );

  /// Baut Belastung, Wunden und Statuswerte des Bestands.
  @override
  Widget spielZustand({
    required String heroId,
    required HeroComputedSnapshot werte,
  }) {
    return _KartoCompatHost(
      child: KartoZustandsblock(heroId: heroId, werte: werte),
    );
  }

  /// Öffnet die vorhandene Heldenliste für Anlegen, Import und Verwaltung.
  @override
  Future<void> heldenVerwalten(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const _KartoCompatHost(child: HeroesHomeScreen()),
      ),
    );
  }

  /// Öffnet die vorhandenen Einstellungen im aktuellen ProviderScope.
  @override
  Future<void> einstellungen(
    BuildContext context, {
    KartoVerlassenPruefung? vorOberflaechenwechsel,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _KartoCompatHost(
          child: SettingsScreen(beforeSurfaceChange: vorOberflaechenwechsel),
        ),
      ),
    );
  }

  /// Öffnet die vorhandene Probensuche mit Würfelprotokoll.
  @override
  Future<void> probeSuchen({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
  }) {
    return _withKartoCompatContext(
      context,
      (themedContext) => showProbeQuickSearch(
        context: themedContext,
        ref: ref,
        heroId: heroId,
      ),
    );
  }

  /// Öffnet die vorhandene Rastbedienung.
  @override
  Future<void> rast({required BuildContext context, required String heroId}) {
    return _withKartoCompatContext(
      context,
      (themedContext) => showRestDialog(context: themedContext, heroId: heroId),
    );
  }

  /// Öffnet die vorhandene Verwaltung laufender Effekte.
  @override
  Future<void> effekte({
    required BuildContext context,
    required String heroId,
  }) {
    return _withKartoCompatContext(
      context,
      (themedContext) =>
          showActiveSpellEffectsDialog(context: themedContext, heroId: heroId),
    );
  }

  /// Öffnet die vorhandene Ressourcenbedienung des Bestands.
  @override
  Future<void> ressourceBearbeiten({
    required BuildContext context,
    required String heroId,
    required KartoRessource ressource,
  }) {
    return _withKartoCompatContext(
      context,
      (themedContext) => zeigeRessourcenBlatt(
        context: themedContext,
        heroId: heroId,
        ressource: ressource,
      ),
    );
  }
}

class _KartoCompatHost extends StatelessWidget {
  const _KartoCompatHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(data: buildKartoCompatTheme(Theme.of(context)), child: child);
  }
}

// Stellt Dialogaufrufen einen echten BuildContext unter dem Compat-Theme bereit,
// damit auch ihre nachgelagerten Dialoge dieselben geerbten Tokens erfassen.
Future<void> _withKartoCompatContext(
  BuildContext context,
  Future<void> Function(BuildContext themedContext) open,
) async {
  final overlay = Overlay.of(context);
  final theme = buildKartoCompatTheme(Theme.of(context));
  final completion = Completer<void>();
  late final OverlayEntry entry;
  var started = false;
  entry = OverlayEntry(
    builder: (_) => Theme(
      data: theme,
      child: Builder(
        builder: (themedContext) {
          if (!started) {
            started = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                await open(themedContext);
                completion.complete();
              } catch (error, stackTrace) {
                completion.completeError(error, stackTrace);
              } finally {
                if (entry.mounted) {
                  entry.remove();
                }
              }
            });
          }
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  overlay.insert(entry);
  await completion.future;
}
