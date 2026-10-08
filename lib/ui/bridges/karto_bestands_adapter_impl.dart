import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/rules/derived/avatar_rahmung_rules.dart';
import 'package:dsa_heldenverwaltung/state/auth_providers.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_compat_theme.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_spiel_bruecke.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_catalog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_history_panel.dart';
import 'package:dsa_heldenverwaltung/ui/screens/auth/open_sign_in.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/settings_screen.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_zustand_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_begleiter_tab.dart'
    show zeigeVertrautenAktionen;
import 'package:dsa_heldenverwaltung/ui/screens/shared/active_spell_effects_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/begleiter_zustand_aendern.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_arcane_effects_block.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_attribute_probes.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_combat_probes.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_dice_log_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/probe_quick_search.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/rest_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/schaden/schaden_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/schaden/schaden_ruecknahme.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_management_body.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/avatar_gallery_image.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampf_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/armatrutz_input_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/attributo_input_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/resource_stepper_dialog.dart';
import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

import 'karto_gefechts_bruecke.dart';

/// Bindet den neuen Rahmen an die vorhandenen, fachlich vollständigen Ansichten.
class KartoBestandsAdapterImpl
    implements KartoBestandsAdapter, KartoGefechtsAdapter {
  /// Erstellt die vorübergehende Brücke ohne eigenes Repository.
  const KartoBestandsAdapterImpl();

  /// Verwendet einmalige Probeauswertung unter dem kompatiblen Dialogtheme.
  @override
  Future<ProbeResult?> gefechtsProbe({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required ResolvedProbeRequest request,
    void Function(ProbeResult)? onResolved,
  }) async {
    ProbeResult? result;
    await _withKartoCompatContext(context, (themedContext) async {
      result = await zeigeGefechtsprobe(
        context: themedContext,
        ref: ref,
        heroId: heroId,
        request: request,
        onResolved: onResolved,
      );
    });
    return result;
  }

  /// Erhält fremde Daten und vorhandene Speicher-/Konfliktprüfungen.
  @override
  Future<bool> gefechtsAusruestung({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required CombatConfig Function(CombatConfig) aenderung,
  }) async {
    final held = await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: heroId,
      was: 'Gefechtsausrüstung',
      aenderung: (held) => mitKampfAenderung(held, aenderung),
    );
    return held != null;
  }

  /// Schreibt frisch über den gemeinsamen Zustandsweg der Bedienelemente.
  @override
  Future<HeroState?> gefechtsZustand({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required String was,
    required HeroState Function(HeroState aktuell) aenderung,
  }) => aendereZustandMitMeldung(
    context: context,
    ref: ref,
    heroId: heroId,
    was: was,
    aenderung: aenderung,
  );

  /// Legt den Fehlerbereich des Zustandswegs um den Inhalt.
  @override
  Widget gefechtsFehlerBereich({
    required Widget Function(Widget fehleranzeige) builder,
  }) => ZustandFehlerBereich(child: builder(const ZustandFehlerAnzeige()));

  /// Verwendet die vorhandene Armatrutz-Eingabe ohne frühes Speichern.
  @override
  Future<ActiveSpellEffectDetail?> gefechtsArmatrutzWerte(
    BuildContext context,
  ) => showArmatrutzInputDialog(context: context);

  /// Verwendet die vorhandene Attributo-Eingabe ohne frühes Speichern.
  @override
  Future<AttributeModifiers?> gefechtsAttributoWerte(BuildContext context) =>
      showAttributoInputDialog(context: context);

  /// Öffnet den vorhandenen Ressourcendialog mit Abschlusskosten.
  @override
  Future<void> gefechtsWirkkosten({
    required BuildContext context,
    required String heroId,
    required bool karmal,
    required int? kosten,
    required Future<bool> Function(BuildContext blatt) onUebernehmen,
  }) => showResourceStepperDialog(
    context: context,
    heroId: heroId,
    resource: karmal ? ResourceType.kap : ResourceType.asp,
    abschlussKosten: kosten,
    onAbschlussUebernehmen: onUebernehmen,
  );

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
    // Die AP-Bilanz steht in der neuen Oberflaeche schon ueber dem Katalog.
    return _KartoCompatHost(
      child: AdvancementHistoryPanel(heroId: heroId, zeigeApZeilen: false),
    );
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
        probenEigenschaften: werte.probenEigenschaften,
        grundwerte: werte.effectiveAttributes,
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
    child: InspectorDiceLogSection(
      entries: werte.state.diceLog,
      aktion: (eintrag) => schadenRuecknahmeAktion(
        eintrag: eintrag,
        heroId: werte.hero.id,
        zustand: werte.state,
      ),
    ),
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
  ///
  /// "Held öffnen" wählt den Helden für den Kartograph-Workspace und schließt
  /// die Liste, statt den klassischen Arbeitsbereich darüberzulegen. Die
  /// Einstellungen laufen über denselben Weg wie aus der Heldenwahl. Offene
  /// Planungen sind hier bereits geprüft: der Workspace verlässt sich vor
  /// diesem Aufruf über seine Leave-Prüfung.
  @override
  Future<void> heldenVerwalten(BuildContext context) {
    final container = ProviderScope.containerOf(context, listen: false);
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) => _KartoCompatHost(
          child: HeroesHomeScreen(
            onHeldOeffnen: (heroId) async {
              await container
                  .read(selectedHeroSelectionActionsProvider)
                  .selectHero(heroId);
              if (routeContext.mounted) Navigator.of(routeContext).pop();
            },
            onEinstellungen: () => einstellungen(routeContext),
          ),
        ),
      ),
    );
  }

  /// Öffnet den vorhandenen Login-Bildschirm im gewünschten Modus.
  @override
  Future<void> anmelden(
    BuildContext context, {
    bool registrieren = false,
  }) async {
    final authService = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(authServiceProvider);
    if (authService == null) return;
    await openSignInScreen(context, authService, register: registrieren);
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

  /// Öffnet den geführten Ablauf „Schaden erhalten“.
  @override
  Future<void> schadenErhalten({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
  }) {
    return _withKartoCompatContext(
      context,
      (themedContext) =>
          showSchadenDialog(context: themedContext, ref: ref, heroId: heroId),
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

  /// Schreibt den laufenden Wert über den gemeinsamen Zustandsweg.
  @override
  Future<void> begleiterWertAendern({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required String begleiterId,
    required BegleiterPool pool,
    required RessourcenAenderung aenderung,
  }) async {
    final begleiter = ref
        .read(heroByIdProvider(heroId))
        ?.companions
        .where((c) => c.id == begleiterId)
        .firstOrNull;
    if (begleiter == null) return;
    await aendereBegleiterPool(
      context: context,
      ref: ref,
      heroId: heroId,
      begleiter: begleiter,
      pool: pool,
      aenderung: aenderung,
    );
  }

  /// Öffnet die vorhandenen Vertrautenaktionen des Begleiter-Tabs.
  @override
  Future<void> vertrautenAktionen({
    required BuildContext context,
    required String heroId,
    required String begleiterId,
  }) {
    return _withKartoCompatContext(
      context,
      (themedContext) => zeigeVertrautenAktionen(
        context: themedContext,
        heroId: heroId,
        begleiterId: begleiterId,
      ),
    );
  }

  @override
  Widget heldenbild({
    required String heroId,
    required String dateiname,
    required double groesse,
    required Widget ersatz,
  }) {
    return SizedBox(
      width: groesse,
      height: groesse,
      child: AvatarGalleryImage(
        heroId: heroId,
        fileName: dateiname,
        placeholder: ersatz,
        rahmung: AvatarRahmung.portraet,
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
