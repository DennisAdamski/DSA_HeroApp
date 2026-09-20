import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/debug/karto_token_sheet.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_breakpoints.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_arbeitsbereich.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_modus_navigation.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

part 'karto_workspace_navigation.dart';

/// Gemeinsamer adaptiver Host für Spielen, Verwaltung und Entwicklung.
class KartoWorkspace extends ConsumerStatefulWidget {
  /// Bindet den Host an genau einen Helden und die injizierte Bestandsbrücke.
  const KartoWorkspace({
    super.key,
    required this.heroId,
    required this.bestand,
  });

  /// ID im gemeinsam genutzten Heldenspeicher.
  final String heroId;

  /// Fachansichten bleiben während R1 über diese begrenzte Brücke erreichbar.
  final KartoBestandsAdapter bestand;

  /// Erstellt ausschließlich flüchtigen Navigationszustand.
  @override
  ConsumerState<KartoWorkspace> createState() => _KartoWorkspaceState();
}

class _KartoWorkspaceState extends ConsumerState<KartoWorkspace> {
  KartoArbeitsbereich _bereich = KartoArbeitsbereich.spielen;
  KartoVerlassenPruefung? _verwaltungVerlassen;
  bool _verwaltungBesucht = false;
  bool _navigiert = false;
  bool _planStartVorgemerkt = false;

  // Hält Flutter-State-Änderungen im State statt in der Navigationserweiterung.
  void _setBereich(KartoArbeitsbereich ziel) {
    setState(() {
      _bereich = ziel;
      _verwaltungBesucht |= ziel == KartoArbeitsbereich.verwalten;
    });
  }

  // Registrierung verändert keinen Renderzustand; auch Dispose ist erlaubt.
  void _registriereVerlassen(KartoVerlassenPruefung? pruefung) {
    _verwaltungVerlassen = pruefung;
  }

