import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/data/karte/karten_kachel_manifest.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_ortsdetails.dart';
import 'package:dsa_heldenverwaltung/domain/hero_unterwegs.dart';
import 'package:dsa_heldenverwaltung/domain/ortsfakten.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ortsfakten_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reisezeit_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_lage_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_providers.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_routen_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/karten_providers.dart';
import 'package:dsa_heldenverwaltung/state/ort_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_blatt.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_reise_ablauf.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_standort.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/standort/karto_lageskizze.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Breite der Bezeichnungsspalte der Fakten (wie in der Infotafel von
/// Avesmaps).
const double kStandortFaktBreite = 96;

/// Der Standort des Helden als Kachel der Spielansicht, nach dem Vorbild der
/// Ortsansicht von Avesmaps: Kopf mit Ortsklasse und Gebiet, Lageskizze,
/// Fakten, Orte in der Nähe und Rücklinks.
///
/// Kartendaten kommen erst nach dem Knopf „Kartendaten laden“ (bzw. dem
/// Öffnen eines Ortsfelds) von Avesmaps; eine früher geladene Tagesliste
/// liegt lokal und wirkt ohne Netz. Ohne Kartendaten zeigt die Kachel, was das
/// Ortsverzeichnis der Wiki Aventurica weiß. Geschrieben wird nur der
/// Standort, über [onSpeichern] (frischer Zustandsweg der Spielansicht).
///
/// Die Lageskizze ist ein Ausschnitt der Aventurien-Karte ohne Reiseroute;
/// mit [heroId] öffnet ein Tipp die große Karte, in der sich der Standort
/// über [onSpeichern] auf einen anderen Ort setzen lässt.
///
/// Mit [onReiseZustand] plant „Reise planen“ eine Reise vom Standort aus;
/// ist der Held [unterwegs], zeigt die Kachel Reisetag und die Knöpfe
/// „Angekommen“, „Anhalten“ und „Abbrechen“.
class KartoStandortKachel extends ConsumerWidget {
  /// Kachel für den gespeicherten [standort].
  const KartoStandortKachel({
    super.key,
    required this.standort,
    this.standortOrtId = '',
    required this.onSpeichern,
    this.oeffneLink = oeffneExtern,
    this.heroId,
    this.unterwegs,
    this.onReiseZustand,
  });

  /// Gespeicherter Standort; leer, solange keiner festgehalten ist.
  final String standort;

  /// Gespeicherter Verweis auf den Avesmaps-Ort (`HeroState.standortOrtId`);
  /// unterscheidet gleichnamige Orte, solange er zum Namen passt.
  final String standortOrtId;

  /// Speichert den neuen Standort; ein leerer Text entfernt ihn.
  final KartoStandortSetzer onSpeichern;

  /// Öffnet Links außerhalb der App; in Tests ersetzbar.
  final KartoLinkOeffner oeffneLink;

  /// Held für die große Karte; ohne ihn öffnet die Skizze nichts.
  final String? heroId;

  /// Laufende Reise, oder `null`.
  final HeroUnterwegs? unterwegs;

