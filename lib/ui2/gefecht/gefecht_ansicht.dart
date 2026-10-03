import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

import 'gefecht_angriffsergebnis.dart';

import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_hand_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_zusatz_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_orientieren_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ablauf_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_ressourcenleiste.dart';

import 'gefecht_aktionsdialog.dart';

import 'package:dsa_heldenverwaltung/rules/derived/gefecht_filter_rules.dart';

import 'gefecht_rundenleiste.dart';
import 'gefecht_ausruestung.dart';
import 'gefecht_magie.dart';
import 'gefecht_manoeverliste.dart';
import 'gefecht_wirken.dart';
import 'gefecht_aktion_ausfuehren.dart';

import 'gefecht_handlungskarte.dart';
import 'gefecht_unterbrechung.dart';

/// Responsive Spielansicht eines flüchtigen Gefechts mit echten Heldendaten.
class GefechtAnsicht extends ConsumerStatefulWidget {
  /// Bindet Navigation und Fachdialoge an dieselbe Heldenidentität.
  const GefechtAnsicht({
    super.key,
    required this.heroId,
    required this.bestand,
  });
  final String heroId;
  final KartoBestandsAdapter bestand;
  @override
  ConsumerState<GefechtAnsicht> createState() => _GefechtAnsichtState();
}

