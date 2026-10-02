import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ablauf_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_ressourcenleiste.dart';

import 'gefecht_aktionsdialog.dart';
import 'gefecht_rundenleiste.dart';
import 'gefecht_ausruestung.dart';
import 'gefecht_magie.dart';
import 'gefecht_manoeverliste.dart';
import 'gefecht_orientieren.dart';

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
  int _nummer = 0;
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
                  final w = gefechtswerteFuer(snapshot);
                  final angriff = _angriff(s, snapshot, katalog);
                  final verteidigung = _verteidigung(s, snapshot, katalog);
                  final manoever = _manoever(s, snapshot, katalog);
                  final ressourcen = _durchhalten(snapshot);
                  final magie = GefechtMagie(
                    werte: snapshot,
                    katalog: katalog,
                    gesperrt: _busy,
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
  }) {
    final auftrag = GefechtAuftrag(
      aktion: aktion,
      titel: titel,
      zuschlag: m == null ? 0 : gefechtsManoeverZuschlag(m),
      dk: s.dk,
      dauer: 1,
      kosten: 1,
      manoever: m,
      manuell: manuell,
    );
    final p = katalog == null
        ? null
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
          knopf: (m) =>
              _knopf(s, snapshot, k, Gefechtsaktion.angriff, m.name, m: m),
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
        _knopf(
          s,
          snapshot,
          k,
          Gefechtsaktion.zusatzaktion,
          'Waffengebundene Zusatzaktion',
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
        Text(snapshot.hero.combatConfig.selectedWeapon.name),
        if (snapshot.combatPreviewStats.offhandName.isNotEmpty)
          Text(snapshot.combatPreviewStats.offhandName),
        Text(
          'RS ${snapshot.combatPreviewStats.rsTotal} · BE ${snapshot.combatPreviewStats.beKampf}',
        ),
        const Text('Waffen und Rüstungsteile im Ausrüstungspopup wechseln.'),
      ],
    ),
  );

  // Ergebnisbuchung erfolgt beim Abschluss der Probe, auch vor Schließen des Dialogs.
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
  }) async {
    if (k == null) return;
    if (aktion == Gefechtsaktion.orientieren ||
        aktion == Gefechtsaktion.position && s.desorientiert) {
      await zeigeOrientieren(
        context: context,
        ref: ref,
        heroId: widget.heroId,
        bestand: _bruecke,
        position: aktion == Gefechtsaktion.position,
      );
      return;
    }
    if (beschreibung != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(titel),
          content: SingleChildScrollView(child: Text(beschreibung)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Weiter'),
            ),
          ],
        ),
      );
      if (!mounted) return;
    }
    final auftrag = await showDialog<GefechtAuftrag>(
      context: context,
      builder: (_) => GefechtAktionsdialog(
        zustand: s,
        werte: snapshot,
        katalog: k,
        aktion: aktion,
        titel: titel,
        manoever: m,
        probe: probe,
        manuell: manuell,
      ),
    );
    if (auftrag == null || !mounted) return;
    final frisch = ref.read(heroComputedProvider(widget.heroId)).asData?.value;
    final aktuell = ref.read(gefechtProvider(widget.heroId));
    if (frisch == null || aktuell == null) return;
    final p = pruefeGefechtAuftrag(aktuell, frisch, k, auftrag);
    if (p.status == Gefechtsfreigabe.gesperrt) {
      throw StateError(p.gruende.join(' '));
    }
    _controller.setzen(aktuell.copyWith(dk: auftrag.dk));
    final id = 'auftrag-${_nummer++}';
    if (!_controller.reservieren(id)) return;
    final request = gefechtRequestFuerAuftrag(auftrag, p);
    final restHandlung = gefechtHandlungNachAuftrag(
      titel: titel,
      dauer: auftrag.dauer,
      pruefung: p,
      probe: probe != null ? request : null,
    );
    void buchen([ProbeResult? result]) {
      final w = gefechtswerteFuer(frisch);
      if (!_controller.abschliessen(id, w, p, erfolg: result?.success)) return;
      final jetzt = ref.read(gefechtProvider(widget.heroId))!;
      if (restHandlung != null) {
        _controller.setzen(jetzt.copyWith(handlung: restHandlung));
      }
    }

    try {
      // Längere Zauber werden erst nach ihrer bestätigten Dauer ausgewertet.
      if (request == null || probe != null && restHandlung != null) {
        buchen();
      } else {
        await _bruecke.gefechtsProbe(
          context: context,
          ref: ref,
          heroId: widget.heroId,
          request: request,
          onResolved: buchen,
        );
      }
    } finally {
      _controller.abbrechen(id);
    }
  }

  Widget _handlung(Gefechtszustand s, HeroComputedSnapshot snapshot) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${s.handlung!.titel} · noch ${s.handlung!.verbleibend} Aktionen',
          ),
          FilledButton.tonal(
            onPressed: _busy
                ? null
                : () => _run(
                    () => setzeGefechtsausruestungFort(
                      context: context,
                      ref: ref,
                      heroId: widget.heroId,
                      bestand: _bruecke,
                    ),
                  ),
            child: const Text('Fortsetzen'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => _controller.setzen(s.copyWith(ohneHandlung: true)),
            child: const Text('Handlung abbrechen'),
          ),
        ],
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