  /// Schreibt Reise und Standort; ohne ihn bietet die Kachel keine Reise an.
  final KartoReiseZustandSetzer? onReiseZustand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = bereinigeStandort(standort);
    final verzeichnis = ref.watch(ortsverzeichnisProvider);
    final liste = ref.watch(avesmapsOrteProvider);
    final avesmaps = liste.asData?.value ?? const <AvesmapsOrt>[];
    final angefordert = ref.watch(avesmapsOrteAnforderungProvider);
    final abrufbar = ref.watch(avesmapsClientProvider) != null;
    // Der Verweis wählt unter gleichnamigen Einträgen; ohne ihn (oder vor dem
    // Laden der Avesmaps-Liste, die erst die Kennungen bringt) der Name.
    final eintrag =
        eintragZumVerweis(name, standortOrtId, verzeichnis) ??
        findeOrt(name, verzeichnis);
    final ort = ortZumStandort(
      name,
      verzeichnis,
      avesmaps,
      ortId: standortOrtId,
    );
    final details = ort == null
        ? null
        : ref.watch(avesmapsOrtsdetailsProvider(ort.id)).asData?.value;
    final manifest = ref.watch(kartenKachelManifestProvider).asData?.value;
    final held = heroId;
    // Kurzfakten und Bauwerke aus der Wiki; zum Avesmaps-Ort gehört der
    // verknüpfte Eintrag des Ortsverzeichnisses.
    final auskunft = ortsAuskunft(
      ort == null ? eintrag : (ortsEintragZu(ort, verzeichnis) ?? eintrag),
      ref.watch(ortsfaktenProvider).asData?.value ?? const OrtsfaktenKatalog(),
    );

    void fordereAn() =>
        ref.read(avesmapsOrteAnforderungProvider.notifier).fordereAn();

    Future<void> bearbeiten() async {
      // Wie beim Ortsfeld: das Öffnen der Eingabe fordert die Ortsliste an.
      fordereAn();
      final neu = await zeigeStandortDialog(context, standort: name);
      if (neu == null) return;
      await onSpeichern(neu);
    }

    return KartoAbschnitt(
      titel: 'Standort',
      symbol: Icons.place_outlined,
      aktion: IconButton(
        key: const ValueKey<String>('karto-standort-kachel-aendern'),
        tooltip: name.isEmpty ? 'Standort festhalten' : 'Standort ändern',
        icon: const Icon(Icons.edit_location_alt_outlined),
        onPressed: bearbeiten,
      ),
      child: _MitReise(
        heroId: held,
        unterwegs: unterwegs,
        setzer: onReiseZustand,
        planbar: name.isNotEmpty,
        child: name.isEmpty
            ? _OhneStandort(onFesthalten: bearbeiten)
            : _Ortsansicht(
                name: name,
                verzeichnis: verzeichnis,
                eintrag: eintrag,
                ort: ort,
                details: details,
                avesmaps: avesmaps,
                laedt: angefordert && liste.isLoading,
                ladenMoeglich:
                    abrufbar &&
                    !liste.isLoading &&
                    (!angefordert || avesmaps.isEmpty),
                onLaden: fordereAn,
                oeffneLink: oeffneLink,
                manifest: manifest,
                auskunft: auskunft,
                onKarte: held == null
                    ? null
                    : () => zeigeKarte(
                        context,
                        heroId: held,
                        fokus: ort,
                        mitRoute: false,
                        onStandortSetzen: onSpeichern,
                        onReiseZustand: onReiseZustand,
                      ),
              ),
      ),
    );
  }
}

/// Reise zum Standort: Tafel einer laufenden Reise über der Ortsansicht,
/// sonst „Reise planen“ darunter.
class _MitReise extends ConsumerWidget {
  const _MitReise({
    required this.heroId,
    required this.unterwegs,
    required this.setzer,
    required this.planbar,
    required this.child,
  });

  final String? heroId;
  final HeroUnterwegs? unterwegs;
  final KartoReiseZustandSetzer? setzer;
  final bool planbar;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final held = heroId;
    final u = unterwegs;
    final setzer = this.setzer;
    if (held == null || setzer == null) return child;
    if (u == null) {
      if (!planbar) return child;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: Abstand.normal),
          TextButton.icon(
            key: const ValueKey<String>('karto-standort-kachel-reise-planen'),
            onPressed: () =>
                reisePlanen(context, ref, heroId: held, zustandSetzen: setzer),
            icon: const Icon(Icons.hiking),
            label: const Text('Reise planen'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _UnterwegsTafel(heroId: held, unterwegs: u, setzer: setzer),
        const SizedBox(height: Abstand.weit),
        child,
      ],
    );
  }
}

