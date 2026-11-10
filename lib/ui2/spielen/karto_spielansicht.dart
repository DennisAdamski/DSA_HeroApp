import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/ui2/merkmale/karto_merkmalsblatt.dart';
import 'package:dsa_heldenverwaltung/ui2/merkmale/karto_merkmal_karten.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_zuordnung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spiel_dabei_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_wirkung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_anzeige_rules.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_breakpoints.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuerblatt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_begleiterkarte.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_dabei_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_held_schreiben.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelraster.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kampfinhalt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_laufendes_abenteuer.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_reiseroute.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_ressourcenleiste.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielaktionen.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielraster_bedienung.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielraster_ordnung.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_wuerfelprotokoll.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_zuletzt_gewuerfelt.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_ornamente.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_seitenkopf.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_einstieg.dart';

/// Führt eine Laufzeitaktion aus und meldet Fehler sichtbar.
///
/// Der Workspace reicht seinen vorhandenen Re-Entrancy-Guard herein, damit ein
/// Doppelklick keine zwei Dialoge öffnet und die Spielansicht keinen zweiten
/// Fehlerweg aufmacht.
typedef KartoLaufzeitAktion = Future<void> Function(
  Future<void> Function() aktion,
);

/// Spielansicht: Ressourcen, Schnellaktionen, Kampf, Effekte und Protokoll.
///
/// Liest `heroComputedProvider(heroId)` **einmal** und reicht den Snapshot an
/// die darstellenden Abschnitte weiter; dessen vier Ableitungen werden nicht
/// zusätzlich beobachtet. Gezeigt werden ausschließlich gespeicherte Werte,
/// nie der Entwurf einer offenen Steigerungssitzung.
///
/// Die Abschnitte stehen als Kacheln in einem Raster (SPIEL-07,
/// [KartoKachelraster]). Reihenfolge, Breite, Ausblenden und Einklappen
/// speichert der Held in `HeroSheet.spielansicht`; was eine Kachel erlaubt,
/// legt [KartoSpielkachelArt] fest. Angeordnet wird in einem eigenen Modus
/// mit Entwurf, geschrieben erst bei „Fertig“.
class KartoSpielansicht extends ConsumerStatefulWidget {
  /// Bindet die Ansicht an einen Helden und die Bestandsbrücke.
  const KartoSpielansicht({
    super.key,
    required this.heroId,
    required this.bestand,
    required this.aktion,
    required this.vorHeldenbearbeitung,
  });

  /// ID im gemeinsam genutzten Heldenspeicher.
  final String heroId;

  /// Übergangsbrücke zu den vorhandenen Fachansichten und Dialogen.
  final KartoBestandsAdapter bestand;

  /// Geschützter Ausführungsweg für Dialoge und Bestandsaktionen.
  final KartoLaufzeitAktion aktion;

  /// Prüft vor Abenteuer- und Merkmalsblatt einen offenen Verwaltungsentwurf.
  ///
  /// Notizen- und Übersichts-Tab speichern ihren ganzen Entwurf über den
  /// Helden; ohne diese Prüfung überschriebe ein späteres Speichern dort die
  /// Einträge aus dem Blatt. `false` bricht das Öffnen ab. Dieselbe Prüfung
  /// läuft vor dem Anordnen und dem Einklappen der Kacheln.
  final Future<bool> Function() vorHeldenbearbeitung;

  @override
  ConsumerState<KartoSpielansicht> createState() => _KartoSpielansichtState();
}