  // Start erst nach geladenem Katalog und außerhalb des Widget-Builds.
  void _planeSitzungsstart() {
    if (_planStartVorgemerkt) return;
    _planStartVorgemerkt = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _planStartVorgemerkt = false;
      if (!mounted || _bereich != KartoArbeitsbereich.entwickeln) return;
      final provider = advancementSessionProvider(widget.heroId);
      if (ref.read(provider) != null) return;
      final computed = ref
          .read(heroComputedProvider(widget.heroId))
          .asData
          ?.value;
      final catalog = ref.read(rulesCatalogProvider);
      if (computed == null || catalog.hasError || !catalog.hasValue) return;
      ref
          .read(provider.notifier)
          .start(hero: computed.hero, catalog: catalog.requireValue);
    });
  }

  @override
  Widget build(BuildContext context) {
    final computed = ref.watch(heroComputedProvider(widget.heroId));
    final session = ref.watch(advancementSessionProvider(widget.heroId));
    final catalog = ref.watch(rulesCatalogProvider);
    final hero = computed.asData?.value.hero;
    if (_bereich == KartoArbeitsbereich.entwickeln &&
        session == null &&
        !catalog.hasError &&
        catalog.hasValue &&
        hero != null) {
      _planeSitzungsstart();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _zurHeldenwahl();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final breite = kartoBreiteFuer(constraints.maxWidth);
          final schmal = breite == KartoBreite.schmal;
          final navigation = KartoModusNavigation(
            bereich: _bereich,
            kompakt: schmal,
            onAuswahl: _wechsleBereich,
          );
          Widget inhalt;
          if (computed.hasError) {
            inhalt = _meldung(
              'Held konnte nicht geladen werden: ${computed.error}',
              wiederholen: () {
                ref.invalidate(heroListProvider);
                ref.invalidate(heroIndexProvider);
                ref.invalidate(heroStateProvider(widget.heroId));
              },
            );
          } else if (hero == null) {
            inhalt = const Center(child: CircularProgressIndicator());
          } else {
            inhalt = IndexedStack(
              index: _bereich.index,
              children: [
                _mitProbenkuerzel(_spielen()),
                _verwaltungBesucht
                    ? _verwaltung(session != null)
                    : const SizedBox.shrink(),
                _planung(breite, session),
              ],
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(
                hero?.name ?? 'Held',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              leading: IconButton(
                tooltip: 'Heldenauswahl',
                onPressed: _zurHeldenwahl,
                icon: const Icon(Icons.arrow_back),
              ),
              actions: [
                PopupMenuButton<String>(
                  tooltip: 'Workspace-Menü',
                  onSelected: _menueAktion,
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'helden',
                      child: Text('Helden verwalten'),
                    ),
                    const PopupMenuItem(
                      value: 'einstellungen',
                      child: Text('Einstellungen'),
                    ),
                    const PopupMenuItem(
                      value: 'bestand',
                      child: Text('Zur bestehenden Oberfläche'),
                    ),
                    if (ref.read(debugModusProvider))
                      const PopupMenuItem(
                        value: 'token',
                        child: Text('Token-Blatt'),
                      ),
                  ],
                ),
              ],
            ),
            bottomNavigationBar: schmal
                ? Material(
                    color: context.karto.navigation,
                    child: SafeArea(
                      top: false,
                      child: IntrinsicHeight(child: navigation),
                    ),
                  )
                : null,
            body: schmal
                ? inhalt
                : Row(
                    // Ohne stretch bekommt die Leiste nur die Hoehe ihrer drei
                    // Ziele und saesse als dunkler Block mitten im Hellen.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: breite.hatDreiSpalten ? 232 : 184,
                        child: ColoredBox(
                          color: context.karto.navigation,
                          child: SingleChildScrollView(child: navigation),
                        ),
                      ),
                      Expanded(child: inhalt),
                    ],
                  ),
          );
        },
      ),
    );
  }

  // Strg/Cmd+K gilt nur im Spielen-Bereich und verschwindet mit dem
  // Workspace. Der IndexedStack haelt die anderen Bereiche am Leben, deshalb
  // entscheidet der aktive Bereich und nicht allein die Position im Baum.
  Widget _mitProbenkuerzel(Widget kind) {
    if (_bereich != KartoArbeitsbereich.spielen) return kind;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _probeSuchen,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _probeSuchen,
      },
      child: Focus(autofocus: true, child: kind),
    );
  }

  // Derselbe Weg wie die Schaltfläche: geschützt und über den Bestand.
  void _probeSuchen() {
    _laufzeitAktion(
      () => widget.bestand.probeSuchen(
        context: context,
        ref: ref,
        heroId: widget.heroId,
      ),
    );
  }

  // Die Spielanordnung liegt vollständig in ui2/spielen und liest den
  // gemeinsamen Snapshot selbst; der Workspace reicht nur seinen Guard herein.
  Widget _spielen() => KartoSpielansicht(
    heroId: widget.heroId,
    bestand: widget.bestand,
    aktion: _laufzeitAktion,
  );

  // Während einer Sitzung bleiben sämtliche manuellen Schreibwege gesperrt.
  Widget _verwaltung(bool gesperrt) => Column(
    children: [
      if (gesperrt)
        Padding(
          padding: const EdgeInsets.all(Abstand.normal),
          child: Wrap(
            spacing: Abstand.normal,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Eine Entwicklung ist noch in Planung.'),
              TextButton(
                onPressed: () =>
                    _wechsleBereich(KartoArbeitsbereich.entwickeln),
                child: const Text('Zur Planung'),
              ),
            ],
          ),
        ),
      Expanded(
        child: widget.bestand.verwaltung(
          heroId: widget.heroId,
          korrekturenGesperrt: gesperrt,
          onVerlassenRegistriert: _registriereVerlassen,
        ),
      ),
    ],
  );

  // Die mobile Historie bekommt ein begrenztes Sheet statt verschachtelter Scrolls.
  Widget _planung(KartoBreite breite, AdvancementSession? session) {
    if (_bereich != KartoArbeitsbereich.entwickeln) {
      return const SizedBox.shrink();
    }
    if (session == null) {
      final catalog = ref.watch(rulesCatalogProvider);
      if (catalog.hasError) {
        return _meldung(
          'Regelkatalog konnte nicht geladen werden: ${catalog.error}',
          wiederholen: () => ref.invalidate(rulesCatalogProvider),
          zurueck: () => _wechsleBereich(KartoArbeitsbereich.spielen),
        );
      }
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Center(child: CircularProgressIndicator()),
          TextButton(
            onPressed: () => _wechsleBereich(KartoArbeitsbereich.spielen),
            child: const Text('Zurück zum Spielen'),
          ),
        ],
      );
    }
    final katalog = widget.bestand.planKatalog(widget.heroId);
    final inhalt = breite.hatDetailspalte
        ? Row(
            children: [
              Expanded(child: katalog),
              SizedBox(
                width: breite.hatDreiSpalten ? 320 : 280,
                child: widget.bestand.planHistorie(widget.heroId),
              ),
            ],
          )
        : katalog;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Abstand.normal),
          child: Wrap(
            spacing: Abstand.normal,
            runSpacing: Abstand.knapp,
            children: [
              const Text('Entwurf – wird erst beim Übernehmen gespeichert.'),
              OutlinedButton(
                onPressed: session.isSaving ? null : _verwirfPlan,
                child: const Text('Verwerfen'),
              ),
              FilledButton(
                onPressed: session.canCommit ? _uebernehmePlan : null,
                child: Text(session.isSaving ? 'Speichert …' : 'Übernehmen'),
              ),
              if (!breite.hatDetailspalte)
                TextButton(
                  onPressed: _zeigePlanHistorie,
                  child: const Text('AP und Historie'),
                ),
            ],
          ),
        ),
        Expanded(child: inhalt),
      ],
    );
  }

  // Fehlertexte bleiben auch bei großer Schrift erreichbar.
  Widget _meldung(
    String text, {
    VoidCallback? wiederholen,
    VoidCallback? zurueck,
  }) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(Abstand.bahn),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text),
          if (wiederholen != null)
            TextButton(
              onPressed: wiederholen,
              child: const Text('Wiederholen'),
            ),
          if (zurueck != null)
            TextButton(
              onPressed: zurueck,
              child: const Text('Zurück zum Spielen'),
            ),
        ],
      ),
    ),
  );

  // Die Historie liest denselben Sitzungsprovider wie die Desktopspalte.
  void _zeigePlanHistorie() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: widget.bestand.planHistorie(widget.heroId),
      ),
    );
  }
}