/// Eine laufende Reise: Ziel, Reisetag, Plan und die Knöpfe zum Beenden.
class _UnterwegsTafel extends ConsumerWidget {
  const _UnterwegsTafel({
    required this.heroId,
    required this.unterwegs,
    required this.setzer,
  });

  final String heroId;
  final HeroUnterwegs unterwegs;
  final KartoReiseZustandSetzer setzer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final werte = ref.watch(heroComputedProvider(heroId)).asData?.value;
    final wege = ref.watch(avesmapsReisewegeProvider).asData?.value;
    final anfrage = unterwegsAnfrage(unterwegs);
    final lage = werte == null
        ? null
        : unterwegsLage(
            unterwegs,
            heute: reiseHeute(werte.hero),
            linie: anfrage == null
                ? const <(double, double)>[]
                : wege?[anfrage.schluessel]?.linie ??
                      const <(double, double)>[],
          );
    final plan = reisePlanText(unterwegs.anreise);
    final abreise = unterwegs.anreise.abreise;
    final zeile = <String>[
      if (unterwegs.vonOrt.isNotEmpty) 'von ${unterwegs.vonOrt}',
      if (abreise.hasContent) 'ab ${abreise.anzeigeText}',
      ?plan,
    ].join(' · ');
    return DecoratedBox(
      key: const ValueKey<String>('karto-standort-kachel-unterwegs'),
      decoration: BoxDecoration(
        color: karto.meer.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(kKartoRadiusKlein),
        border: Border.all(color: karto.meer.withValues(alpha: .35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Abstand.weit),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Unterwegs nach ${unterwegs.ziel}',
              key: const ValueKey<String>(
                'karto-standort-kachel-unterwegs-ziel',
              ),
              style: texte.abschnitt,
            ),
            if (lage?.text case final text?)
              Text(
                text,
                key: const ValueKey<String>(
                  'karto-standort-kachel-unterwegs-tag',
                ),
                style: texte.fliess,
              ),
            if (zeile.isNotEmpty)
              Text(
                zeile,
                style: texte.legende.copyWith(color: karto.schriftLeise),
              ),
            const SizedBox(height: Abstand.normal),
            Wrap(
              spacing: Abstand.knapp,
              runSpacing: Abstand.knapp,
              children: [
                FilledButton.tonalIcon(
                  key: const ValueKey<String>(
                    'karto-standort-kachel-angekommen',
                  ),
                  onPressed: () => reiseAngekommen(
                    context,
                    ref,
                    heroId: heroId,
                    u: unterwegs,
                    zustandSetzen: setzer,
                  ),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Angekommen'),
                ),
                TextButton(
                  key: const ValueKey<String>('karto-standort-kachel-anhalten'),
                  onPressed: () => reiseAnhalten(
                    context,
                    ref,
                    heroId: heroId,
                    u: unterwegs,
                    zustandSetzen: setzer,
                  ),
                  child: const Text('Anhalten'),
                ),
                TextButton(
                  key: const ValueKey<String>(
                    'karto-standort-kachel-reise-abbrechen',
                  ),
                  onPressed: () => reiseAbbrechen(
                    context,
                    u: unterwegs,
                    zustandSetzen: setzer,
                  ),
                  child: const Text('Reise abbrechen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OhneStandort extends StatelessWidget {
  const _OhneStandort({required this.onFesthalten});

  final VoidCallback onFesthalten;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kein Standort erfasst.',
          key: const ValueKey<String>('karto-standort-kachel-leer'),
          style: Theme.of(context).textTheme.fliess
              .copyWith(color: karto.schriftLeise),
        ),
        Abstand.luecke,
        FilledButton.tonalIcon(
          key: const ValueKey<String>('karto-standort-kachel-festhalten'),
          onPressed: onFesthalten,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Standort festhalten'),
        ),
      ],
    );
  }
}

class _Ortsansicht extends StatelessWidget {
  const _Ortsansicht({
    required this.name,
    required this.verzeichnis,
    required this.eintrag,
    required this.ort,
    required this.details,
    required this.avesmaps,
    required this.laedt,
    required this.ladenMoeglich,
    required this.onLaden,
    required this.oeffneLink,
    required this.manifest,
    required this.auskunft,
    required this.onKarte,
  });

  final String name;
  final List<OrtEintrag> verzeichnis;
  final OrtEintrag? eintrag;
  final AvesmapsOrt? ort;
  final AvesmapsOrtsdetails? details;
  final List<AvesmapsOrt> avesmaps;
  final bool laedt;
  final bool ladenMoeglich;
  final VoidCallback onLaden;
  final KartoLinkOeffner oeffneLink;
  final KartenKachelManifest? manifest;
  final OrtsAuskunft auskunft;
  final VoidCallback? onKarte;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final weit = KartoKachelSteuerung.istWeit(context);
    final ort = this.ort;
    final eintrag = this.eintrag;
    final gebiete = gebietsZeile(details);
    final reich = reichDesOrts(details);
    final fakten = auskunft.fakten;

    // Ein Satz statt einer Reihung: „Metropole in Alt-Gareth“.
    final art = ort != null
        ? ort.artBezeichnung
        : (eintrag == null
              ? ''
              : (eintrag.unterart.isNotEmpty
                    ? eintrag.unterart
                    : eintrag.art.bezeichnung));
    final lage = gebiete.isNotEmpty
        ? gebiete.split(' · ').first
        : (eintrag?.region ?? '');
    final untertitel = <String>[
      if (art.isNotEmpty) art,
      if (lage.isNotEmpty) art.isEmpty ? lage : 'in $lage',
    ].join(' ');

    final angaben = <(String, String)>[
      if (fakten != null && fakten.oberhaupt.isNotEmpty)
        ('Oberhaupt', fakten.oberhaupt),
      if (fakten != null && fakten.herrschaftsform.isNotEmpty)
        ('Herrschaft', fakten.herrschaftsform),
      if (gebiete.isNotEmpty) ('Lage', gebiete),
      if (reich.isNotEmpty && !gebiete.contains(reich)) ('Reich', reich),
      if (gebiete.isEmpty && eintrag != null && eintrag.region.isNotEmpty)
        ('Region', eintrag.region),
    ];

    final kartenLink = ort != null
        ? avesmapsOrtLink(
            wikiUrl: details?.wikiUrl ?? '',
            id: ort.id,
            name: ort.name,
          )
        : (kartenlinkSinnvoll(name, verzeichnis) ? avesmapsLink(name) : null);
    final wikiUrl = details?.wikiUrl ?? '';
    final wikiLink =
        sichererWikiLink(wikiUrl) ?? wikiAventuricaLink(name, verzeichnis);

    final nahe = ort == null
        ? const <NaherOrt>[]
        : _merker.nahe(ort, avesmaps, weit ? kNaheOrteWeit : kNaheOrteKurz);
    final bauwerkGrenze = weit ? kBauwerkeWeit : kBauwerkeKurz;
    final wichtige = auskunft.wichtigeOrte;
    final gottheiten = tempelNachGottheit(auskunft.tempel);

    void oeffne(Uri? link) => _oeffnen(context, link);

    // Kopf: Name und Einordnung, daneben die Wege nach draußen.
    final kopf = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ort?.name ?? eintrag?.name ?? name,
                key: const ValueKey<String>('karto-standort-kachel-name'),
                style: texte.titel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (untertitel.isNotEmpty)
                Text(
                  untertitel,
                  key: const ValueKey<String>(
                    'karto-standort-kachel-untertitel',
                  ),
                  style: texte.fliess.copyWith(color: karto.schriftLeise),
                ),
            ],
          ),
        ),
        if (kartenLink != null)
          IconButton(
            key: const ValueKey<String>('karto-standort-kachel-karte'),
            tooltip: 'Auf Avesmaps öffnen',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => oeffne(kartenLink),
          ),
        if (wikiLink != null)
          IconButton(
            key: const ValueKey<String>('karto-standort-kachel-wiki'),
            tooltip: 'Im Wiki Aventurica lesen',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => oeffne(wikiLink),
          ),
      ],
    );

    final karte = ort != null
        ? KartoLageskizze(
            skizze: _merker.skizze(ort, avesmaps),
            orte: avesmaps,
            manifest: manifest,
            onTap: onKarte,
          )
        : _Kartenhinweis(
            laedt: laedt,
            ladenMoeglich: ladenMoeglich && avesmaps.isEmpty,
            nichtGefunden: avesmaps.isNotEmpty,
            onLaden: onLaden,
          );

    // Steckbrief unter der Karte: Einwohner, Herrschaft, Wege, Tempel.
    final steckbrief = <Widget>[
      if (fakten != null) ?_Einwohner.aus(fakten),
      if (angaben.isNotEmpty) ...[
        const SizedBox(height: Abstand.normal),
        for (final (bezeichnung, wert) in angaben)
          _Fakt(bezeichnung: bezeichnung, wert: wert),
      ],
      if (fakten != null && fakten.verkehrswege.isNotEmpty) ...[
        const _Rubrik('Wege'),
        Wrap(
          spacing: Abstand.knapp,
          runSpacing: Abstand.knapp,
          children: [for (final weg in fakten.verkehrswege) _Marke(text: weg)],
        ),
      ],
      if (gottheiten.isNotEmpty) ...[
        const _Rubrik('Tempel'),
        Wrap(
          spacing: Abstand.knapp,
          runSpacing: Abstand.knapp,
          children: [
            for (final (gottheit, tempel) in gottheiten)
              _Marke(
                key: ValueKey<String>('karto-standort-kachel-tempel-$gottheit'),
                text: gottheit,
                anzahl: tempel.length,
                onTap: tempel.length == 1
                    ? () => oeffne(bauwerkLink(tempel.single))
                    : () => _zeigeTempel(context, gottheit, tempel, oeffne),
              ),
          ],
        ),
      ],
    ];

    // Umgebung: bedeutende Bauwerke und Nachbarorte. In der weiten Kachel
    // steht sie als eigene Spalte bündig mit der Karte.
    final spalten = weit && ort != null;
    final umgebung = <Widget>[
      if (wichtige.isNotEmpty) ...[
        _Rubrik('Wichtige Orte', oben: !spalten),
        for (final bauwerk in wichtige.take(bauwerkGrenze))
          _BauwerkZeile(
            bauwerk: bauwerk,
            onTap: () => oeffne(bauwerkLink(bauwerk)),
          ),
        if (wichtige.length > bauwerkGrenze)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey<String>('karto-standort-kachel-orte-mehr'),
              onPressed: wikiLink == null ? null : () => oeffne(wikiLink),
              child: Text('Weitere ${wichtige.length - bauwerkGrenze} im Wiki'),
            ),
          ),
      ],
      if (nahe.isNotEmpty) ...[
        _Rubrik('In der Nähe', oben: !spalten || wichtige.isNotEmpty),
        for (final naher in nahe)
          _NaheZeile(
            naher: naher,
            onTap: () =>
                oeffne(avesmapsOrtLink(id: naher.ort.id, name: naher.ort.name)),
          ),
      ],
    ];

    final nachladen = <Widget>[
      if (ort != null && ladenMoeglich)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey<String>('karto-standort-kachel-details'),
            onPressed: onLaden,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Gebiete und Wiki-Link laden'),
          ),
        ),
    ];

    final quelle = Text(
      kOrtsdatenQuellen,
      style: texte.marke.copyWith(color: karto.schriftStumm),
    );

    // Weit: Karte und Steckbrief links, Umgebung rechts, wie die Infotafel
    // von Avesmaps neben der Karte.
    final nebeneinander = spalten && umgebung.isNotEmpty;
    if (nebeneinander) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          kopf,
          const SizedBox(height: Abstand.weit),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    karte,
                    ...nachladen,
                    const SizedBox(height: Abstand.weit),
                    ...steckbrief,
                  ],
                ),
              ),
              const SizedBox(width: Abstand.bahn),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: umgebung,
                ),
              ),
            ],
          ),
          const SizedBox(height: Abstand.block),
          quelle,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        kopf,
        const SizedBox(height: Abstand.weit),
        karte,
        ...nachladen,
        if (steckbrief.isNotEmpty) const SizedBox(height: Abstand.weit),
        ...steckbrief,
        ...umgebung,
        const SizedBox(height: Abstand.block),
        quelle,
      ],
    );
  }

  Future<void> _zeigeTempel(
    BuildContext context,
    String gottheit,
    List<OrtsBauwerk> tempel,
    void Function(Uri) oeffne,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.karto.blatt,
      builder: (blatt) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            Abstand.bahn,
            0,
            Abstand.bahn,
            Abstand.bahn,
          ),
          children: [
            Text(
              gottheit == 'Weitere' ? 'Weitere Tempel' : 'Tempel: $gottheit',
              style: Theme.of(blatt).textTheme.abschnitt,
            ),
            const SizedBox(height: Abstand.normal),
            for (final t in tempel)
              _BauwerkZeile(
                bauwerk: t,
                onTap: () {
                  Navigator.of(blatt).pop();
                  oeffne(bauwerkLink(t));
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _oeffnen(BuildContext context, Uri? link) async {
    if (link == null) return;
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

// Platz der Skizze, solange der Standort keine Kartenposition hat.
class _Kartenhinweis extends StatelessWidget {
  const _Kartenhinweis({
    required this.laedt,
    required this.ladenMoeglich,
    required this.nichtGefunden,
    required this.onLaden,
  });

  final bool laedt;
  final bool ladenMoeglich;
  final bool nichtGefunden;
  final VoidCallback onLaden;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final leise = Theme.of(context).textTheme.fliess
        .copyWith(color: karto.schriftLeise);
    if (laedt) {
      return Text(
        'Kartendaten werden geladen …',
        key: const ValueKey<String>('karto-standort-kachel-laedt'),
        style: leise,
      );
    }
    if (ladenMoeglich) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lageskizze und Orte in der Nähe brauchen die Ortsliste von '
            'Avesmaps. Sie wird höchstens einmal am Tag geladen und lokal '
            'gespeichert.',
            style: leise,
          ),
          const SizedBox(height: Abstand.normal),
          FilledButton.tonalIcon(
            key: const ValueKey<String>('karto-standort-kachel-laden'),
            onPressed: onLaden,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Kartendaten laden'),
          ),
        ],
      );
    }
    return Text(
      nichtGefunden
          ? 'Dieser Ort steht nicht auf der Karte von Avesmaps.'
          : 'Keine Kartendaten vorhanden.',
      key: const ValueKey<String>('karto-standort-kachel-ohne-karte'),
      style: leise,
    );
  }
}