class _KartoSpielansichtState extends ConsumerState<KartoSpielansicht>
    with KartoHeldSchreiben<KartoSpielansicht> {
  /// Entwurf des Anordnen-Modus; `null` außerhalb des Modus.
  List<KartoSpielkachel>? _entwurf;

  @override
  String get heroId => widget.heroId;

  @override
  String get planungsSperre =>
      'Während einer Planung ruhen Anordnen und Einklappen.';
  KartoBestandsAdapter get bestand => widget.bestand;
  KartoLaufzeitAktion get aktion => widget.aktion;
  Future<bool> Function() get vorHeldenbearbeitung =>
      widget.vorHeldenbearbeitung;

  @override
  Widget build(BuildContext context) {
    final berechnet = ref.watch(heroComputedProvider(heroId));
    if (berechnet.hasError) {
      return _meldung(
        context,
        'Spielwerte konnten nicht geladen werden: ${berechnet.error}',
        wiederholen: () => ref.invalidate(heroStateProvider(heroId)),
      );
    }
    final werte = berechnet.asData?.value;
    if (werte == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Während einer Planung bräche jede Heldenänderung den Runden-Hash;
    // Anordnen und Einklappen ruhen dann.
    final gesperrt = ref.watch(advancementSessionProvider(heroId)) != null;
    final gespeichert = loeseSpielansichtAuf(
      werte.hero.spielansicht,
      verfuegbar: _verfuegbar(werte),
    );
    final entwurf = gesperrt ? null : _entwurf;
    final kacheln = entwurf ?? gespeichert;
    final sichtbar = <int>[
      for (var i = 0; i < kacheln.length; i++)
        if (!kacheln[i].ausgeblendet) i,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final breite = kartoBreiteFuer(constraints.maxWidth);
        return SingleChildScrollView(
          padding: EdgeInsets.all(breite.seitenrand),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KartoSeitenkopf(
                titel: 'Am Spieltisch',
                kompakt: breite == KartoBreite.schmal,
                // Fest zwischen Titel und „Anordnen“; keine Kachel, also
                // weder verschiebbar noch ausblendbar.
                mitte: _schnellaktionen(context, werte),
                aktion: entwurf == null
                    ? KartoAnordnenKnopf(
                        gesperrt: gesperrt,
                        onPressed: () => _anordnenBeginnen(gespeichert),
                      )
                    : KartoAnordnenAbschluss(
                        speichert: schreibt,
                        onStandard: () => setState(
                          () => _entwurf = loeseSpielansichtAuf(
                            null,
                            verfuegbar: _verfuegbar(werte),
                          ),
                        ),
                        onAbbrechen: () => setState(() => _entwurf = null),
                        onFertig: () => _anordnenBeenden(gespeichert),
                      ),
              ),
              if (entwurf != null) ...[
                KartoAnordnenHinweis(
                  ausgeblendet: [
                    for (final kachel in entwurf)
                      if (kachel.ausgeblendet) kachel.art,
                  ],
                  onEinblenden: (art) => _aendereEntwurf(
                    art,
                    (kachel) => kachel.copyWith(ausgeblendet: false),
                  ),
                ),
                const SizedBox(height: Abstand.block),
              ],
              KartoKachelraster(
                luecke: Abstand.block,
                children: [
                  for (final (stelle, i) in sichtbar.indexed)
                    KartoRasterKachel(
                      key: ValueKey<String>(
                        'karto-kachel-${kacheln[i].art.id}',
                      ),
                      breite: kacheln[i].breite,
                      gewicht: kacheln[i].art.gewicht,
                      child: _kachel(
                        context,
                        werte,
                        kacheln[i],
                        gesperrt: gesperrt,
                        anordnung: entwurf == null
                            ? null
                            : (
                                index: i,
                                vor: stelle > 0 ? sichtbar[stelle - 1] : null,
                                nach: stelle + 1 < sichtbar.length
                                    ? sichtbar[stelle + 1]
                                    : null,
                              ),
                      ),
                    ),
                ],
              ),
              const _Abschluss(),
            ],
          ),
        );
      },
    );
  }

  // Ohne Begleiter entfällt ihre Kachel; ein gespeicherter Eintrag bleibt.
  Set<KartoSpielkachelArt> _verfuegbar(HeroComputedSnapshot werte) => {
    for (final art in KartoSpielkachelArt.values)
      if (art != KartoSpielkachelArt.begleiter ||
          werte.hero.companions.isNotEmpty)
        art,
  };

  // Eine Kachel: im Normalmodus mit Einklappknopf, im Anordnen-Modus eine
  // kompakte Karte mit Bedienung statt des vollen Inhalts. [anordnung] nennt
  // die Stelle im Entwurf und die sichtbaren Nachbarn.
  Widget _kachel(
    BuildContext context,
    HeroComputedSnapshot werte,
    KartoSpielkachel kachel, {
    required bool gesperrt,
    required ({int index, int? vor, int? nach})? anordnung,
  }) {
    final art = kachel.art;
    if (anordnung != null) {
      final (:index, :vor, :nach) = anordnung;
      return KartoAnordnungskarte(
        kachel: kachel,
        onAblegen: (gezogen, seite) =>
            _fuegeEin(gezogen, art, davor: seite == KartoEinfuegeSeite.davor),
        onNachVorn: vor == null ? null : () => _verschiebe(index, vor),
        onNachHinten: nach == null ? null : () => _verschiebe(index, nach),
        onBreite: (breite) =>
            _aendereEntwurf(art, (k) => k.copyWith(breite: breite)),
        onAusblenden: art.ausblendbar
            ? () => _aendereEntwurf(art, (k) => k.copyWith(ausgeblendet: true))
            : null,
        // Der echte Inhalt in der Stufe, die die Kachel bei dieser Breite
        // hätte; ausgeklappt, damit man sieht, was darin steht.
        vorschau: (groesse) => KartoKachelSteuerung(
          kennung: art.id,
          groesse: groesse,
          child: _inhalt(context, werte, art, ref),
        ),
      );
    }
    // Die Größenstufe folgt der echten Kachelbreite; das Raster legt seine
    // Kinder mit fester Breite aus, daher misst der LayoutBuilder genau sie.
    return LayoutBuilder(
      builder: (context, constraints) => KartoKachelSteuerung(
        kennung: art.id,
        eingeklappt: kachel.eingeklappt,
        groesse: KartoKachelGroesse.fuerBreite(constraints.maxWidth),
        onEinklappen: art.einklappbar && !gesperrt
            ? (wert) => _einklappen(art, wert)
            : null,
        onVergroessern: () => _vergroessern(art),
        child: _inhalt(context, werte, art, ref),
      ),
    );
  }

  Widget _inhalt(
    BuildContext context,
    HeroComputedSnapshot werte,
    KartoSpielkachelArt art,
    WidgetRef leser,
  ) => switch (art) {
    KartoSpielkachelArt.ressourcen => _ressourcen(context, werte),
    KartoSpielkachelArt.proben => _proben(context),
    KartoSpielkachelArt.eigenschaften => KartoAbschnitt(
      titel: 'Eigenschaften',
      dicht: true,
      child: bestand.spielEigenschaftsproben(heroId: heroId, werte: werte),
    ),
    KartoSpielkachelArt.kampf => _kampf(werte),
    KartoSpielkachelArt.effekte => _effekte(context, werte),
    KartoSpielkachelArt.zustand => KartoAbschnitt(
      titel: 'Zustand',
      stufe: KartoFlaechenstufe.senke,
      symbol: Icons.monitor_heart_outlined,
      child: bestand.spielZustand(heroId: heroId, werte: werte),
    ),
    KartoSpielkachelArt.begleiter => _begleiter(context, werte),
    KartoSpielkachelArt.dabei => _dabei(context, werte),
    KartoSpielkachelArt.abenteuer => _abenteuer(context, werte, leser),
    KartoSpielkachelArt.reiseroute => KartoReiserouteKachel(
      heroId: heroId,
      stationen: werte.hero.reiseStationen,
    ),
    KartoSpielkachelArt.merkmale => _merkmale(context, werte, leser),
    KartoSpielkachelArt.protokoll => _protokoll(werte),
  };

  // Öffnet die Kachel groß in einem Dialog. Der Dialog liest den Helden selbst
  // (`heroComputedProvider`), damit ein Wurf oder eine Änderung darin sofort
  // erscheint, statt den beim Öffnen erfassten Stand zu zeigen. Er liest nur;
  // geschrieben wird ausschließlich über dieselben Aktionen wie in der Kachel.
  Future<void> _vergroessern(KartoSpielkachelArt art) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, leser, _) {
          final werte = leser.watch(heroComputedProvider(heroId)).asData?.value;
          return Dialog(
            key: ValueKey<String>('karto-kachel-${art.id}-popup'),
            backgroundColor: context.karto.blatt,
            insetPadding: const EdgeInsets.all(Abstand.block),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        0,
                        Abstand.eng,
                        Abstand.eng,
                        0,
                      ),
                      child: IconButton(
                        key: const ValueKey<String>('karto-kachel-popup-zu'),
                        tooltip: 'Schließen',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ),
                  ),
                  Flexible(
                    child: werte == null
                        ? const Padding(
                            padding: EdgeInsets.all(Abstand.bahn),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(
                              Abstand.block,
                              0,
                              Abstand.block,
                              Abstand.block,
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) =>
                                  KartoKachelSteuerung(
                                    kennung: art.id,
                                    dicht: false,
                                    groesse: KartoKachelGroesse.fuerBreite(
                                      constraints.maxWidth,
                                    ),
                                    child: _inhalt(context, werte, art, leser),
                                  ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Anordnen beginnt nach derselben Editorprüfung wie das Merkmalsblatt:
  // ein offener Verwaltungsentwurf überschriebe die Anordnung sonst wieder.
  Future<void> _anordnenBeginnen(List<KartoSpielkachel> gespeichert) async {
    if (!await vorHeldenbearbeitung() || !mounted) return;
    setState(() => _entwurf = gespeichert);
  }

  void _aendereEntwurf(
    KartoSpielkachelArt art,
    KartoSpielkachel Function(KartoSpielkachel kachel) aenderung,
  ) {
    final entwurf = _entwurf;
    if (entwurf == null) return;
    setState(() => _entwurf = aendereSpielkachel(entwurf, art, aenderung));
  }

  void _verschiebe(int von, int nach) {
    final entwurf = _entwurf;
    if (entwurf == null || von == nach) return;
    setState(() => _entwurf = verschiebeSpielkachel(entwurf, von, nach));
  }

  // Die gezogene Kachel wird vor oder hinter der Zielkachel eingefügt.
  void _fuegeEin(
    KartoSpielkachelArt gezogen,
    KartoSpielkachelArt ziel, {
    required bool davor,
  }) {
    final entwurf = _entwurf;
    if (entwurf == null) return;
    setState(
      () =>
          _entwurf = fuegeSpielkachelEin(entwurf, gezogen, ziel, davor: davor),
    );
  }

  // Einziger Schreibweg der Anordnung: frisch laden, nur `spielansicht`
  // ersetzen (ARCH-05). Ohne Änderung wird nichts geschrieben.
  Future<void> _anordnenBeenden(List<KartoSpielkachel> gespeichert) async {
    final entwurf = _entwurf;
    if (entwurf == null || schreibt) return;
    if (_gleich(entwurf, gespeichert)) {
      setState(() => _entwurf = null);
      return;
    }
    final gelungen = await _schreibe(
      (held) => held.copyWith(
        spielansicht: schreibeSpielansicht(entwurf, basis: held.spielansicht),
      ),
    );
    if (gelungen && mounted) setState(() => _entwurf = null);
  }

  // Einklappen schreibt sofort und nur den einen Eintrag.
  Future<void> _einklappen(KartoSpielkachelArt art, bool eingeklappt) async {
    if (!await vorHeldenbearbeitung() || !mounted) return;
    await _schreibe(
      (held) => held.copyWith(
        spielansicht: mitEingeklappt(
          held.spielansicht,
          art,
          eingeklappt: eingeklappt,
        ),
      ),
      einzeln: false,
    );
  }

  // Fehler erscheinen als Hinweis am Seitenrand, nicht in einer Kachel.
  Future<bool> _schreibe(
    HeroSheet Function(HeroSheet held) aenderung, {
    bool einzeln = true,
  }) async {
    final gelungen = await schreibeHeld(
      aenderung,
      einzeln: einzeln,
      fehlerPraefix: 'Anordnung nicht gespeichert: ',
    );
    final text = fehler;
    if (!gelungen && text != null && mounted) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(text)));
    }
    return gelungen;
  }

  static bool _gleich(List<KartoSpielkachel> a, List<KartoSpielkachel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // Der Abschnittskopf öffnet das Blatt auf einem geschützten Weg.
  Future<void> _abenteuerOeffnen(BuildContext context, String abenteuerId) =>
      aktion(() async {
        if (!await vorHeldenbearbeitung() || !context.mounted) return;
        await zeigeAbenteuerblatt(
          context: context,
          heroId: heroId,
          abenteuerId: abenteuerId,
        );
      });

  Widget _ressourcen(BuildContext context, HeroComputedSnapshot werte) =>
      KartoAbschnitt(
        titel: 'Ressourcen',
        dicht: true,
        child: KartoRessourcenleiste(
          werte: werte,
          onBearbeiten: (ressource) => aktion(
            () => bestand.ressourceBearbeiten(
              context: context,
              heroId: heroId,
              ressource: ressource,
            ),
          ),
          // Bewusst ohne `aktion`-Guard: jeder schnelle Klick zählt. Gerechnet
          // wird im Bestand auf dem frisch geladenen, gespeicherten Wert.
          onSchritt: (ressource, schritt) => bestand.ressourceSchritt(
            context: context,
            ref: ref,
            heroId: heroId,
            ressource: ressource,
            schritt: schritt,
          ),
        ),
      );

  Widget _proben(BuildContext context) => KartoAbschnitt(
    titel: 'Häufige Proben',
    dicht: true,
    aktion: TextButton(
      key: const ValueKey<String>('karto-spiel-proben-waehlen'),
      onPressed: () => aktion(
        () => bestand.probeSuchen(context: context, ref: ref, heroId: heroId),
      ),
      child: const Text('Proben wählen'),
    ),
    child: bestand.spielFavoritenproben(heroId: heroId),
  );

  // Die farbigen Schnellaktionen im Seitenkopf; darunter die zuletzt gewürfelten
  // Proben, die sich mit einem Tipp wiederholen lassen (SPIEL-01).
  Widget _schnellaktionen(BuildContext context, HeroComputedSnapshot werte) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KartoSpielaktionen(
          kuerzelHinweis: 'Strg K',
          gefecht: GefechtEinstieg(
            heroId: heroId,
            werte: werte,
            bestand: bestand,
            aktion: aktion,
            vorBearbeitung: vorHeldenbearbeitung,
            hervorgehoben: true,
            stil: kartoSchnellaktionStil(context, context.karto.messing),
            knopfKey: const ValueKey('karto-spiel-gefecht'),
          ),
          onProbeSuchen: () => aktion(
            () =>
                bestand.probeSuchen(context: context, ref: ref, heroId: heroId),
          ),
          // Der Regelindex läuft nur auf Desktop und im Web und wird erst
          // angeboten, wenn die Katalog-Inhalte entsperrt sind (SPIEL-04).
          onRegeln:
              bestand.regelnNachschlagenVerfuegbar &&
                  ref.watch(catalogContentVisibleProvider)
              ? () => aktion(() => bestand.regelnNachschlagen(context: context))
              : null,
          onRast: () =>
              aktion(() => bestand.rast(context: context, heroId: heroId)),
          onSchaden: () => aktion(
            () => bestand.schadenErhalten(
              context: context,
              ref: ref,
              heroId: heroId,
            ),
          ),
        ),
        KartoZuletztGewuerfelt(
          protokoll: werte.state.diceLog,
          onWiederholen: (eintrag) => aktion(
            () => bestand.probeWiederholen(
              context: context,
              ref: ref,
              heroId: heroId,
              eintrag: eintrag,
            ),
          ),
        ),
      ],
    );
  }

  // Geld und Verbrauchsgegenstände am Tisch (SPIEL-02); schreibt selbst und
  // frisch, nie über den Snapshot dieser Ansicht.
  Widget _dabei(BuildContext context, HeroComputedSnapshot werte) =>
      KartoDabeiAbschnitt(
        heroId: heroId,
        dukaten: werte.hero.dukaten,
        verbrauch: dabeiVerbrauchsgegenstaende(werte.hero.inventoryEntries),
        munition: dabeiMunition(werte.hero.combatConfig),
        tragkraft: werte.tragkraft,
        tragkraftBoni: werte.hero.tragkraftBoni,
        erschoepfung: werte.state.erschoepfung,
        ueberanstrengung: werte.state.ueberanstrengung,
        // Trank, Heilmittel und Elixier benutzen den Dialog des Gefechts-
        // inventars; er bucht Wirkung und Stück selbst.
        onBenutzen: switch (bestand) {
          final KartoGefechtsAdapter gefechtsBruecke => (eintrag) => aktion(
            () => gefechtsBruecke.gefechtsVitalwirkung(
              context: context,
              ref: ref,
              heroId: heroId,
              eintrag: eintrag,
            ),
          ),
          _ => null,
        },
      );

  // Das laufende Abenteuer mit Standort, Personen und Notizen.
  Widget _abenteuer(
    BuildContext context,
    HeroComputedSnapshot werte,
    WidgetRef leser,
  ) => KartoAbenteuerAbschnitt(
    heroId: heroId,
    abenteuer: laufendesAbenteuer(werte.hero),
    standort: werte.state.standort,
    sortierung: leser.watch(abenteuerSortierungProvider),
    // Bewusst ohne `aktion`-Guard: der Dialog schließt sich selbst, und
    // das Speichern läuft über den eingereihten Zustandsweg.
    onStandortSpeichern: (standort) => bestand.standortSetzen(
      context: context,
      ref: ref,
      heroId: heroId,
      standort: standort,
    ),
    onOeffnen: () {
      final abenteuer = laufendesAbenteuer(werte.hero);
      if (abenteuer != null) _abenteuerOeffnen(context, abenteuer.id);
    },
    // Suchtreffer in anderen Abenteuern öffnen deren Blatt, auf demselben
    // geschützten Weg wie der Abschnittskopf.
    onAbenteuerOeffnen: (abenteuerId) =>
        _abenteuerOeffnen(context, abenteuerId),
  );

  // Vor- und Nachteile kompakt; bearbeitet wird im Merkmalsblatt, nach
  // derselben Editorprüfung wie beim Abenteuerblatt.
  Widget _merkmale(
    BuildContext context,
    HeroComputedSnapshot werte,
    WidgetRef leser,
  ) {
    final catalog = leser.watch(heroRulesCatalogProvider(heroId)).valueOrNull;
    // Ohne geladenen Katalog zeigt die Übersicht die gespeicherten Texte;
    // bearbeitet werden kann erst mit Katalog.
    final katalog = catalog == null
        ? MerkmalKatalog(vorteile: const [], nachteile: const [])
        : MerkmalKatalog.von(catalog);
    final abgleich = werteMerkmaleAus(werte.hero, catalog: catalog).abgleich;
    List<MerkmalAnzeige> aufbereiten(List<HeroMerkmal> liste, bool vorteil) {
      return [
        for (final eintrag in liste)
          beschreibeMerkmal(eintrag, katalog, vorteil: vorteil),
      ];
    }

    return KartoAbschnitt(
      titel: 'Vor- und Nachteile',
      aktion: TextButton(
        key: const ValueKey<String>('karto-spiel-merkmale'),
        onPressed: catalog == null
            ? null
            : () => aktion(() async {
                if (!await vorHeldenbearbeitung() || !context.mounted) return;
                await zeigeMerkmalsblatt(context: context, heroId: heroId);
              }),
        child: const Text('Bearbeiten'),
      ),
      child: KartoMerkmalsuebersicht(
        vorteile: aufbereiten(abgleich.vorteile, true),
        nachteile: aufbereiten(abgleich.nachteile, false),
        aufgeklappt: leser.watch(merkmaleAufgeklapptProvider),
        // Rein geraetelokal: ein Tipp aendert nur die Einstellung, nie den
        // Helden; deshalb ohne `aktion`-Guard und ohne Editorpruefung.
        onUmschalten: (aufgeklappt) => ref
            .read(settingsActionsProvider)
            .setMerkmaleAufgeklappt(aufgeklappt),
      ),
    );
  }

  // Kampf, Effekte, Zustand und Begleiter sitzen eine Flächenstufe tiefer,
  // damit sie als Begleitflächen lesbar bleiben und nicht mit Schnellaktionen
  // und Ressourcen um dieselbe Aufmerksamkeit konkurrieren.
  Widget _kampf(HeroComputedSnapshot werte) => KartoAbschnitt(
    titel: 'Kampf',
    aktion: GefechtEinstieg(
      heroId: heroId,
      werte: werte,
      bestand: bestand,
      aktion: aktion,
      vorBearbeitung: vorHeldenbearbeitung,
    ),
    stufe: KartoFlaechenstufe.senke,
    symbol: Icons.shield_outlined,
    akzent: KartoAkzent.messing,
    // In einer weiten Kachel kommen die Kampfwerte neben die Probenchips.
    child: KartoKampfInhalt(
      proben: bestand.spielKampfproben(heroId: heroId, werte: werte),
      werte: werte,
    ),
  );

  Widget _effekte(BuildContext context, HeroComputedSnapshot werte) =>
      KartoAbschnitt(
        titel: 'Aktive Effekte',
        stufe: KartoFlaechenstufe.senke,
        symbol: Icons.auto_awesome_outlined,
        akzent: KartoAkzent.astral,
        aktion: TextButton(
          key: const ValueKey<String>('karto-spiel-effekte'),
          onPressed: () =>
              aktion(() => bestand.effekte(context: context, heroId: heroId)),
          child: const Text('Effekte verwalten'),
        ),
        child: bestand.spielEffekte(heroId: heroId, werte: werte),
      );

  Widget _begleiter(BuildContext context, HeroComputedSnapshot werte) =>
      KartoBegleiterAbschnitt(
        begleiter: werte.hero.companions,
        zustaende: werte.state.begleiterZustaende,
        // Bewusst ohne `aktion`-Guard: jeder schnelle Klick zählt.
        onWert: (begleiter, pool, aenderung) => bestand.begleiterWertAendern(
          context: context,
          ref: ref,
          heroId: heroId,
          begleiterId: begleiter.id,
          pool: pool,
          aenderung: aenderung,
        ),
        onVertrautenAktionen: (vertrauter) => aktion(() async {
          if (!await vorHeldenbearbeitung() || !context.mounted) return;
          await bestand.vertrautenAktionen(
            context: context,
            heroId: heroId,
            begleiterId: vertrauter.id,
          );
        }),
      );

  // Am Tisch zählen die letzten Würfe; die ganze Historie samt Filtern
  // öffnet „Alle anzeigen“ in einem eigenen Blatt. Die Größenstufe der Kachel
  // liest `KartoProtokollAbschnitt` selbst.
  Widget _protokoll(HeroComputedSnapshot werte) =>
      KartoProtokollAbschnitt(heroId: heroId, werte: werte, bestand: bestand);

  // Fehlertexte bleiben auch bei großer Schrift erreichbar.
  Widget _meldung(
    BuildContext context,
    String text, {
    required VoidCallback wiederholen,
  }) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(Abstand.bahn),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          TextButton(onPressed: wiederholen, child: const Text('Wiederholen')),
        ],
      ),
    ),
  );
}

/// Leiser Schluss der Spielansicht: Zierlinie und ein Satz.
///
/// Rein dekorativ; er schliesst die Seite ab, damit sie nicht mitten im
/// Protokoll aufhoert. Kein Knopf, keine Angabe — siehe die Negativpruefungen
/// in `test/ui2/spielen/karto_spielverlauf_test.dart`.
class _Abschluss extends StatelessWidget {
  const _Abschluss();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Abstand.rand, bottom: Abstand.block),
      child: Column(
        children: [
          const KartoZierlinie(maxBreite: 360),
          const SizedBox(height: Abstand.normal),
          Text(
            'Jeder Held hat eine Geschichte.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.legende,
          ),
        ],
      ),
    );
  }
}
