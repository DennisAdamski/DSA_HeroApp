import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

import 'gefecht_angriffsergebnis.dart';
import 'gefecht_aktionsknopf.dart';
import 'gefecht_anordnung.dart';
import 'gefecht_schnellleiste.dart';
import 'gefecht_probenwahl.dart';
import 'gefecht_aktionswahl.dart';
import 'gefecht_begleiter.dart';
import 'gefecht_inventar.dart';
import 'gefecht_gegner.dart';
import 'gefecht_initiative.dart';
import 'gefecht_beenden.dart';
import 'gefecht_reserve.dart';
import 'gefecht_patzer.dart';
import 'gefecht_klingen.dart';

import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_patzer_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_lage_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_patzer_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_hand_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_zusatz_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_orientieren_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
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
import 'gefecht_laden.dart';
import 'gefecht_geschosse.dart';
import 'gefecht_vitalwerte.dart';

import 'package:dsa_heldenverwaltung/rules/derived/gefecht_laden_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kampfmittel_rules.dart';

import 'gefecht_fehlertext.dart';

part 'gefecht_ansicht_teile.dart';

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
  String? _fehler;
  GefechtsController get _controller =>
      ref.read(gefechtProvider(widget.heroId).notifier);
  KartoGefechtsAdapter get _bruecke => widget.bestand as KartoGefechtsAdapter;
  // Ein einziger Guard umfasst Dialog, Probe und nachgelagerte Schreibwege.
  Future<void> _run(Future<void> Function() aktion) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _fehler = null;
    });
    try {
      await aktion();
    } catch (fehler) {
      if (mounted) setState(() => _fehler = gefechtsFehlertext(fehler));
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
    final s = ref.watch(gefechtMitInitiativeProvider(widget.heroId));
    final katalog = ref.watch(rulesCatalogProvider).asData?.value;
    final snapshot = geladen.asData?.value;
    // Strg/Cmd+K öffnet wie im Spielbereich die Probenauswahl, hier aber
    // gefechtsbewusst; die Route liegt außerhalb des Workspace-Kürzels.
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _probe,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _probe,
      },
      child: Focus(
        autofocus: true,
        child: PopScope(
          canPop: !_busy,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Gefecht'),
              actions: [
                TextButton.icon(
                  key: const ValueKey('gefecht-probe'),
                  onPressed: _busy || s == null ? null : _probe,
                  icon: const Icon(Icons.search),
                  label: const Text('Probe'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _run(_beenden),
                  child: const Text('Beenden'),
                ),
              ],
            ),
            bottomNavigationBar:
                s != null &&
                    snapshot != null &&
                    MediaQuery.sizeOf(context).width < kGefechtZweispaltig
                ? _schnellleiste(s, snapshot, katalog)
                : null,
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
                      final ressourcen = _vitalwerte(snapshot);
                      final magie = GefechtMagie(
                        werte: snapshot,
                        katalog: katalog,
                        zuletzt: s.zuletztGewirkt,
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
                              onRunde: () =>
                                  _run(() async => _naechsteRunde(s)),
                            ),
                            if (_fehler != null) _fehlerhinweis(_fehler!),
                            ..._lagebanner(snapshot),
                            const SizedBox(height: 12),
                            GefechtPatzer(
                              heroId: widget.heroId,
                              bestand: () => _bruecke,
                              gesperrt: _busy,
                              onAktion: _run,
                            ),
                            if (s.handlung != null) _handlung(s, snapshot),
                            GefechtKlingenkarte(
                              heroId: widget.heroId,
                              bestand: () => _bruecke,
                              gesperrt: _busy,
                              onAktion: _run,
                            ),
                            GefechtAnordnung(
                              breite: constraints.maxWidth,
                              vitalwerte: ressourcen,
                              angriff: angriff,
                              verteidigung: verteidigung,
                              manoever: manoever,
                              magie: magie,
                              weitere: [
                                _weitere(s, snapshot, katalog),
                                GefechtReservekarte(
                                  heroId: widget.heroId,
                                  bestand: () => _bruecke,
                                  gesperrt: _busy,
                                  onAktion: _run,
                                ),
                              ],
                              begegnung: [
                                GefechtGegnerkarte(
                                  heroId: widget.heroId,
                                  waffenDk: w.waffenDk,
                                  fernkampf: w.fernkampf,
                                  gesperrt: _busy,
                                  onAktion: _run,
                                ),
                                GefechtInitiativkarte(
                                  heroId: widget.heroId,
                                  gesperrt: _busy,
                                  onAktion: _run,
                                ),
                                GefechtBegleiter(
                                  begleiter: snapshot.hero.companions,
                                ),
                              ],
                              ausruestung: _ausruestung(snapshot),
                            ),
                            widget.bestand.spielProtokoll(snapshot),
                          ],
                        ),
                      );
                    },
                  ),
          ),
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
    GefechtsDialogzweck zweck = GefechtsDialogzweck.aktion,
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
      distanzSchritte: zweck == GefechtsDialogzweck.distanzklasse ? -1 : 0,
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
    return GefechtAktionsknopf(
      titel: titel,
      pruefung: p,
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
                zweck: zweck,
              ),
            ),
    );
  }

  // Fehler bleiben sichtbar, bis die nächste Aktion beginnt oder er geschlossen wird.
  Widget _fehlerhinweis(String text) => Card(
    key: const ValueKey('gefecht-fehler'),
    color: Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      leading: const Icon(Icons.error_outline),
      title: Text(text),
      trailing: IconButton(
        tooltip: 'Hinweis schließen',
        onPressed: () => setState(() => _fehler = null),
        icon: const Icon(Icons.close),
      ),
    ),
  );

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
        if (s.ansageFolgemalus > 0)
          Text(
            'Ansagefolgemalus +${s.ansageFolgemalus} auf Proben bis einschließlich '
            'nächster AT/PA; Orientieren beendet ihn.',
            key: const ValueKey('gefecht-ansagefolgemalus'),
          ),
        if (s.meisterparadeBonus > 0)
          Text(
            'Meisterparade: nächste Angriffs- oder Abwehraktion '
            'um ${s.meisterparadeBonus} erleichtert.',
            key: const ValueKey('gefecht-meisterparade-bonus'),
          ),
        const SizedBox(height: 8),
        _knopf(s, snapshot, k, Gefechtsaktion.angriff, 'Angreifen'),
        _knopf(
          s,
          snapshot,
          k,
          Gefechtsaktion.angriff,
          'Distanzklasse ändern',
          zweck: GefechtsDialogzweck.distanzklasse,
        ),
        for (final profil in gefechtsKampfmittelprofile(snapshot))
          if (profil.waffe?.isRanged == true)
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => zeigeGefechtsLaden(
                        context: context,
                        ref: ref,
                        heroId: widget.heroId,
                        kampfmittel: profil.wahl,
                      ),
                    ),
              child: Text('Laden / Vorbereiten · ${profil.name}'),
            ),
        GefechtGeschossbereich(
          werte: snapshot,
          heroId: widget.heroId,
          bruecke: () => _bruecke,
          gesperrt: _busy || s.handlung != null,
          onAktion: _run,
        ),
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
          gesperrt: (m) =>
              !kGefechtsBasismanoever.contains(m.id) &&
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
          // Finte und Wuchtschlag sind Ansagen der Attacke, keine eigene Aktion.
          knopf: (m) => kGefechtsBasismanoever.contains(m.id)
              ? _knopf(s, snapshot, k, Gefechtsaktion.angriff, m.name)
              : _knopf(s, snapshot, k, gefechtsManoeveraktion(m), m.name, m: m),
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
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton(
            key: const ValueKey('gefecht-aktionswahl'),
            onPressed: _busy
                ? null
                : () => _run(
                    () => zeigeGefechtsBenannteAktion(
                      context: context,
                      ref: ref,
                      heroId: widget.heroId,
                      bestand: _bruecke,
                    ),
                  ),
            child: const Text('Aktion wählen · Bewegen, Sprinten, Rufen …'),
          ),
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
    GefechtsDialogzweck zweck = GefechtsDialogzweck.aktion,
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
      zweck: zweck,
    );
  }

  Widget _handlung(Gefechtszustand s, HeroComputedSnapshot snapshot) {
    final vorbereitet = s.handlung!.vorbereitung != null;
    final p = vorbereitet ? pruefeGefechtsVorbereitung(s, snapshot) : null;
    final k = ref.watch(rulesCatalogProvider).asData?.value;
    final schuss =
        s.handlung!.art == Gefechtshandlungsart.zielen && p?.rest == 0;
    final schusspruefung = schuss && k != null
        ? pruefeGefechtsZielschuss(s, snapshot, k)
        : null;
    final gruende = schuss
        ? k == null
              ? ['Regelkatalog wird geladen.']
              : [
                  ...schusspruefung!.sperrgruende,
                  ...schusspruefung.fehlendeAngaben,
                  ...schusspruefung.entscheidungen,
                ]
        : <String>[];
    return gefechtsHandlungskarte(
      s,
      gesperrt: _busy,
      vorbereitung: p,
      schussgruende: gruende,
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
  }

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

  Future<void> _beenden() =>
      beendeGefechtsansicht(context: context, ref: ref, heroId: widget.heroId);
}