class _Fakt extends StatelessWidget {
  const _Fakt({required this.bezeichnung, required this.wert});

  final String bezeichnung;
  final String wert;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Abstand.eng),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: kStandortFaktBreite,
            child: Text(
              bezeichnung,
              style: texte.etikett.copyWith(color: context.karto.schriftLeise),
            ),
          ),
          Expanded(
            child: Text(
              wert,
              key: ValueKey<String>('karto-standort-kachel-fakt-$bezeichnung'),
              style: texte.fliess,
            ),
          ),
        ],
      ),
    );
  }
}

/// Überschrift eines Abschnitts der Ortsansicht mit Haarlinie bis zum Rand.
class _Rubrik extends StatelessWidget {
  const _Rubrik(this.text, {this.oben = true});

  final String text;

  /// Ob die Rubrik Abstand nach oben hält (nicht am Spaltenanfang).
  final bool oben;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    return Padding(
      padding: EdgeInsets.only(
        top: oben ? Abstand.block : 0,
        bottom: Abstand.knapp,
      ),
      child: Row(
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.etikett
                .copyWith(color: karto.schrift),
          ),
          const SizedBox(width: Abstand.normal),
          Expanded(
            child: Container(height: Strich.hoehenlinie, color: karto.grat),
          ),
        ],
      ),
    );
  }
}

