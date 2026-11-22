import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_route.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/domain/ortsfakten.dart';
import 'package:dsa_heldenverwaltung/rules/derived/karten_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ortsfakten_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseroute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseweg_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reisezeit_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_lage_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_providers.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_routen_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/karten_providers.dart';
import 'package:dsa_heldenverwaltung/state/ort_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karte.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_stil.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_held_schreiben.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_reise_ablauf.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_reiseroute_schreiben.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_standort.dart';

/// Halbe Kantenlänge des Ausschnitts um einen Fokusort in Karteneinheiten
/// (90 Meilen).
const double kKartenFokusHalb = 30;

/// Speichert einen neuen Standort des Helden (frischer Zustandsweg der
/// Spielansicht, legt bei Ortswechsel eine Station an).
typedef KartoStandortSetzer = Future<void> Function(String standort);

/// Öffnet die Aventurien-Karte des Helden [heroId] im Vollbild, auf Wunsch
/// um den Ort [fokus].
///
/// [mitRoute] bestimmt, ob die Reiseroute beim Öffnen sichtbar ist; im Blatt
/// lässt sie sich umschalten. Mit [onStandortSetzen] bietet die Infotafel
/// „Standort hierher“ an, mit [onReiseZustand] „Hierher reisen“.
Future<void> zeigeKarte(
  BuildContext context, {
  required String heroId,
  AvesmapsOrt? fokus,
  bool mitRoute = true,
  KartoStandortSetzer? onStandortSetzen,
  KartoReiseZustandSetzer? onReiseZustand,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => KartoKartenBlatt(
        heroId: heroId,
        fokus: fokus,
        mitRoute: mitRoute,
        onStandortSetzen: onStandortSetzen,
        onReiseZustand: onReiseZustand,
      ),
    ),
  );
}

/// Die Aventurien-Karte im Vollbild: Route und Standort des Helden auf dem
/// Kartenbild (bzw. ohne Kartenbild auf Papier), zoombar, mit Infotafel zu
/// Ort oder Station.
///
/// Liest den Helden selbst (`heroComputedProvider`), damit jede Änderung
/// sofort erscheint. Beim Öffnen fordert das Blatt das Ortsverzeichnis von
/// Avesmaps an, wie das Reiseroute-Blatt. Stationen bearbeitet es über
/// [KartoReiserouteSchreiben] (frisch, gesperrt während einer Planung).
class KartoKartenBlatt extends ConsumerStatefulWidget {
  /// Blatt für den Helden [heroId].
  const KartoKartenBlatt({
    super.key,
    required this.heroId,
    this.fokus,
    this.mitRoute = true,
    this.onStandortSetzen,
    this.onReiseZustand,
    this.oeffneLink = oeffneExtern,
  });

  /// ID im gemeinsam genutzten Heldenspeicher.
  final String heroId;

  /// Ort, um den die Karte aufgeht; ohne ihn Route und Standort.
  final AvesmapsOrt? fokus;

  /// Ob die Reiseroute beim Öffnen sichtbar ist.
  final bool mitRoute;

  /// Setzt den Standort auf einen Ort der Karte; `null` bietet es nicht an.
  final KartoStandortSetzer? onStandortSetzen;

  /// Schreibt Reise und Standort; mit ihm bietet die Infotafel „Hierher
  /// reisen“ an (Reiseplaner).
  final KartoReiseZustandSetzer? onReiseZustand;

  /// Öffnet Links außerhalb der App; in Tests ersetzbar.
  final KartoLinkOeffner oeffneLink;

  @override
  ConsumerState<KartoKartenBlatt> createState() => _KartoKartenBlattState();
}