class _GefechtAnsichtState extends ConsumerState<GefechtAnsicht> {
  bool _busy = false;
  GefechtsController get _controller =>
      ref.read(gefechtProvider(widget.heroId).notifier);
  KartoGefechtsAdapter get _bruecke => widget.bestand as KartoGefechtsAdapter;
  // Ein einziger Guard umfasst Dialog, Probe und nachgelagerte Schreibwege.
  Future<void> _run(Future<void> Function() aktion) async {
    if (_busy) return;
    setState(() {
      _busy = true;
    });
    try {
      await aktion();
    } catch (fehler) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$fehler')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final geladen = ref.watch(heroComputedProvider(widget.heroId));
    final s = ref.watch(gefechtProvider(widget.heroId));
    final katalog = ref.watch(rulesCatalogProvider).asData?.value;
    final snapshot = geladen.asData?.value;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gefecht'),
          actions: [
            TextButton(
              onPressed: _busy ? null : () => _run(_beenden),
              child: const Text('Beenden'),
            ),
          ],
        ),
        body: s == null
            ? const Center(child: Text('Kein laufendes Gefecht.'))
            : snapshot == null
            ? Center(
                child: geladen.hasError
                    ? Text('Spielwerte nicht geladen: ${geladen.error}')
                    : const CircularProgressIndicator(),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final w = gefechtswerteFuer(snapshot, katalog: katalog);
                  final angriff = _angriff(s, snapshot, katalog);
                  final verteidigung = _verteidigung(s, snapshot, katalog);
                  final manoever = _manoever(s, snapshot, katalog);
                  final ressourcen = _durchhalten(snapshot);
                  final magie = GefechtMagie(
                    werte: snapshot,
                    katalog: katalog,
                    gesperrt: _busy,
                    onZauber: (z) => _run(
                      () => zeigeGefechtsWirken(
                        context: context,
                        ref: ref,
                        heroId: widget.heroId,
                        bestand: _bruecke,
                        zauber: z,
                      ),
                    ),
                    onKarma: (t) => _run(
                      () => zeigeGefechtsWirken(
                        context: context,
                        ref: ref,
                        heroId: widget.heroId,
                        bestand: _bruecke,
                        talent: t,
                      ),
                    ),
                    onAuftrag: (titel, probe, beschreibung) => _run(
                      () => _aktion(
                        s,
                        snapshot,
                        katalog,
                        Gefechtsaktion.handlung,
                        titel,
                        probe: probe,
                        manuell: true,
                        beschreibung: beschreibung,
                      ),
                    ),
                  );
                  final links = [ressourcen, _ausruestung(snapshot)];
                  final mitte = [angriff, manoever, magie];
                  final rechts = [verteidigung, _weitere(s, snapshot, katalog)];
                  Widget spalte(List<Widget> kinder) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final k in kinder)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: k,
                        ),
                    ],
                  );
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          snapshot.hero.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        GefechtRundenleiste(
                          onAktion: _run,
                          zustand: s,
                          werte: w,
                          gesperrt: _busy,
                          onAendern: _controller.setzen,
                          onRunde: () => _run(() async {
                            _controller.setzen(naechsteGefechtsrunde(s));
                          }),
                        ),
                        const SizedBox(height: 12),
                        if (s.handlung != null) _handlung(s, snapshot),
                        if (constraints.maxWidth < 744)
                          spalte([
                            angriff,
                            manoever,
                            verteidigung,
                            _weitere(s, snapshot, katalog),
                            magie,
                            ressourcen,
                            _ausruestung(snapshot),
                          ])
                        else if (constraints.maxWidth < 1100)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: spalte(mitte)),
                              const SizedBox(width: 16),
                              Expanded(child: spalte([...rechts, ...links])),
                            ],
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: spalte(links)),
                              const SizedBox(width: 16),
                              Expanded(flex: 4, child: spalte(mitte)),
                              const SizedBox(width: 16),
                              Expanded(flex: 3, child: spalte(rechts)),
                            ],
                          ),
                        widget.bestand.spielProtokoll(snapshot),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  // Karte und Ausführung rufen dieselbe Freigabe auf; auch Sperren erklären sich.
  Widget _knopf(
    Gefechtszustand s,
    HeroComputedSnapshot snapshot,
    RulesCatalog? katalog,
    Gefechtsaktion aktion,
    String titel, {
    ManeuverDef? m,
    bool manuell = false,
    GefechtsKampfmittelwahl? kampfmittel,
    bool zusatzParade = false,
  }) {
    final auftrag = GefechtAuftrag(
      aktion: aktion,
      titel: titel,
      zuschlag: 0,
      dk: s.dk,
      dauer: 1,
      kosten: 1,
      manoever: m,
      manuell: manuell,
      kampfmittel: kampfmittel,
      zusatzParade: zusatzParade,
    );
    final p = katalog == null
        ? null
        : aktion == Gefechtsaktion.orientieren ||
              aktion == Gefechtsaktion.position && s.desorientiert
        ? pruefeOrientierung(
            s,
            gefechtswerteFuer(snapshot, katalog: katalog),
            position: aktion == Gefechtsaktion.position,
          )
        : pruefeGefechtAuftrag(s, snapshot, katalog, auftrag);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: _busy || katalog == null
            ? null
            : () => _run(
                () => _aktion(
                  s,
                  snapshot,
                  katalog,
                  aktion,
                  titel,
                  m: m,
                  manuell: manuell,
                  kampfmittel: kampfmittel,
                  zusatzParade: zusatzParade,
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(titel)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  p == null
                      ? 'Lädt'
                      : '${freigabeText(p.status)}${p.zielwert == null ? '' : ' · ${p.zielwert}'}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _angriff(
    Gefechtszustand s,
    HeroComputedSnapshot snapshot,
    RulesCatalog? k,
  ) => KartoAbschnitt(
    titel: 'Angriff',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Geführt: ${snapshot.hero.combatConfig.selectedWeapon.name}'),
        Text('TP ${snapshot.combatPreviewStats.tpExpression}'),
        const SizedBox(height: 8),
        _knopf(s, snapshot, k, Gefechtsaktion.angriff, 'Angreifen'),
        for (final ergebnis in s.angriffsergebnisse)
          GefechtAngriffsergebnisAnzeige(
            ergebnis: ergebnis,
            heroId: widget.heroId,
            bestand: _bruecke,
            gesperrt: _busy || s.handlung != null,
            onAktion: _run,
          ),
        TextButton(
          onPressed: _busy ? null : () => _run(() => _schaden(snapshot)),
          child: const Text('Schaden würfeln'),
        ),
      ],
    ),
  );
  Widget _verteidigung(
    Gefechtszustand s,
    HeroComputedSnapshot snapshot,
    RulesCatalog? k,
  ) => KartoAbschnitt(
    titel: 'Verteidigung',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final eintrag in {
          Gefechtsaktion.parade: 'Parieren',
          if (gefechtsSchildparadeSichtbar(snapshot))
            Gefechtsaktion.schildparade: 'Schildparade',
          Gefechtsaktion.freiesAusweichen: 'Freies Ausweichen',
          Gefechtsaktion.gezieltesAusweichen: 'Gezieltes Ausweichen',
        }.entries)
          _knopf(s, snapshot, k, eintrag.key, eintrag.value),
      ],
    ),
  );
  Widget _manoever(
    Gefechtszustand s,
    HeroComputedSnapshot snapshot,
    RulesCatalog? k,
  ) => k == null
      ? const KartoAbschnitt(
          titel: 'Manöver',
          child: Text('Katalog wird geladen.'),
        )
      : GefechtManoeverliste(
          manoever: gefechtsManoeverliste(s, snapshot, k),
          erlernt: (m) => gefechtsManoeverErlernt(m, snapshot, k),
          gesperrt: (m) =>
              pruefeGefechtAuftrag(
                s,
                snapshot,
                k,
                GefechtAuftrag(
                  aktion: gefechtsManoeveraktion(m),
                  titel: m.name,
                  zuschlag: 0,
                  dk: s.dk,
                  dauer: 1,
                  kosten: 1,
                  manoever: m,
                ),
              ).status ==
              Gefechtsfreigabe.gesperrt,
          knopf: (m) =>
              _knopf(s, snapshot, k, gefechtsManoeveraktion(m), m.name, m: m),
        );
  Widget _weitere(
    Gefechtszustand s,
    HeroComputedSnapshot snapshot,
    RulesCatalog? k,
  ) => KartoAbschnitt(
    titel: 'Weitere Aktionen',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _knopf(
          s,
          snapshot,
          k,
          Gefechtsaktion.position,
          s.desorientiert ? 'Position + Orientieren' : 'Position',
        ),
        _knopf(
          s,
          snapshot,
          k,
          Gefechtsaktion.orientieren,
          'Orientieren',
          manuell: true,
        ),
        _knopf(s, snapshot, k, Gefechtsaktion.freieAktion, 'Freie Aktion'),
        for (final option in gefechtsZusatzoptionen(snapshot))
          _knopf(
            s,
            snapshot,
            k,
            Gefechtsaktion.zusatzaktion,
            option.titel,
            kampfmittel: option.kampfmittel,
            zusatzParade: option.parade,
          ),
        _knopf(
          s,
          snapshot,
          k,
          Gefechtsaktion.handlung,
          'Manuelle Sonderaktion',
          manuell: true,
        ),
      ],
    ),
  );
  Widget _durchhalten(HeroComputedSnapshot snapshot) => Card(
    child: ExpansionTile(
      key: ValueKey(
        'durchhalten-${snapshot.wundEffekte.hatAbzuege}-${snapshot.state.currentLep}',
      ),
      title: const Text('Durchhalten'),
      initiallyExpanded: gefechtDurchhaltenOeffnen(
        wundAbzuege: snapshot.wundEffekte.hatAbzuege,
        lep: snapshot.state.currentLep,
        maxLep: snapshot.derivedStats.maxLep,
      ),
      childrenPadding: const EdgeInsets.all(12),
      children: [
        KartoRessourcenleiste(
          werte: snapshot,
          onBearbeiten: (r) => _run(
            () => widget.bestand.ressourceBearbeiten(
              context: context,
              heroId: widget.heroId,
              ressource: r,
            ),
          ),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => _run(
                  () => widget.bestand.schadenErhalten(
                    context: context,
                    ref: ref,
                    heroId: widget.heroId,
                  ),
                ),
          child: const Text('Schaden erhalten'),
        ),
        widget.bestand.spielZustand(heroId: widget.heroId, werte: snapshot),
        TextButton(
          onPressed: _busy
              ? null
              : () => _run(
                  () => widget.bestand.effekte(
                    context: context,
                    heroId: widget.heroId,
                  ),
                ),
          child: const Text('Effekte verwalten'),
        ),
        widget.bestand.spielEffekte(heroId: widget.heroId, werte: snapshot),
      ],
    ),
  );
  Widget _ausruestung(HeroComputedSnapshot snapshot) => KartoAbschnitt(
    titel: 'Geführte Ausrüstung',
    aktion: TextButton(
      onPressed: _busy
          ? null
          : () => _run(
              () => zeigeGefechtsausruestung(
                context: context,
                ref: ref,
                heroId: widget.heroId,
                bestand: _bruecke,
              ),
            ),
      child: const Text('Wechseln'),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(gefechtsHandbelegung(snapshot.hero.combatConfig)),
        Text(
          'RS ${snapshot.combatPreviewStats.rsTotal} · BE ${snapshot.combatPreviewStats.beKampf}',
        ),
        const Text('Waffen und Rüstungsteile im Ausrüstungspopup wechseln.'),
      ],
    ),
  );

  Future<void> _aktion(
    Gefechtszustand s,
    HeroComputedSnapshot snapshot,
    RulesCatalog? k,
    Gefechtsaktion aktion,
    String titel, {
    ManeuverDef? m,
    ResolvedProbeRequest? probe,
    bool manuell = false,
    String? beschreibung,
    GefechtsKampfmittelwahl? kampfmittel,
    bool zusatzParade = false,
  }) async {
    await fuehreGefechtsaktionAus(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      bestand: _bruecke,
      s: s,
      snapshot: snapshot,
      k: k,
      aktion: aktion,
      titel: titel,
      m: m,
      probe: probe,
      manuell: manuell,
      beschreibung: beschreibung,
      kampfmittel: kampfmittel,
      zusatzParade: zusatzParade,
    );
  }

  Widget _handlung(Gefechtszustand s, HeroComputedSnapshot snapshot) =>
      gefechtsHandlungskarte(
        s,
        gesperrt: _busy,
        onFortsetzen: () => _run(
          () => setzeGefechtsausruestungFort(
            context: context,
            ref: ref,
            heroId: widget.heroId,
            bestand: _bruecke,
          ),
        ),
        onAbbruch: () => _run(
          () => brecheGefechtsHandlungAb(
            context: context,
            ref: ref,
            heroId: widget.heroId,
          ),
        ),
        onStoerung: () => _run(
          () => stoereGefechtsWirken(
            context: context,
            ref: ref,
            heroId: widget.heroId,
            bestand: _bruecke,
          ),
        ),
      );
  Future<void> _schaden(HeroComputedSnapshot snapshot) async {
    await _bruecke.gefechtsProbe(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      request: ResolvedProbeRequest(
        type: ProbeType.damage,
        title: 'Schaden',
        subtitle: snapshot.combatPreviewStats.tpExpression,
        ruleHint: 'TP-Wurf; RS, Wunden und Manöverfolgen beim Gegner manuell berücksichtigen.',
        diceSpec: snapshot.combatPreviewStats.damageDiceSpec,
        targets: const [],
      ),
    );
  }

  Future<void> _beenden() async {
    if (ref.read(gefechtProvider(widget.heroId))?.handlung != null) {
      throw StateError(
        'Laufende Handlung zuerst abschließen oder Abbruch bestätigen.',
      );
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gefecht beenden?'),
        content: const Text(
          'Runde, INI und Aktionsmarken werden verworfen. '
          'Gespeicherte Ressourcen, Ausrüstung und Protokolle bleiben erhalten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Weiterkämpfen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Beenden'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      _controller.beenden();
      Navigator.pop(context);
    }
  }
}