/// Einwohnerzahl als Leitzeile des Steckbriefs, der Wiki-Zusatz leise
/// darunter.
class _Einwohner extends StatelessWidget {
  const _Einwohner({required this.zahl, required this.zusatz});

  /// Nur wenn es etwas zu zeigen gibt.
  static _Einwohner? aus(SiedlungsFakten fakten) {
    final (zahl, zusatz) = einwohnerTeile(fakten);
    if (zahl == null && zusatz.isEmpty) return null;
    return _Einwohner(zahl: zahl, zusatz: zusatz);
  }

  final String? zahl;
  final String zusatz;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              if (zahl != null) TextSpan(text: zahl, style: texte.wertGross),
              TextSpan(
                text: zahl != null ? ' Einwohner' : 'Einwohner: $zusatz',
                style: texte.fliess.copyWith(color: karto.schriftLeise),
              ),
            ],
          ),
          key: const ValueKey<String>('karto-standort-kachel-einwohner'),
        ),
        if (zahl != null && zusatz.isNotEmpty)
          Text(
            zusatz,
            key: const ValueKey<String>(
              'karto-standort-kachel-einwohner-zusatz',
            ),
            style: texte.legende.copyWith(color: karto.schriftLeise),
          ),
      ],
    );
  }
}

/// Kleine Marke für Wege und Gottheiten; mit [anzahl] über 1 steht die Zahl
/// in Messing dahinter.
class _Marke extends StatelessWidget {
  const _Marke({super.key, required this.text, this.anzahl = 1, this.onTap});

