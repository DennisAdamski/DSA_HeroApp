import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/debug/karto_token_sheet.dart';
import 'package:dsa_heldenverwaltung/ui2/entwicklung/karto_entwicklungsansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_breakpoints.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_arbeitsbereich.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_heldenmarke.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_modus_navigation.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_seitenkopf.dart';
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
            // Identitaet und globale Aktionen fuellen die Spalte nur dort, wo
            // es eine gibt. Schmal traegt sie die AppBar.
            kopf: schmal || hero == null ? null : _navigationsKopf(hero),
            fuss: schmal ? null : _navigationsFuss(),
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
                _planung(session, breite),
              ],
            );
          }
          return Scaffold(
            // Breit tragen Identitaetsspalte und Seitenkopf die Kopfzeile; eine
            // zusaetzliche AppBar brachte nur den Heldennamen ein zweites Mal
            // und schob den Inhalt nach unten.
            appBar: schmal
                ? AppBar(
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
                        itemBuilder: (_) => _menueEintraege(),
                      ),
                    ],
                  )
                : null,
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
                : SafeArea(
                    child: Row(
                      // Ohne stretch bekommt die Leiste nur die Hoehe ihrer
                      // drei Ziele und saesse als dunkler Block mitten im
                      // Hellen.
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: switch (breite) {
                            KartoBreite.sehrBreit => 272.0,
                            KartoBreite.breit => 248.0,
                            _ => 208.0,
                          },
                          child: ColoredBox(
                            color: context.karto.navigation,
                            child: SingleChildScrollView(child: navigation),
                          ),
                        ),
                        Expanded(child: inhalt),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  // Die Marke zeigt, wessen Bogen offen ist. Das Bild kommt ueber die Bruecke,
  // weil Avatare ausschliesslich `AvatarGalleryImage` rendern darf.
  Widget _navigationsKopf(HeroSheet hero) {
    final dateiname = hero.appearance.aktivesBild?.fileName;
    return KartoHeldenmarke(
      name: hero.name,
      herkunft: _herkunft(hero),
      bild: dateiname == null
          ? null
          : (ersatz) => widget.bestand.heldenbild(
              heroId: widget.heroId,
              dateiname: dateiname,
              groesse: 88,
              ersatz: ersatz,
            ),
    );
  }

  // Die Profession benennt einen Helden am genauesten; Kultur und Rasse
  // springen nur ein, damit die Zeile bei unvollstaendigen Boegen nicht leer
  // bleibt und die Marke ihre Hoehe behaelt.
  String _herkunft(HeroSheet hero) {
    final kandidaten = <String>[
      hero.background.profession,
      hero.background.kultur,
      hero.background.rasse,
    ];
    for (final wert in kandidaten) {
      if (wert.trim().isNotEmpty) return wert.trim();
    }
    return '';
  }

  // Beide Wege tragen dieselben Tooltips wie zuvor in der AppBar: sie sind die
  // Einstiege, auf die sich Bedien- und Abnahmetests beziehen.
  Widget _navigationsFuss() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      _Fussziel(
        icon: Icons.arrow_back,
        beschriftung: 'Heldenauswahl',
        onTap: _zurHeldenwahl,
      ),
      PopupMenuButton<String>(
        tooltip: 'Workspace-Menü',
        onSelected: _menueAktion,
        itemBuilder: (_) => _menueEintraege(),
        // Kein eigener Tooltip im Ziel: der Knopf bringt bereits einen mit,
        // und zwei gleichlautende waeren in den Bedientests doppelt.
        child: const _Fussziel(
          icon: Icons.more_horiz,
          beschriftung: 'Workspace-Menü',
        ),
      ),
    ],
  );

  List<PopupMenuEntry<String>> _menueEintraege() => <PopupMenuEntry<String>>[
    const PopupMenuItem(value: 'helden', child: Text('Helden verwalten')),
    const PopupMenuItem(value: 'einstellungen', child: Text('Einstellungen')),
    const PopupMenuItem(
      value: 'bestand',
      child: Text('Zur bestehenden Oberfläche'),
    ),
    if (ref.read(debugModusProvider))
      const PopupMenuItem(value: 'token', child: Text('Token-Blatt')),
  ];

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
    // Ohne stretch zentriert Column seine schrumpfenden Kinder; der
    // Sperrhinweis staende dann mittig statt am linken Rand.
    crossAxisAlignment: CrossAxisAlignment.stretch,
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

  // Start, Speichern und Verwerfen bleiben beim gemeinsamen Workspace-Guard.
  Widget _planung(AdvancementSession? session, KartoBreite breite) {
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
    return Column(
      // Siehe _verwaltung: ohne stretch zentriert Column den Seitenkopf.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            breite.seitenrand,
            breite.seitenrand,
            breite.seitenrand,
            0,
          ),
          child: _planungskopf(session, breite),
        ),
        Expanded(
          child: KartoEntwicklungsansicht(
            heroId: widget.heroId,
            bestand: widget.bestand,
          ),
        ),
      ],
    );
  }

  // Der Entwurfshinweis ist die Einordnung dieser Seite und steht deshalb als
  // Kontextzeile ueber dem Titel, nicht als eigene Leiste daneben.
  //
  // Schmale Fenster bekommen **keinen** Seitentitel: der Katalog darunter
  // fuehrt bereits seine eigene Ueberschrift, und die Planung braucht die
  // Hoehe fuer die erste Steigerungskarte. Auf breiten Fenstern ist beides
  // Platz genug und die Stufung Seite → Abschnitt hilfreich.
  Widget _planungskopf(AdvancementSession session, KartoBreite breite) {
    const entwurf = 'Entwurf – wird erst beim Übernehmen gespeichert.';
    final aktionen = Wrap(
      spacing: Abstand.normal,
      runSpacing: Abstand.knapp,
      children: [
        OutlinedButton(
          onPressed: session.isSaving ? null : _verwirfPlan,
          child: const Text('Verwerfen'),
        ),
        FilledButton(
          key: const ValueKey('karto-plan-commit'),
          onPressed: session.canCommit ? _uebernehmePlan : null,
          child: Text(
            session.isSaving ? 'Speichert …' : 'Änderungen übernehmen',
          ),
        ),
      ],
    );
    if (breite != KartoBreite.schmal) {
      return KartoSeitenkopf(
        titel: 'Nächste Schritte',
        kontext: entwurf,
        aktion: aktionen,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: Abstand.block),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entwurf,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: context.karto.schriftLeise),
          ),
          const SizedBox(height: Abstand.normal),
          aktionen,
        ],
      ),
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
}

