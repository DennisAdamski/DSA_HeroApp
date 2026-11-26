import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/alchimika_elixier_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/avatar_rahmung_rules.dart';
import 'package:dsa_heldenverwaltung/state/auth_providers.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_compat_theme.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_spiel_bruecke.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_catalog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_history_panel.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_unterwegs.dart';
import 'package:dsa_heldenverwaltung/ui/screens/auth/open_sign_in.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/artefakt_anwenden.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/elixier_einnehmen_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/vitalwirkung_anwenden_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/auxiliator_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/settings_screen.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_zustand_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_status_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reittier_probe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseroute_rules.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_providers.dart';
import 'package:uuid/uuid.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_begleiter_tab.dart'
    show zeigeVertrautenAktionen;
import 'package:dsa_heldenverwaltung/ui/screens/shared/active_spell_effects_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/begleiter_zustand_aendern.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/spell_instance_aktionen.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_event_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_protection_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_arcane_effects_block.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_attribute_probes.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_combat_probes.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_dice_log_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/hero_regelprofil_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/herleitung_suche_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/probe_quick_search.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/proben_favoriten_liste.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/rules_lookup_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/rest_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/schaden/schaden_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/schaden/schaden_ruecknahme.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_management_body.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/avatar_gallery_image.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_verwaltungs_ziel.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
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
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';

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
    BuildContext context, {
    bool grenzePruefen = false,
    int? grenze,
  }) => showArmatrutzInputDialog(
    context: context,
    grenzePruefen: grenzePruefen,
    grenze: grenze,
  );

  /// Verwendet die vorhandene Attributo-Eingabe ohne frühes Speichern.
  @override
  Future<AttributeModifiers?> gefechtsAttributoWerte(BuildContext context) =>
      showAttributoInputDialog(context: context);

  /// Öffnet den Auslösedialog des Artefakts (Matrixgeber oder Spruchspeicher)
  /// unter dem kompatiblen Theme.
  @override
  Future<void> gefechtsMatrixAusloesen({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required HeroInventoryEntry eintrag,
  }) => _withKartoCompatContext(
    context,
    (themedContext) => zeigeArtefaktAnwenden(
      context: themedContext,
      ref: ref,
      heroId: heroId,
      eintrag: eintrag,
    ),
  );

  /// Öffnet den Anwendungsdialog eines Heiltranks o. Ä. unter dem kompatiblen
  /// Theme; ein Katalogelixier mit Eigenschaftswirkung öffnet stattdessen den
  /// Dialog „Elixier einnehmen“.
  @override
  Future<bool> gefechtsVitalwirkung({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required HeroInventoryEntry eintrag,
  }) async {
    var gebucht = false;
    final elixier = hatElixierWirkung(
      ref.read(heroRulesCatalogProvider(heroId)).valueOrNull,
      eintrag,
    );
    await _withKartoCompatContext(
      context,
      (themedContext) async => gebucht = elixier
          ? await zeigeElixierEinnehmen(
              context: themedContext,
              ref: ref,
              heroId: heroId,
              eintrag: eintrag,
            )
          : await zeigeVitalwirkungAnwenden(
              context: themedContext,
              ref: ref,
              heroId: heroId,
              eintrag: eintrag,
            ),
    );
    return gebucht;
  }

  /// Öffnet den Einsatzdialog des Zaubertalismans unter dem kompatiblen Theme.
  @override
  Future<void> gefechtsAuxiliator({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required HeroInventoryEntry eintrag,
    required String zauberId,
    required int zfpStern,
    required bool gelungen,
    required String repraesentation,
  }) => _withKartoCompatContext(
    context,
    (themedContext) => zeigeAuxiliator(
      context: themedContext,
      ref: ref,
      heroId: heroId,
      eintrag: eintrag,
      zauberId: zauberId,
      zfpStern: zfpStern,
      gelungen: gelungen,
      repraesentation: repraesentation,
      zauberkostenGebucht: true,
    ),
  );

  /// Bedient eine Zauberwirkung mit denselben Eingaben wie der Effektedialog.
  @override
  Future<void> gefechtsWirkung({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required GefechtsWirkungAktion aktion,
    String? instanzId,
  }) => _withKartoCompatContext(context, (themedContext) async {
    final aktionen = SpellInstanceAktionen(
      context: themedContext,
      ref: ref,
      heroId: heroId,
      // Fehler erscheinen im Bereich der Gefechtsansicht, nicht im Dialog.
      aendere: (aenderung) => aendereZustandMitMeldung(
        context: context,
        ref: ref,
        heroId: heroId,
        was: 'Zaubereffekt',
        aenderung: aenderung,
      ),
    );
    final katalog = ref.read(heroRulesCatalogProvider(heroId)).asData?.value;
    switch (aktion) {
      case GefechtsWirkungAktion.zauberHinzufuegen:
        if (katalog != null) await aktionen.zauberwirkungHinzufuegen(katalog);
      case GefechtsWirkungAktion.attributoHinzufuegen:
        await aktionen.attributoQuelleHinzufuegen();
      case GefechtsWirkungAktion.dauer ||
          GefechtsWirkungAktion.einsetzen ||
          GefechtsWirkungAktion.schutzvorrat:
        final zustand = ref.read(heroStateProvider(heroId)).valueOrNull;
        final instanz = zustand?.activeSpellEffects.instanzen
            .where((i) => i.id == instanzId)
            .firstOrNull;
        if (instanz == null) return;
        switch (aktion) {
          case GefechtsWirkungAktion.dauer:
            await aktionen.dauerDerQuelle(instanz);
          case GefechtsWirkungAktion.schutzvorrat:
            await aktionen.schutzRestAnpassen(instanz);
          default:
            if (instanz.effectId == kAengsteLindernZauberId) {
              await aktionen.aengsteEinsetzen(instanz);
            } else if (kSchutzZauberIds.contains(instanz.effectId)) {
              await aktionen.schildAuffangen(instanz);
            }
        }
    }
  });

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
    KartoVerwaltungsZiel? ziel,
  }) {
    return _KartoCompatHost(
      child: WorkspaceManagementBody(
        heroId: heroId,
        korrekturenGesperrt: korrekturenGesperrt,
        onVerlassenRegistriert: onVerlassenRegistriert,
        ziel: ziel,
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
      // Die Stufe der umgebenden Kachel entscheidet, ob ein Wundabzug an der
      // Karte steht (weit) oder nur im Tooltip.
      child: Builder(
        builder: (context) => InspectorAttributeProbes(
          heroId: heroId,
          probenEigenschaften: werte.probenEigenschaften,
          grundwerte: werte.effectiveAttributes,
          kompakt: true,
          abzugZeigen: KartoKachelSteuerung.istWeit(context),
        ),
      ),
    );
  }

  /// Mindestbreite einer Spalte der häufigen Proben in einer weiten Kachel.
  static const double kFavoritenSpaltenbreite = 260;

  /// Baut die häufigen Proben des Helden, in einer weiten Kachel in Spalten.
  @override
  Widget spielFavoritenproben({required String heroId}) {
    return _KartoCompatHost(
      // In einer weiten Kachel stehen die Proben nebeneinander.
      child: Builder(
        builder: (context) => ProbenFavoritenListe(
          heroId: heroId,
          spaltenbreite: KartoKachelSteuerung.istWeit(context)
              ? KartoBestandsAdapterImpl.kFavoritenSpaltenbreite
              : null,
        ),
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

  /// Baut das vorhandene Würfelprotokoll mit den Einträgen des Zustands, in
  /// einer weiten Kachel mit Grenze als Tabelle.
  @override
  Widget spielProtokoll(
    HeroComputedSnapshot werte, {
    int? hoechstens,
  }) => _KartoCompatHost(
    child: Consumer(
      builder: (context, ref, _) => InspectorDiceLogSection(
        entries: werte.state.diceLog,
        hoechstens: hoechstens,
        // Die weite Kachel zeigt die Würfe als Tabelle; nur mit Grenze, denn
        // das ganze Protokoll samt Filtern steht im Blatt.
        tabellarisch:
            hoechstens != null && KartoKachelSteuerung.istWeit(context),
        aktion: (eintrag) => schadenRuecknahmeAktion(
          eintrag: eintrag,
          heroId: werte.hero.id,
          zustand: werte.state,
        ),
        // „Nochmal würfeln“ öffnet den normalen Probendialog derselben Probe
        // über die Probensuche (SPIEL-05).
        onWiederholen: (eintrag) => wiederholeProbeMitHinweis(
          context: context,
          ref: ref,
          heroId: werte.hero.id,
          entry: eintrag,
        ),
      ),
    ),
  );

  /// Baut Belastung, Wunden und Statuswerte des Bestands.
  @override
  Widget spielZustand({
    required String heroId,
    required HeroComputedSnapshot werte,
    bool mitBelastung = true,
  }) {
    return _KartoCompatHost(
      child: KartoZustandsblock(
        heroId: heroId,
        werte: werte,
        mitBelastung: mitBelastung,
      ),
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

  /// Öffnet die durchsuchbaren Berechnungsschritte des Bestands.
  @override
  Future<void> berechnungsschritte({
    required BuildContext context,
    required String heroId,
  }) {
    return _withKartoCompatContext(
      context,
      (themedContext) =>
          showHerleitungsSuche(context: themedContext, heroId: heroId),
    );
  }

  /// Öffnet die Regelprofil-Karte der Übersicht in einem Dialog.
  @override
  Future<void> regelprofil({
    required BuildContext context,
    required String heroId,
  }) {
    return _withKartoCompatContext(
      context,
      (themedContext) => showDialog<void>(
        context: themedContext,
        builder: (dialogContext) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: HeroRegelprofilSection(heroId: heroId),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextButton(
                      key: const ValueKey<String>(
                        'karto-regelprofil-schliessen',
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Schließen'),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        mitFavoriten: true,
      ),
    );
  }

  /// Wiederholt die Probe eines Protokolleintrags im normalen Probendialog.
  @override
  Future<void> probeWiederholen({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required DiceLogEntry eintrag,
  }) {
    return _withKartoCompatContext(
      context,
      (themedContext) => wiederholeProbeMitHinweis(
        context: themedContext,
        ref: ref,
        heroId: heroId,
        entry: eintrag,
      ),
    );
  }

  /// Der Regelwerk-Index läuft nur auf Desktop und im Web.
  @override
  bool get regelnNachschlagenVerfuegbar => isRulesLookupSupported();

  /// Öffnet den vorhandenen Regelnachschlag (Volltextsuche in den Regelwerken).
  @override
  Future<void> regelnNachschlagen({required BuildContext context}) {
    return _withKartoCompatContext(
      context,
      (themedContext) => showRulesLookupDialog(context: themedContext),
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

  /// Verschiebt die Ressource über den gemeinsamen Zustandsweg des Blatts.
  @override
  Future<void> ressourceSchritt({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required KartoRessource ressource,
    required int schritt,
  }) {
    return schreibeRessourcenSchritt(
      context: context,
      ref: ref,
      heroId: heroId,
      ressource: ressource,
      schritt: schritt,
    );
  }

  /// Schreibt den Wundzähler über den gemeinsamen Zustandsweg.
  @override
  Future<void> begleiterWundenAendern({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required String begleiterId,
    required int schritt,
  }) async {
    await aendereBegleiterWunden(
      context: context,
      ref: ref,
      heroId: heroId,
      begleiterId: begleiterId,
      schritt: schritt,
    );
  }

  /// Würfelt die Reittierprobe über den Probendialog und das Würfelprotokoll.
  ///
  /// Reiten trägt den Stufenmodifikator des Reittiers, LO die wirksame
  /// Loyalität; gebucht wird nichts.
  @override
  Future<void> reittierProbe({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required String begleiterId,
    required ReittierProbeArt art,
  }) async {
    final held = ref.read(heroByIdProvider(heroId));
    final begleiter = held?.companions
        .where((c) => c.id == begleiterId)
        .firstOrNull;
    if (held == null || begleiter == null) return;
    ResolvedProbeRequest? request;
    String? hinweis;
    if (art == ReittierProbeArt.loyalitaet) {
      request = begleiterLoyalitaetsProbe(begleiter);
    } else {
      final snapshot = ref.read(heroComputedProvider(heroId)).valueOrNull;
      final katalog = ref.read(heroRulesCatalogProvider(heroId)).valueOrNull;
      if (snapshot == null || katalog == null) {
        hinweis = 'Heldenwerte werden noch geladen.';
      } else {
        final aufbau = reittierReitenProbe(
          snapshot: snapshot,
          talente: katalog.talents,
          reittier: begleiter,
          imKampf: art == ReittierProbeArt.reitenImKampf,
          reiterIstZauberer: detectMagicStatus(held, katalog) != null,
          epicAdvantagesActive: ref.read(
            heroEpicAdvantagesActiveProvider(heroId),
          ),
        );
        request = aufbau.request;
        hinweis = aufbau.hinweis;
      }
    }
    if (request == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(hinweis ?? 'Die Probe ist nicht möglich.')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    await gefechtsProbe(
      context: context,
      ref: ref,
      heroId: heroId,
      request: request,
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

  /// Schreibt den Standort über den gemeinsamen Zustandsweg.
  @override
  Future<void> standortSetzen({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required String standort,
    String ortId = '',
    double? kartenX,
    double? kartenY,
  }) async {
    // Alles Kontextgebundene vor dem Warten greifen: Der Dialog ist danach zu.
    final bote = ScaffoldMessenger.maybeOf(context);
    final orte = ref.read(ortsverzeichnisProvider);
    final neu = bereinigeStandort(standort);
    // Alter Standort und Verweis stammen aus dem frisch geladenen Zustand,
    // nicht aus dem Stand beim Rendern.
    String? alterStandort;
    var alteOrtId = '';
    var neueOrtId = '';
    final gespeichert = await aendereZustandMitMeldung(
      context: context,
      ref: ref,
      heroId: heroId,
      was: 'Standort',
      aenderung: (aktuell) {
        alterStandort = aktuell.standort;
        alteOrtId = aktuell.standortOrtId;
        neueOrtId = standortOrtIdNachWechsel(
          alterStandort: aktuell.standort,
          alteOrtId: aktuell.standortOrtId,
          neuerStandort: neu,
          gewaehlteOrtId: ortId,
          orte: orte,
        );
        return aktuell.copyWith(standort: neu, standortOrtId: neueOrtId);
      },
    );
    if (gespeichert == null || alterStandort == null) return;
    // Die Station trägt denselben Ort wie der Standort: aus dem Verzeichnis,
    // sonst (etwa ein Treffer der Online-Suche) mit der Position der Wahl.
    final verweis = neueOrtId.isEmpty
        ? null
        : orte.where((e) => e.ortId == neueOrtId).firstOrNull ??
              OrtEintrag(
                name: neu,
                art: OrtArt.siedlung,
                ortId: neueOrtId,
                kartenX: neueOrtId == ortId ? kartenX : null,
                kartenY: neueOrtId == ortId ? kartenY : null,
              );
    await _haltStandortwechselFest(
      ref: ref,
      bote: bote,
      heroId: heroId,
      alterStandort: alterStandort!,
      alteOrtId: alteOrtId,
      neuerStandort: standort,
      orte: orte,
      gewaehlt: verweis,
    );
  }

  /// Schreibt Reise und Standort in einem Zustandsdokument.
  @override
  Future<bool> reiseZustandSetzen({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required HeroUnterwegs? unterwegs,
    String? standort,
    String standortOrtId = '',
  }) async {
    final gespeichert = await aendereZustandMitMeldung(
      context: context,
      ref: ref,
      heroId: heroId,
      was: 'Reise',
      aenderung: (aktuell) => aktuell.copyWith(
        unterwegs: unterwegs,
        standort: standort == null ? null : bereinigeStandort(standort),
        // Ein neuer Standort bringt seinen Verweis mit (oder keinen).
        standortOrtId: standort == null || bereinigeStandort(standort).isEmpty
            ? null
            : standortOrtId,
      ),
    );
    return gespeichert != null;
  }

  /// Hält einen Ortswechsel als Station der Reiseroute fest.
  ///
  /// Zweiter, eigenständiger Schreibvorgang am Heldenbogen nach dem
  /// Standort-Schreiben am Zustand (je Schritt ein Dokument). Er ist
  /// wiederholbar: Die Regel legt für denselben Ort keine zweite Station an.
  /// Scheitert er (etwa während einer Planung), bleibt der Standort gespeichert
  /// und eine Meldung nennt den Grund.
  Future<void> _haltStandortwechselFest({
    required WidgetRef ref,
    required ScaffoldMessengerState? bote,
    required String heroId,
    required String alterStandort,
    required String neuerStandort,
    required List<OrtEintrag> orte,
    String alteOrtId = '',
    OrtEintrag? gewaehlt,
  }) async {
    if (bereinigeStandort(neuerStandort).isEmpty) return;
    try {
      await aendereHeldImEditor(
        ref: ref,
        heroId: heroId,
        aenderung: (held) =>
            reiseStationFuerStandortwechsel(
              held: held,
              alterStandort: alterStandort,
              neuerStandort: neuerStandort,
              id: const Uuid().v4(),
              jetzt: DateTime.now(),
              orte: orte,
              gewaehlt: gewaehlt,
              alteOrtId: alteOrtId,
            ) ??
            held,
      );
    } on Object catch (fehler) {
      final grund = fehler is StateError ? fehler.message : '$fehler';
      bote?.showSnackBar(
        SnackBar(
          content: Text(
            'Standort gespeichert, Reiseroute nicht ergänzt: $grund',
          ),
        ),
      );
    }
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