  final String text;
  final int anzahl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final inhalt = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Abstand.normal,
        vertical: Abstand.eng,
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: text, style: texte.etikett),
            if (anzahl > 1)
              TextSpan(
                text: '  $anzahl',
                style: texte.etikett.copyWith(
                  color: karto.messing,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
    return Material(
      color: karto.feld,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kKartoRadiusKlein),
        side: BorderSide(color: karto.grat, width: Strich.grat),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? inhalt : InkWell(onTap: onTap, child: inhalt),
    );
  }
}

/// Höchstzahl der wichtigen Orte in einer schmalen Kachel.
const int kBauwerkeKurz = 4;

/// Höchstzahl der wichtigen Orte in einer weiten Kachel.
const int kBauwerkeWeit = 8;

/// Symbol zur Art eines Bauwerks; die Art bleibt daneben als Text stehen.
IconData _bauwerkSymbol(OrtsBauwerk bauwerk) {
  final art = bauwerk.art.toLowerCase();
  if (istTempel(bauwerk)) return Icons.brightness_7_outlined;
  if (art.contains('burg') ||
      art.contains('festung') ||
      art.contains('zitadelle') ||
      art.contains('garnison') ||
      art.contains('kaserne') ||
      art.contains('schloss')) {
    return Icons.castle_outlined;
  }
  if (art.contains('akademie') || art.contains('universit')) {
    return Icons.school_outlined;
  }
  if (art.contains('hafen') ||
      art.contains('werft') ||
      art.contains('leucht')) {
    return Icons.anchor_outlined;
  }
  if (art.contains('markt') ||
      art.contains('kontor') ||
      art.contains('bank') ||
      art.contains('gilde')) {
    return Icons.storefront_outlined;
  }
  if (art.contains('taverne') ||
      art.contains('gasthaus') ||
      art.contains('herberge') ||
      art.contains('karawanserei')) {
    return Icons.local_bar_outlined;
  }
  if (art.contains('theater') ||
      art.contains('arena') ||
      art.contains('museum')) {
    return Icons.theater_comedy_outlined;
  }
  if (art.contains('grab') || art.contains('boronanger')) {
    return Icons.local_florist_outlined;
  }
  return Icons.account_balance_outlined;
}

