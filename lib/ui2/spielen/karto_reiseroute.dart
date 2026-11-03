import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseroute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_reiseroute_schreiben.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Wie viele Stationen die Kachel zeigt; alle weiteren stehen im Blatt.
const int kReiserouteKurz = 3;

/// Reiseroute als Kachel der Spielansicht: die jüngsten Stationen als
/// Zeitleiste, eine neue Station mit einem Tipp.
class KartoReiserouteKachel extends ConsumerStatefulWidget {
  /// Kachel für die [stationen] des Helden [heroId].
  const KartoReiserouteKachel({
    super.key,
    required this.heroId,
    required this.stationen,
  });

  /// ID im gemeinsam genutzten Heldenspeicher.
  final String heroId;

  /// Gespeicherte Stationen in Erfassungsreihenfolge.
  final List<HeroReiseStation> stationen;

  @override
  ConsumerState<KartoReiserouteKachel> createState() =>
      _KartoReiserouteKachelState();
}

class _KartoReiserouteKachelState extends ConsumerState<KartoReiserouteKachel>
    with KartoReiserouteSchreiben<KartoReiserouteKachel> {
  @override
  String get heroId => widget.heroId;

  @override
  Widget build(BuildContext context) {
    final etappen = reiseEtappen(widget.stationen);
    final juengste = etappen.length <= kReiserouteKurz
        ? etappen
        : etappen.sublist(etappen.length - kReiserouteKurz);
    final bedienbar = !gesperrt && !schreibt;
    final texte = Theme.of(context).textTheme;

    return KartoAbschnitt(
      titel: 'Reiseroute',
      symbol: Icons.route_outlined,
      aktion: TextButton.icon(
        key: const ValueKey<String>('karto-reise-station-neu'),
        onPressed: bedienbar ? stationAnlegen : null,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Station'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (etappen.isEmpty)
            Text(
              'Keine Station erfasst. Halte fest, wo der Held wann war.',
              style: texte.fliess.copyWith(color: context.karto.schriftLeise),
            )
          else
            KartoReiseZeitleiste(
              etappen: juengste,
              notizZeilen: 2,
              onStation: bedienbar ? stationBearbeiten : null,
            ),
          if (etappen.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const ValueKey<String>('karto-reise-alle'),
                onPressed: () =>
                    zeigeReiseroute(context: context, heroId: widget.heroId),
                child: Text(
                  etappen.length > kReiserouteKurz
                      ? 'Ganze Route (${etappen.length})'
                      : 'Ganze Route',
                ),
              ),
            ),
          if (fehler != null) _Fehler(fehler!),
        ],
      ),
    );
  }
}

/// Öffnet das Reiseroute-Blatt des Helden.
Future<void> zeigeReiseroute({
  required BuildContext context,
  required String heroId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.karto.blatt,
    constraints: const BoxConstraints(maxWidth: Breite.gross),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kKartoRadius)),
    ),
    builder: (context) => FractionallySizedBox(
      heightFactor: .9,
      child: KartoReiserouteBlatt(heroId: heroId),
    ),
  );
}

/// Die ganze Reiseroute: Übersicht, Filter nach Abenteuer und Zeitleiste.
///
/// Liest den Helden selbst (`heroComputedProvider`), damit jede Änderung
/// sofort erscheint.
class KartoReiserouteBlatt extends ConsumerStatefulWidget {
  /// Blatt für den Helden [heroId].
  const KartoReiserouteBlatt({super.key, required this.heroId});

  /// ID im gemeinsam genutzten Heldenspeicher.
  final String heroId;

  @override
  ConsumerState<KartoReiserouteBlatt> createState() =>
      _KartoReiserouteBlattState();
}

class _KartoReiserouteBlattState extends ConsumerState<KartoReiserouteBlatt>
    with KartoReiserouteSchreiben<KartoReiserouteBlatt> {
  @override
  String get heroId => widget.heroId;

  /// Gewähltes Abenteuer; `null` zeigt alle Stationen.
  String? _abenteuerId;

  @override
  Widget build(BuildContext context) {
    final held = ref.watch(heroComputedProvider(heroId)).asData?.value.hero;
    if (held == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final texte = Theme.of(context).textTheme;
    final karto = context.karto;
    final stationen = held.reiseStationen;
    // Ein inzwischen entferntes Abenteuer als Filter zeigt wieder alles.
    final filter =
        _abenteuerId != null &&
            stationen.any((s) => s.adventureId == _abenteuerId)
        ? _abenteuerId
        : null;
    final etappen = reiseEtappen(stationen, adventureId: filter);
    final tage = reiseTageGesamt(etappen);
    final abenteuerMitStationen = <HeroAdventureEntry>[
      for (final a in held.adventures)
        if (stationen.any((s) => s.adventureId == a.id)) a,
    ];
    final bedienbar = !gesperrt && !schreibt;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Abstand.bahn,
        0,
        Abstand.bahn,
        Abstand.bahn,
      ),
      children: [
        Row(
          children: [
            Expanded(child: Text('Reiseroute', style: texte.titel)),
            FilledButton.icon(
              key: const ValueKey<String>('karto-reise-blatt-station-neu'),
              onPressed: bedienbar ? stationAnlegen : null,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Station'),
            ),
          ],
        ),
        const SizedBox(height: Abstand.eng),
        Text(
          [
            switch (etappen.length) {
              0 => 'Keine Stationen',
              1 => '1 Station',
              final n => '$n Stationen',
            },
            if (tage != null) '$tage Tage unterwegs',
          ].join(' · '),
          style: texte.legende.copyWith(color: karto.schriftLeise),
        ),
        if (gesperrt)
          Padding(
            padding: const EdgeInsets.only(top: Abstand.normal),
            child: Text(
              'Während einer Planung ist die Reiseroute gesperrt.',
              style: texte.legende.copyWith(color: karto.wachs),
            ),
          ),
        if (abenteuerMitStationen.isNotEmpty) ...[
          const SizedBox(height: Abstand.weit),
          Wrap(
            spacing: Abstand.knapp,
            runSpacing: Abstand.knapp,
            children: [
              ChoiceChip(
                label: const Text('Alle'),
                selected: filter == null,
                onSelected: (_) => setState(() => _abenteuerId = null),
              ),
              for (final a in abenteuerMitStationen)
                ChoiceChip(
                  label: Text(
                    a.title.trim().isEmpty ? 'Ohne Titel' : a.title.trim(),
                  ),
                  selected: filter == a.id,
                  onSelected: (_) => setState(() => _abenteuerId = a.id),
                ),
            ],
          ),
        ],
        if (fehler != null) _Fehler(fehler!),
        const SizedBox(height: Abstand.block),
        if (etappen.isEmpty)
          Text(
            'Keine Station erfasst. Lege die erste über „Station“ an; Ort, Datum '
            'und Abenteuer werden aus dem laufenden Spiel vorgeschlagen.',
            style: texte.fliess.copyWith(color: karto.schriftLeise),
          )
        else
          KartoReiseZeitleiste(
            etappen: etappen,
            onStation: bedienbar ? stationBearbeiten : null,
            mitKartenlink: true,
          ),
      ],
    );
  }
}