class _KartoKartenBlattState extends ConsumerState<KartoKartenBlatt>
    with
        KartoHeldSchreiben<KartoKartenBlatt>,
        KartoReiserouteSchreiben<KartoKartenBlatt> {
  final GlobalKey<KartoKarteState> _karte = GlobalKey<KartoKarteState>();
  KartenTreffer? _treffer;
  late bool _route = widget.mitRoute;
  bool _setztStandort = false;

  @override
  String get heroId => widget.heroId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      ref.read(avesmapsOrteAnforderungProvider.notifier).fordereAn();
    });
  }

  @override
  Widget build(BuildContext context) {
    final werte = ref.watch(heroComputedProvider(heroId)).asData?.value;
    final orte =
        ref.watch(avesmapsOrteProvider).asData?.value ?? const <AvesmapsOrt>[];
    final verzeichnis = ref.watch(ortsverzeichnisProvider);
    final manifest = ref.watch(kartenKachelManifestProvider).asData?.value;
    final wege =
        ref.watch(avesmapsReisewegeProvider).asData?.value ??
        const <String, AvesmapsRoute>{};
    final etappen = werte == null
        ? const <ReiseEtappe>[]
        : reiseEtappen(werte.hero.reiseStationen);
    final punkte = !_route
        ? const <KartenRoutenPunkt>[]
        : kartenRoutenPunkte(etappen, wege: wege);
    final unterwegs = werte?.state.unterwegs;
    // Unterwegs steht der Reisende an der geschätzten Lage auf dem Weg.
    final lage = unterwegs == null
        ? null
        : unterwegsLage(
            unterwegs,
            heute: reiseHeute(werte!.hero),
            linie: switch (unterwegsAnfrage(unterwegs)) {
              final a? => wege[a.schluessel]?.linie ?? const [],
              null => const <(double, double)>[],
            },
          );
    final standort = lage != null && lage.hatKartenposition
        ? AvesmapsOrt(
            id: 'unterwegs',
            name: 'Unterwegs nach ${unterwegs!.ziel}',
            x: lage.kartenX!,
            y: lage.kartenY!,
          )
        : werte == null
        ? null
        : ortZumStandort(werte.state.standort, verzeichnis, orte);
    final fokus = widget.fokus;
    final treffer = _treffer;
    final auswahl = switch (treffer) {
      KartenTrefferOrt(:final ort) => ort.id,
      KartenTrefferStation(:final station) => station.id,
      null => null,
    };

    return Scaffold(
      backgroundColor: KartenFarben.papier,
      appBar: AppBar(title: const Text('Aventurien')),
      body: Stack(
        children: [
          Positioned.fill(
            child: KartoKarte(
              key: _karte,
              orte: orte,
              routenPunkte: punkte,
              standort: standort,
              manifest: manifest,
              start: fokus == null
                  ? null
                  : KartenRechteck.um(fokus.x, fokus.y, kKartenFokusHalb),
              auswahl: auswahl,
              onTreffer: (t) => setState(() => _treffer = t),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              children: [
                KartoKartenKnopf(
                  key: const ValueKey<String>('karto-karte-plus'),
                  symbol: Icons.add,
                  tooltip: 'Näher',
                  onPressed: () => _karte.currentState?.zoomeUm(1),
                ),
                const SizedBox(height: 6),
                KartoKartenKnopf(
                  key: const ValueKey<String>('karto-karte-minus'),
                  symbol: Icons.remove,
                  tooltip: 'Weiter weg',
                  onPressed: () => _karte.currentState?.zoomeUm(-1),
                ),
                const SizedBox(height: 12),
                KartoKartenKnopf(
                  key: const ValueKey<String>('karto-karte-route-umschalten'),
                  symbol: _route ? Icons.layers : Icons.layers_outlined,
                  tooltip: _route
                      ? 'Reiseroute ausblenden'
                      : 'Reiseroute einblenden',
                  onPressed: () => setState(() {
                    _route = !_route;
                    if (!_route && _treffer is KartenTrefferStation) {
                      _treffer = null;
                    }
                  }),
                ),
                if (_route) ...[
                  const SizedBox(height: 6),
                  KartoKartenKnopf(
                    key: const ValueKey<String>('karto-karte-route'),
                    symbol: Icons.route_outlined,
                    tooltip: 'Route und Standort zeigen',
                    onPressed: () => _karte.currentState?.einpassen(),
                  ),
                ],
                if (standort != null) ...[
                  const SizedBox(height: 6),
                  KartoKartenKnopf(
                    key: const ValueKey<String>('karto-karte-standort'),
                    symbol: Icons.my_location,
                    tooltip: 'Zum Standort',
                    onPressed: () =>
                        _karte.currentState?.zeige(standort.x, standort.y),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            left: 140,
            child: Align(
              alignment: Alignment.bottomRight,
              child: KartoKartenNennung(manifest: manifest),
            ),
          ),
          if (treffer != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 56,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _Infotafel(
                    treffer: treffer,
                    bearbeitbar: !gesperrt && !schreibt,
                    standortName: werte?.state.standort ?? '',
                    etappe: switch (treffer) {
                      KartenTrefferStation(:final station) =>
                        etappen
                            .where((e) => e.station.id == station.id)
                            .firstOrNull,
                      _ => null,
                    },
                    wege: wege,
                    onReiseweg: (etappe) async {
                      await reisewegWaehlen(etappe);
                    },
                    onStandortSetzen:
                        widget.onStandortSetzen == null || _setztStandort
                        ? null
                        : _standortSetzen,
                    onHierherReisen:
                        widget.onReiseZustand == null ||
                            _setztStandort ||
                            unterwegs != null ||
                            (werte?.state.standort ?? '').trim().isEmpty
                        ? null
                        : _hierherReisen,
                    fehler: fehler,
                    oeffneLink: widget.oeffneLink,
                    onSchliessen: () => setState(() => _treffer = null),
                    onBearbeiten: (station) async {
                      await stationBearbeiten(station);
                      if (mounted) setState(() => _treffer = null);
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _hierherReisen(AvesmapsOrt ort) async {
    final setzer = widget.onReiseZustand;
    if (setzer == null || _setztStandort) return;
    setState(() => _setztStandort = true);
    try {
      await reisePlanen(
        context,
        ref,
        heroId: heroId,
        zustandSetzen: setzer,
        ziel: ReiseOrt(
          name: ort.name,
          ortId: ort.id,
          kartenX: ort.x,
          kartenY: ort.y,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _setztStandort = false;
          _treffer = null;
        });
      }
    }
  }

  Future<void> _standortSetzen(String ort) async {
    final setzer = widget.onStandortSetzen;
    if (setzer == null || _setztStandort) return;
    setState(() => _setztStandort = true);
    try {
      await setzer(ort);
    } finally {
      if (mounted) {
        setState(() {
          _setztStandort = false;
          _treffer = null;
        });
      }
    }
  }
}

/// Infotafel zu einem getroffenen Ort oder einer Station, in den Farben der
/// Infotafel von Avesmaps.
class _Infotafel extends ConsumerWidget {
  const _Infotafel({
    required this.treffer,
    required this.bearbeitbar,
    required this.standortName,
    required this.onStandortSetzen,
    required this.onHierherReisen,
    required this.etappe,
    required this.wege,
    required this.onReiseweg,
    required this.fehler,
    required this.oeffneLink,
    required this.onSchliessen,
    required this.onBearbeiten,
  });

  final KartenTreffer treffer;
  final bool bearbeitbar;

  /// Gespeicherter Standort; „Standort hierher“ fehlt für genau diesen Ort.
  final String standortName;

  /// Setzt den Standort; `null`, solange es nicht geht.
  final ValueChanged<String>? onStandortSetzen;

  /// Plant eine Reise zum Ort; `null`, solange es nicht geht.
  final ValueChanged<AvesmapsOrt>? onHierherReisen;

  /// Etappe zur getroffenen Station, oder `null`.
  final ReiseEtappe? etappe;

  /// Gemerkte Reisewege.
  final Map<String, AvesmapsRoute> wege;

  /// Öffnet die Wahl des Reisewegs.
  final ValueChanged<ReiseEtappe> onReiseweg;
  final String? fehler;
  final KartoLinkOeffner oeffneLink;
  final VoidCallback onSchliessen;
  final ValueChanged<HeroReiseStation> onBearbeiten;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const titel = TextStyle(
      fontFamily: kKartenSchrift,
      fontSize: 18,
      color: KartenFarben.text,
    );
    const leise = TextStyle(
      fontFamily: kKartenSchrift,
      fontSize: 13,
      height: 1.35,
      color: KartenFarben.textLeise,
    );
    const fliess = TextStyle(
      fontFamily: kKartenSchrift,
      fontSize: 14,
      height: 1.4,
      color: KartenFarben.text,
    );

    final inhalt = <Widget>[];
    final knoepfe = <Widget>[];
    switch (treffer) {
      case KartenTrefferOrt(:final ort):
        final details = ref
            .watch(avesmapsOrtsdetailsProvider(ort.id))
            .asData
            ?.value;
        final gebiete = gebietsZeile(details);
        final auskunft = ortsAuskunft(
          ortsEintragZu(ort, ref.watch(ortsverzeichnisProvider)),
          ref.watch(ortsfaktenProvider).asData?.value ??
              const OrtsfaktenKatalog(),
        );
        final fakten = auskunft.fakten;
        final einwohner = fakten == null ? '' : einwohnerAnzeige(fakten);
        inhalt.addAll(<Widget>[
          Text(
            ort.name,
            key: const ValueKey<String>('karto-karte-info-name'),
            style: titel,
          ),
          Text(
            <String>[
              ort.artBezeichnung,
              if (gebiete.isNotEmpty) gebiete,
            ].join(' · '),
            style: leise,
          ),
          if (einwohner.isNotEmpty || (fakten?.oberhaupt ?? '').isNotEmpty)
            const SizedBox(height: 6),
          if (einwohner.isNotEmpty)
            Text(
              'Einwohner: $einwohner',
              key: const ValueKey<String>('karto-karte-info-einwohner'),
              style: fliess,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if ((fakten?.oberhaupt ?? '').isNotEmpty)
            Text(
              'Oberhaupt: ${fakten!.oberhaupt}',
              style: fliess,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          for (final (titel, liste) in <(String, List<OrtsBauwerk>)>[
            ('Tempel', auskunft.tempel),
            ('Wichtig', auskunft.wichtigeOrte),
          ])
            if (liste.isNotEmpty)
              Text(
                '$titel: ${liste.take(3).map((b) => b.name).join(', ')}'
                '${liste.length > 3 ? ' und ${liste.length - 3} weitere' : ''}',
                style: leise,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        ]);
        final karte = avesmapsOrtLink(
          wikiUrl: details?.wikiUrl ?? '',
          id: ort.id,
          name: ort.name,
        );
        final wiki = sichererWikiLink(details?.wikiUrl ?? '');
        _hierherKnopf(knoepfe, ort.name);
        final reisen = onHierherReisen;
        if (reisen != null &&
            bereinigeStandort(ort.name) != bereinigeStandort(standortName)) {
          knoepfe.add(
            _TafelKnopf(
              key: const ValueKey<String>('karto-karte-info-reisen'),
              symbol: Icons.hiking,
              text: 'Hierher reisen',
              onPressed: () => reisen(ort),
            ),
          );
        }
        if (karte != null) {
          knoepfe.add(
            _TafelKnopf(
              key: const ValueKey<String>('karto-karte-info-avesmaps'),
              symbol: Icons.open_in_new,
              text: 'Auf Avesmaps',
              onPressed: () => _oeffnen(context, karte),
            ),
          );
        }
        if (wiki != null) {
          knoepfe.add(
            _TafelKnopf(
              symbol: Icons.menu_book_outlined,
              text: 'Wiki Aventurica',
              onPressed: () => _oeffnen(context, wiki),
            ),
          );
        }
      case KartenTrefferStation(:final station, :final nummer):
        final datum = reiseStationDatumText(station);
        inhalt.addAll(<Widget>[
          Text(
            station.ort.trim().isEmpty ? 'Station $nummer' : station.ort.trim(),
            key: const ValueKey<String>('karto-karte-info-name'),
            style: titel,
          ),
          Text(<String>['Station $nummer', ?datum].join(' · '), style: leise),
          if (_anreiseZeile() case final zeile?)
            Text(
              zeile,
              key: const ValueKey<String>('karto-karte-info-reiseweg'),
              style: leise,
            ),
          if (station.notiz.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              station.notiz.trim(),
              style: fliess,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ]);
        _hierherKnopf(knoepfe, station.ort);
        final etappe = this.etappe;
        if (etappe != null && reisewegAnfrageFuer(etappe) != null) {
          knoepfe.add(
            _TafelKnopf(
              key: const ValueKey<String>('karto-karte-info-reiseweg-knopf'),
              symbol: Icons.alt_route,
              text: 'Reiseweg',
              onPressed: bearbeitbar ? () => onReiseweg(etappe) : null,
            ),
          );
        }
        knoepfe.add(
          _TafelKnopf(
            key: const ValueKey<String>('karto-karte-info-bearbeiten'),
            symbol: Icons.edit_outlined,
            text: 'Bearbeiten',
            onPressed: bearbeitbar ? () => onBearbeiten(station) : null,
          ),
        );
    }

    return Material(
      color: KartenFarben.tafel,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: KartenFarben.rahmen),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...inhalt,
                  if (knoepfe.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 6, children: knoepfe),
                  ],
                  if (fehler != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      fehler!,
                      style: leise.copyWith(color: const Color(0xFF9D3A2E)),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              key: const ValueKey<String>('karto-karte-info-schliessen'),
              tooltip: 'Schließen',
              visualDensity: VisualDensity.compact,
              color: KartenFarben.textLeise,
              icon: const Icon(Icons.close),
              onPressed: onSchliessen,
            ),
          ],
        ),
      ),
    );
  }

  /// Anreise zur Station: der gemerkte Weg, sonst die Luftlinie.
  String? _anreiseZeile() {
    final etappe = this.etappe;
    if (etappe == null || etappe.vorherige == null) return null;
    final weg = reisewegFuer(etappe, wege);
    final von = etappe.vorherige!.ort.trim();
    final herkunft = von.isEmpty ? 'Anreise' : 'Von $von';
    if (weg != null) return '$herkunft: ${reisewegText(weg)}';
    final meilen = etappe.meilenSeitVorher;
    if (meilen == null) return null;
    return '$herkunft: ${meilen.round()} Meilen Luftlinie';
  }

  /// „Standort hierher“, außer für einen leeren Ort oder den Standort selbst.
  void _hierherKnopf(List<Widget> knoepfe, String ort) {
    final name = bereinigeStandort(ort);
    final setzer = onStandortSetzen;
    if (name.isEmpty || name == bereinigeStandort(standortName)) return;
    knoepfe.add(
      _TafelKnopf(
        key: const ValueKey<String>('karto-karte-info-hierher'),
        symbol: Icons.person_pin_circle_outlined,
        text: 'Standort hierher',
        onPressed: setzer == null ? null : () => setzer(name),
      ),
    );
  }

  Future<void> _oeffnen(BuildContext context, Uri link) async {
    final bote = ScaffoldMessenger.maybeOf(context);
    var geoeffnet = false;
    try {
      geoeffnet = await oeffneLink(link);
    } catch (_) {
      geoeffnet = false;
    }
    if (!geoeffnet) {
      bote?.showSnackBar(
        const SnackBar(content: Text('Der Link konnte nicht geöffnet werden.')),
      );
    }
  }
}

/// Knopf der Infotafel im Stil von Avesmaps (taupe-braun mit hellem Text).
class _TafelKnopf extends StatelessWidget {
  const _TafelKnopf({
    super.key,
    required this.symbol,
    required this.text,
    required this.onPressed,
  });

  final IconData symbol;
  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: KartenFarben.knopf,
        foregroundColor: KartenFarben.knopfText,
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontFamily: kKartenSchrift, fontSize: 13),
      ),
      onPressed: onPressed,
      icon: Icon(symbol, size: 16),
      label: Text(text),
    );
  }
}