class _BauwerkZeile extends StatelessWidget {
  const _BauwerkZeile({required this.bauwerk, required this.onTap});

  final OrtsBauwerk bauwerk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final zeile = bauwerkZeile(bauwerk);
    return InkWell(
      key: ValueKey<String>(
        'karto-standort-kachel-bauwerk-${bauwerk.wikiSeite}',
      ),
      onTap: onTap,
      borderRadius: BorderRadius.circular(kKartoRadiusKlein),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Abstand.knapp),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1, right: Abstand.normal),
              child: Icon(
                _bauwerkSymbol(bauwerk),
                size: 18,
                color: karto.messing,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bauwerk.name,
                    style: texte.fliess,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (zeile.isNotEmpty)
                    Text(
                      zeile,
                      style: texte.legende.copyWith(color: karto.schriftLeise),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NaheZeile extends StatelessWidget {
  const _NaheZeile({required this.naher, required this.onTap});

  final NaherOrt naher;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    return InkWell(
      key: ValueKey<String>('karto-standort-kachel-nahe-${naher.ort.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(kKartoRadiusKlein),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Abstand.knapp),
        child: Row(
          children: [
            // Der Pfeil zeigt vom Standort zum Nachbarort.
            Tooltip(
              message: naher.richtung.bezeichnung,
              child: Transform.rotate(
                angle: naher.richtung.index * math.pi / 4,
                child: Icon(Icons.north, size: 16, color: karto.meer),
              ),
            ),
            const SizedBox(width: Abstand.normal),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: naher.ort.name, style: texte.fliess),
                    TextSpan(
                      text: '  ${naher.ort.artBezeichnung}',
                      style: texte.legende.copyWith(color: karto.schriftLeise),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Abstand.normal),
            Text(
              formatiereMeilen(naher.meilen),
              style: texte.etikett.copyWith(color: karto.schriftLeise),
            ),
          ],
        ),
      ),
    );
  }
}