/// Ruhiger Eintrag im Fussbereich der Bereichsnavigation.
///
/// Bewusst leiser als ein Navigationsziel: diese Wege fuehren aus dem
/// Workspace heraus und sollen nicht mit den drei Arbeitsbereichen um
/// Aufmerksamkeit konkurrieren.
///
/// Ohne [onTap] liefert das Ziel nur seine Darstellung. Diesen Fall braucht
/// das Workspace-Menue: sein [PopupMenuButton] bringt Tooltip, Semantik und
/// Trefferflaeche bereits mit, und ein zweiter Tooltip gleichen Wortlauts
/// waere in den Bedientests doppelt vorhanden.
class _Fussziel extends StatelessWidget {
  const _Fussziel({required this.icon, required this.beschriftung, this.onTap});

  final IconData icon;
  final String beschriftung;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final token = KartoTheme.of(context);
    final inhalt = Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(
        horizontal: Abstand.block,
        vertical: Abstand.normal,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: token.navigationMuted),
          const SizedBox(width: Abstand.weit),
          Expanded(
            child: Text(
              beschriftung,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: token.navigationMuted),
            ),
          ),
        ],
      ),
    );
    final ziel = onTap;
    if (ziel == null) return inhalt;
    // MergeSemantics ist hier nicht schmueckend: ein Tooltip legt seine Angabe
    // auf einen Knoten *unterhalb* seiner selbst, waehrend die Pruefung vom
    // Tooltip aus nach oben sucht. Ohne die Verschmelzung findet sie den
    // umgebenden Scrollbereich und damit eine leere Angabe. In der frueheren
    // AppBar uebernahm das der IconButton.
    return MergeSemantics(
      child: Tooltip(
        message: beschriftung,
        child: InkWell(onTap: ziel, child: inhalt),
      ),
    );
  }
}
