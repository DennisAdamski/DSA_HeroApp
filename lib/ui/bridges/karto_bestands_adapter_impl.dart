import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/ui/bridges/karto_spiel_bruecke.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_catalog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_history_panel.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/settings_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/active_spell_effects_dialog.dart';
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
    return WorkspaceManagementBody(
      heroId: heroId,
      korrekturenGesperrt: korrekturenGesperrt,
      onVerlassenRegistriert: onVerlassenRegistriert,
    );
  }

  /// Baut den vorhandenen Katalog für die aktive Planung.
  @override
  Widget planKatalog(String heroId) => AdvancementCatalog(heroId: heroId);

  /// Baut die vorhandene Vorschau und Historie der aktiven Planung.
  @override
  Widget planHistorie(String heroId) {
    return AdvancementHistoryPanel(heroId: heroId);
  }

  /// Öffnet die vorhandene Heldenliste für Anlegen, Import und Verwaltung.
  @override
  Future<void> heldenVerwalten(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const HeroesHomeScreen()),
    );
  }

  /// Öffnet die vorhandenen Einstellungen im aktuellen ProviderScope.
  @override
  Future<void> einstellungen(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  /// Öffnet die vorhandene Probensuche mit Würfelprotokoll.
  @override
  Future<void> probeSuchen({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
  }) {
    return showProbeQuickSearch(context: context, ref: ref, heroId: heroId);
  }

  /// Öffnet die vorhandene Rastbedienung.
  @override
  Future<void> rast({required BuildContext context, required String heroId}) {
    return showRestDialog(context: context, heroId: heroId);
  }

  /// Öffnet die vorhandene Verwaltung laufender Effekte.
  @override
  Future<void> effekte({
    required BuildContext context,
    required String heroId,
  }) {
    return showActiveSpellEffectsDialog(context: context, heroId: heroId);
  }

  /// Öffnet die vorhandene Ressourcenbedienung des Bestands.
  @override
  Future<void> ressourceBearbeiten({
    required BuildContext context,
    required String heroId,
    required KartoRessource ressource,
  }) {
    return zeigeRessourcenBlatt(
      context: context,
      heroId: heroId,
      ressource: ressource,
    );
  }
}