// Merkt sich die letzten Rechnungen über das ganze Ortsverzeichnis, damit
// ein Neuaufbau der Kachel (Theme, Breite, Details) nicht jedes Mal über
// alle Orte läuft. Gilt, solange Liste, Ort und Grenze gleich bleiben.
final _Merker _merker = _Merker();

class _Merker {
  List<AvesmapsOrt>? _naheListe;
  String? _naheOrt;
  int? _naheGrenze;
  List<NaherOrt> _nahe = const <NaherOrt>[];

  List<AvesmapsOrt>? _skizzeListe;
  String? _skizzeOrt;
  Lageskizze? _skizze;

  List<NaherOrt> nahe(AvesmapsOrt ort, List<AvesmapsOrt> orte, int grenze) {
    if (!identical(_naheListe, orte) ||
        _naheOrt != ort.id ||
        _naheGrenze != grenze) {
      _nahe = orteInDerNaehe(ort, orte, limit: grenze);
      _naheListe = orte;
      _naheOrt = ort.id;
      _naheGrenze = grenze;
    }
    return _nahe;
  }

  Lageskizze skizze(AvesmapsOrt ort, List<AvesmapsOrt> orte) {
    final vorhanden = _skizze;
    if (vorhanden != null &&
        identical(_skizzeListe, orte) &&
        _skizzeOrt == ort.id) {
      return vorhanden;
    }
    final neu = lageskizze(ort, orte);
    _skizze = neu;
    _skizzeListe = orte;
    _skizzeOrt = ort.id;
    return neu;
  }
}