/// Senkrechte Zeitleiste der Etappen: nummerierte Marken, verbunden durch
/// eine Linie, daneben Abstand, Datum, Ort und Notiz.
class KartoReiseZeitleiste extends StatelessWidget {
  /// Zeitleiste der [etappen] in der gegebenen Reihenfolge.
  const KartoReiseZeitleiste({
    super.key,
    required this.etappen,
    this.onStation,
    this.notizZeilen,
    this.mitKartenlink = false,
  });

  /// Darzustellende Etappen, bereits zeitlich geordnet.
  final List<ReiseEtappe> etappen;

  /// Öffnet die Bearbeitung; `null` zeigt nur an.
  final ValueChanged<HeroReiseStation>? onStation;

  /// Höchstzahl der Notizzeilen; `null` zeigt die ganze Notiz.
  final int? notizZeilen;

  /// Ob je Station ein Link auf die Avesmaps-Karte erscheint.
  final bool mitKartenlink;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < etappen.length; i++)
          _ZeitleistenEintrag(
            etappe: etappen[i],
            erster: i == 0,
            letzter: i == etappen.length - 1,
            notizZeilen: notizZeilen,
            mitKartenlink: mitKartenlink,
            onTap: onStation == null
                ? null
                : () => onStation!(etappen[i].station),
          ),
      ],
    );
  }
}

class _ZeitleistenEintrag extends StatelessWidget {
  const _ZeitleistenEintrag({
    required this.etappe,
    required this.erster,
    required this.letzter,
    required this.notizZeilen,
    required this.mitKartenlink,
    required this.onTap,
  });

  final ReiseEtappe etappe;
  final bool erster;
  final bool letzter;
  final int? notizZeilen;
  final bool mitKartenlink;
  final VoidCallback? onTap;

  static const double _marke = 26;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final station = etappe.station;
    final ort = station.ort.trim();
    final notiz = station.notiz.trim();
    final datum = reiseStationDatumText(station);
    final abstand = erster ? null : reiseEtappenAbstandText(etappe);
    final link = mitKartenlink ? avesmapsLink(ort) : null;

    final inhalt = Padding(
      padding: EdgeInsets.only(
        left: Abstand.weit,
        bottom: letzter ? 0 : Abstand.block,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (abstand != null)
            Text(
              abstand,
              style: texte.marke.copyWith(color: karto.schriftStumm),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ort.isEmpty ? 'Unbekannter Ort' : ort,
                  style: ort.isEmpty
                      ? texte.abschnitt.copyWith(color: karto.schriftLeise)
                      : texte.abschnitt,
                ),
              ),
              if (link != null)
                IconButton(
                  tooltip: 'Auf Avesmaps zeigen',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: () =>
                      launchUrl(link, mode: LaunchMode.externalApplication),
                ),
            ],
          ),
          if (datum != null)
            Text(
              datum,
              style: texte.etikett.copyWith(color: karto.schriftLeise),
            ),
          if (notiz.isNotEmpty) ...[
            const SizedBox(height: Abstand.eng),
            Text(
              notiz,
              style: texte.fliess,
              maxLines: notizZeilen,
              overflow: notizZeilen == null ? null : TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: ValueKey<String>('karto-reise-station-${station.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(kKartoRadiusKlein),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _marke,
                child: Column(
                  children: [
                    Container(
                      width: _marke,
                      height: _marke,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: letzter ? karto.meer : karto.feld,
                        border: Border.all(
                          color: karto.meer,
                          width: Strich.kueste,
                        ),
                      ),
                      child: Text(
                        '${etappe.nummer}',
                        style: texte.marke.copyWith(
                          color: letzter ? karto.schriftAufSignal : karto.meer,
                        ),
                      ),
                    ),
                    if (!letzter)
                      Expanded(
                        child: Container(
                          width: Strich.kueste,
                          color: karto.grat,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: inhalt),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fehler extends StatelessWidget {
  const _Fehler(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Abstand.normal),
    child: Text(
      text,
      style: Theme.of(context).textTheme.legende
          .copyWith(color: context.karto.siegel),
    ),
  );
}
