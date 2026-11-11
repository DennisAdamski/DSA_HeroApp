import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/kraeuter_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/aventurian_age_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kraeutersuche_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/meta_talent_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_probe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_sonderfertigkeit_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/ort_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/wildnis/karto_kraeutersuche_taetigkeit.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/wildnis/karto_wildnis_taetigkeit.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';

/// Die Tätigkeiten der Wildnis-Kachel in der Reihenfolge des Umschalters.
///
/// Eine neue Tätigkeit (Nahrung sammeln, Pirschjagd …) kommt als Unterklasse
/// von [KartoWildnisTaetigkeit] hierher; die Kachel selbst bleibt unverändert.
const List<KartoWildnisTaetigkeit> kartoWildnisTaetigkeiten =
    <KartoWildnisTaetigkeit>[KartoKraeutersucheTaetigkeit()];

/// Höchstzahl der Vorschauzeilen in einer normalen Kachel.
const int kWildnisVorschauKurz = 3;

/// Höchstzahl der Vorschauzeilen in einer weiten Kachel.
const int kWildnisVorschauWeit = 8;

/// Wildnis als Kachel der Spielansicht: Landschaft, Jahreszeit,
/// Geländekunde und Ortskenntnis aus dem Helden vorbelegen, die Probe über das
/// Würfelprotokoll würfeln und die Ausbeute der gewählten Tätigkeit zeigen.
///
/// Die Kachel schreibt nichts am Helden: Eingaben und Ergebnis leben nur im
/// Widget; ins Würfelprotokoll schreibt `gefechtsProbe` selbst. Alle Angaben
/// lassen sich von Hand ändern, auch Geländekunde und Ortskenntnis.
class KartoWildnisKachel extends ConsumerStatefulWidget {
  /// Kachel für den Helden [heroId] mit den gespeicherten [werte].
  const KartoWildnisKachel({
    super.key,
    required this.heroId,
    required this.werte,
    required this.bestand,
    required this.aktion,
    this.taetigkeiten = kartoWildnisTaetigkeiten,
  });

  /// ID im gemeinsam genutzten Heldenspeicher.
  final String heroId;

  /// Abgeleitete Werte des Helden (Talente, Eigenschaften, Standort).
  final HeroComputedSnapshot werte;

  /// Brücke zum Bestand; nur mit [KartoGefechtsAdapter] lässt sich würfeln.
  final KartoBestandsAdapter bestand;

  /// Geschützter Ausführungsweg für Dialoge (Re-Entrancy-Guard).
  final Future<void> Function(Future<void> Function() aktion) aktion;

  /// Wählbare Tätigkeiten.
  final List<KartoWildnisTaetigkeit> taetigkeiten;

  @override
  ConsumerState<KartoWildnisKachel> createState() => _KartoWildnisKachelState();
}

class _KartoWildnisKachelState extends ConsumerState<KartoWildnisKachel> {
  String? _taetigkeitId;
  String? _landschaft;
  Jahreszeit? _jahreszeit;
  int? _dauer;
  Gelaendekunde? _gelaendekunde;
  bool? _ortskenntnis;
  int _asp = 0;
  int _situativ = 0;
  final Map<String, String> _optionen = <String, String>{};
  WildnisErgebnis? _ergebnis;
  bool _wuerfelt = false;

  KartoWildnisTaetigkeit get _taetigkeit => widget.taetigkeiten.firstWhere(
    (t) => t.id == _taetigkeitId,
    orElse: () => widget.taetigkeiten.first,
  );

  // Jede Eingabe verwirft das Ergebnis: es gehörte zu den alten Angaben.
  void _aendere(VoidCallback aenderung) => setState(() {
    aenderung();
    _ergebnis = null;
  });

  void _waehleTaetigkeit(String id) => _aendere(() {
    _taetigkeitId = id;
    _landschaft = null;
    _dauer = null;
    _gelaendekunde = null;
    _ortskenntnis = null;
    _optionen.clear();
  });

  void _waehleLandschaft(String schluessel) => _aendere(() {
    _landschaft = schluessel;
    // Die Erkennung gilt je Landschaft; ein Handwert gehörte zur alten.
    _gelaendekunde = null;
    _ortskenntnis = null;
  });

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final karto = context.karto;
    final weit = KartoKachelSteuerung.istWeit(context);
    final werte = widget.werte;
    final taetigkeit = _taetigkeit;
    final daten = taetigkeit.beobachteDaten(ref);
    final orte =
        ref.watch(ortKatalogProvider).asData?.value.orte ??
        const <OrtEintrag>[];
    final katalog = ref
        .watch(heroRulesCatalogProvider(widget.heroId))
        .valueOrNull;

    final standort = werte.state.standort;
    final ort = findeOrt(standort, orte);
    final vorschlaege = ort == null
        ? const <WildnisLandschaft>[]
        : taetigkeit.landschaftenFuerOrt(ort);
    final landschaft = _gewaehlteLandschaft(taetigkeit, vorschlaege);

    final datum = resolveCurrentAdventureDate(werte.hero);
    final monat = datum?.month ?? '';
    final jahreszeit = _jahreszeit ?? jahreszeitFuerMonat(monat);

    final erkannt = landschaft == null
        ? WildnisSonderfertigkeiten.keine
        : werteWildnisSonderfertigkeitenAus(
            hero: werte.hero,
            landschaft: landschaft,
            standort: standort,
            catalog: katalog,
          );
    final gelaendekunde = _gelaendekunde ?? erkannt.gelaendekunde;
    final ortskenntnis = _ortskenntnis ?? erkannt.ortskenntnis;

    final dauer = _dauer ?? taetigkeit.dauern.first.stunden;
    final taw = computeMetaTalentBaseTaw(
      talentEntries: werte.hero.talents,
      componentTalentIds: taetigkeit.talentKomponenten,
    );

    KartoWildnisKontext? kontext;
    if (landschaft != null && jahreszeit != null && daten.hasValue) {
      kontext = _baueKontext(
        taetigkeit: taetigkeit,
        landschaft: landschaft,
        jahreszeit: jahreszeit,
        monat: monat,
        taw: taw,
        dauer: dauer,
        gelaendekunde: gelaendekunde,
        ortskenntnis: ortskenntnis,
        daten: daten.value,
      );
    }

    final KartoGefechtsAdapter? bruecke = switch (widget.bestand) {
      final KartoGefechtsAdapter gefechtsBruecke => gefechtsBruecke,
      _ => null,
    };
    final wurfKontext = kontext;

    return KartoAbschnitt(
      titel: 'Wildnis',
      symbol: Icons.forest_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.taetigkeiten.length > 1) ...[
            _taetigkeitWahl(taetigkeit),
            Abstand.luecke,
          ],
          _Marke(
            symbol: Icons.place_outlined,
            text: standort.trim().isEmpty
                ? 'Kein Standort erfasst'
                : 'Standort: ${standort.trim()}',
            leise: standort.trim().isEmpty,
          ),
          Abstand.luecke,
          _felder(
            weit: weit,
            kinder: [
              _auswahl(
                schluessel: 'landschaft',
                bezeichnung: 'Landschaft',
                wert: landschaft?.schluessel,
                hinweis: landschaft == null
                    ? (vorschlaege.length > 1
                          ? 'Mehrere passen zum Standort: bitte wählen.'
                          : 'Landschaft wählen.')
                    : null,
                eintraege: [
                  for (final l in <WildnisLandschaft>[
                    ...vorschlaege,
                    for (final l in taetigkeit.landschaften)
                      if (!vorschlaege.any((v) => v.schluessel == l.schluessel))
                        l,
                  ])
                    (
                      schluessel: l.schluessel,
                      text: vorschlaege.any((v) => v.schluessel == l.schluessel)
                          ? '${l.bezeichnung} (Standort)'
                          : l.bezeichnung,
                    ),
                ],
                onChanged: _waehleLandschaft,
              ),
              _auswahl(
                schluessel: 'jahreszeit',
                bezeichnung: datum == null || monat.isEmpty
                    ? 'Jahreszeit'
                    : 'Jahreszeit (${aventurianMonthLabel(monat)})',
                wert: jahreszeit?.name,
                hinweis: jahreszeit == null
                    ? 'Kein Datum im Abenteuer: bitte wählen.'
                    : null,
                eintraege: [
                  for (final j in Jahreszeit.values)
                    (schluessel: j.name, text: j.bezeichnung),
                ],
                onChanged: (name) => _aendere(
                  () => _jahreszeit = Jahreszeit.values.byName(name),
                ),
              ),
            ],
          ),
          Abstand.luecke,
          _sonderfertigkeiten(
            erkannt: erkannt,
            gelaendekunde: gelaendekunde,
            ortskenntnis: ortskenntnis,
            gelaendeVonHand: _gelaendekunde != null,
            ortVonHand: _ortskenntnis != null,
          ),
          Abstand.luecke,
          _felder(
            weit: weit,
            kinder: [
              _auswahl(
                schluessel: 'dauer',
                bezeichnung: 'Dauer',
                wert: '$dauer',
                eintraege: [
                  for (final d in taetigkeit.dauern)
                    (schluessel: '${d.stunden}', text: d.text),
                ],
                onChanged: (wert) => _aendere(() => _dauer = int.parse(wert)),
              ),
              for (final option in taetigkeit.optionen)
                if (option.sichtbar?.call(
                      kontext?.optionen ?? _effektiveOptionen(taetigkeit),
                    ) ??
                    true)
                  _optionsFeld(option, kontext),
            ],
          ),
          Abstand.luecke,
          _felder(
            weit: weit,
            kinder: [
              _Schritt(
                schluessel: 'asp',
                bezeichnung: 'Eingesetzte AsP (je 3 senken um 1)',
                wert: _asp,
                min: 0,
                max: 99,
                onChanged: (w) => _aendere(() => _asp = w),
              ),
              _Schritt(
                schluessel: 'situativ',
                bezeichnung: 'Weitere Erschwernis (negativ = leichter)',
                wert: _situativ,
                min: -20,
                max: 20,
                vorzeichen: true,
                onChanged: (w) => _aendere(() => _situativ = w),
              ),
            ],
          ),
          Abstand.luecke,
          _zusammenfassung(taetigkeit, kontext, werte.probenEigenschaften, taw),
          if (daten.hasError) ...[
            Abstand.luecke,
            Text(
              'Daten der Tätigkeit konnten nicht geladen werden: ${daten.error}',
              style: texte.fliess.copyWith(color: karto.siegel),
            ),
          ] else if (!daten.hasValue) ...[
            Abstand.luecke,
            Text(
              'Daten werden geladen …',
              style: texte.fliess.copyWith(color: karto.schriftLeise),
            ),
          ],
          Abstand.luecke,
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const ValueKey<String>('karto-wildnis-wuerfeln'),
              onPressed: wurfKontext != null && bruecke != null && !_wuerfelt
                  ? () => _wuerfeln(taetigkeit, wurfKontext, bruecke)
                  : null,
              icon: const Icon(Icons.casino_outlined),
              label: Text('${taetigkeit.titel} würfeln'),
            ),
          ),
          if (_ergebnis case final ergebnis?) ...[
            Abstand.luecke,
            _ErgebnisAnzeige(ergebnis: ergebnis),
          ],
          if (kontext != null) _vorschau(taetigkeit, kontext, weit),
        ],
      ),
    );
  }

  // Die gewählte Landschaft; ohne Wahl gilt ein eindeutiger Vorschlag.
  WildnisLandschaft? _gewaehlteLandschaft(
    KartoWildnisTaetigkeit taetigkeit,
    List<WildnisLandschaft> vorschlaege,
  ) {
    final schluessel = _landschaft;
    if (schluessel != null) {
      for (final l in taetigkeit.landschaften) {
        if (l.schluessel == schluessel) return l;
      }
    }
    return vorschlaege.length == 1 ? vorschlaege.single : null;
  }

  Map<String, String> _effektiveOptionen(KartoWildnisTaetigkeit taetigkeit) => {
    for (final o in taetigkeit.optionen)
      o.schluessel: _optionen[o.schluessel] ?? o.standard,
  };

  // Baut den Kontext; Wahlen mit abhängigen Antworten (etwa das Kraut der
  // Landschaft) fallen auf ihren Standard zurück, wenn die Antwort nicht mehr
  // zur Landschaft passt.
  KartoWildnisKontext _baueKontext({
    required KartoWildnisTaetigkeit taetigkeit,
    required WildnisLandschaft landschaft,
    required Jahreszeit jahreszeit,
    required String monat,
    required int taw,
    required int dauer,
    required Gelaendekunde gelaendekunde,
    required bool ortskenntnis,
    required Object? daten,
  }) {
    KartoWildnisKontext mit(Map<String, String> optionen) =>
        KartoWildnisKontext(
          landschaft: landschaft,
          jahreszeit: jahreszeit,
          monat: monat,
          taw: taw,
          dauerStunden: dauer,
          eigenschaften: _eigenschaften(taetigkeit),
          gelaendekunde: gelaendekunde,
          ortskenntnis: ortskenntnis,
          eingesetzteAsp: _asp,
          situativeErschwernis: _situativ,
          optionen: Map<String, String>.unmodifiable(optionen),
          daten: daten,
        );

    final optionen = _effektiveOptionen(taetigkeit);
    final vorlaeufig = mit(optionen);
    for (final option in taetigkeit.optionen) {
      final dynamisch = option.dynamischeWerte;
      if (dynamisch == null) continue;
      final gueltig = dynamisch(vorlaeufig);
      if (!gueltig.any((w) => w.schluessel == optionen[option.schluessel])) {
        optionen[option.schluessel] = option.standard;
      }
    }
    return mit(optionen);
  }

  List<ProbeTargetValue> _eigenschaften(KartoWildnisTaetigkeit taetigkeit) {
    final probe = widget.werte.probenEigenschaften;
    return [
      for (final code in taetigkeit.eigenschaften)
        ProbeTargetValue(
          label: attributeCodeKey(code),
          value: _eigenschaftswert(probe, code),
        ),
    ];
  }

  int _eigenschaftswert(Attributes werte, AttributeCode code) => switch (code) {
    AttributeCode.mu => werte.mu,
    AttributeCode.kl => werte.kl,
    AttributeCode.inn => werte.inn,
    AttributeCode.ch => werte.ch,
    AttributeCode.ff => werte.ff,
    AttributeCode.ge => werte.ge,
    AttributeCode.ko => werte.ko,
    AttributeCode.kk => werte.kk,
  };

  Future<void> _wuerfeln(
    KartoWildnisTaetigkeit taetigkeit,
    KartoWildnisKontext kontext,
    KartoGefechtsAdapter bruecke,
  ) async {
    setState(() => _wuerfelt = true);
    try {
      await widget.aktion(() async {
        // Die Probe schreibt selbst ins Würfelprotokoll; der Modifikator ist im
        // Dialog gesperrt, die Erschwernis stammt aus der Regelfunktion.
        final probe = await bruecke.gefechtsProbe(
          context: context,
          ref: ref,
          heroId: widget.heroId,
          request: taetigkeit.baueProbe(kontext),
        );
        if (probe == null || !mounted) return;
        setState(
          () => _ergebnis = taetigkeit.auswerten(
            kontext,
            probe,
            roller: RandomDiceRoller(),
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _wuerfelt = false);
    }
  }

  Widget _taetigkeitWahl(KartoWildnisTaetigkeit aktuell) {
    return Wrap(
      spacing: Abstand.normal,
      runSpacing: Abstand.eng,
      children: [
        for (final t in widget.taetigkeiten)
          ChoiceChip(
            key: ValueKey<String>('karto-wildnis-taetigkeit-${t.id}'),
            avatar: Icon(t.symbol, size: 16),
            label: Text(t.titel),
            selected: t.id == aktuell.id,
            onSelected: (_) => _waehleTaetigkeit(t.id),
          ),
      ],
    );
  }

  // Felder nebeneinander in der weiten Kachel, sonst untereinander.
  Widget _felder({required bool weit, required List<Widget> kinder}) {
    if (kinder.isEmpty) return const SizedBox.shrink();
    if (!weit) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < kinder.length; i++) ...[
            if (i > 0) const SizedBox(height: Abstand.weit),
            kinder[i],
          ],
        ],
      );
    }
    return Wrap(
      spacing: Abstand.weit,
      runSpacing: Abstand.weit,
      children: [for (final kind in kinder) SizedBox(width: 260, child: kind)],
    );
  }

  Widget _auswahl({
    required String schluessel,
    required String bezeichnung,
    required String? wert,
    required List<({String schluessel, String text})> eintraege,
    required ValueChanged<String> onChanged,
    String? hinweis,
  }) {
    final gueltig = eintraege.any((e) => e.schluessel == wert) ? wert : null;
    return DropdownButtonFormField<String>(
      key: ValueKey<String>('karto-wildnis-$schluessel-${gueltig ?? ''}'),
      initialValue: gueltig,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: bezeichnung,
        helperText: hinweis,
        helperMaxLines: 2,
      ),
      items: [
        for (final e in eintraege)
          DropdownMenuItem<String>(
            value: e.schluessel,
            child: Text(e.text, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (neu) {
        if (neu != null) onChanged(neu);
      },
    );
  }

  Widget _optionsFeld(KartoWildnisOption option, KartoWildnisKontext? kontext) {
    final eintraege = kontext != null && option.dynamischeWerte != null
        ? option.dynamischeWerte!(kontext)
        : option.werte;
    return _auswahl(
      schluessel: 'option-${option.schluessel}',
      bezeichnung: option.bezeichnung,
      wert:
          kontext?.optionen[option.schluessel] ??
          _optionen[option.schluessel] ??
          option.standard,
      eintraege: eintraege,
      onChanged: (neu) => _aendere(() => _optionen[option.schluessel] = neu),
    );
  }

  Widget _sonderfertigkeiten({
    required WildnisSonderfertigkeiten erkannt,
    required Gelaendekunde gelaendekunde,
    required bool ortskenntnis,
    required bool gelaendeVonHand,
    required bool ortVonHand,
  }) {
    final texte = Theme.of(context).textTheme;
    final leise = texte.etikett.copyWith(color: context.karto.schriftLeise);
    final gelaendeQuelle = gelaendeVonHand
        ? 'von Hand gesetzt'
        : erkannt.gelaendekundeHerkunft == null
        ? 'keine passende Sonderfertigkeit'
        : 'aus ${erkannt.gelaendekundeHerkunft}';
    final ortQuelle = ortVonHand
        ? 'von Hand gesetzt'
        : erkannt.ortskenntnisHerkunft == null
        ? 'keine Ortskenntnis für diesen Standort'
        : 'aus ${erkannt.ortskenntnisHerkunft}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Geländekunde', style: texte.etikett),
        const SizedBox(height: Abstand.eng),
        Wrap(
          spacing: Abstand.normal,
          runSpacing: Abstand.eng,
          children: [
            for (final stufe in Gelaendekunde.values)
              ChoiceChip(
                key: ValueKey<String>('karto-wildnis-gelaende-${stufe.name}'),
                label: Text(switch (stufe) {
                  Gelaendekunde.keine => 'Keine',
                  Gelaendekunde.aehnlich => 'Ähnlich (−1)',
                  Gelaendekunde.passend => 'Passend (−3)',
                }),
                selected: gelaendekunde == stufe,
                onSelected: (_) => _aendere(() => _gelaendekunde = stufe),
              ),
          ],
        ),
        Text(gelaendeQuelle, style: leise),
        const SizedBox(height: Abstand.normal),
        Row(
          children: [
            Switch(
              key: const ValueKey<String>('karto-wildnis-ortskenntnis'),
              value: ortskenntnis,
              onChanged: (wert) => _aendere(() => _ortskenntnis = wert),
            ),
            const SizedBox(width: Abstand.normal),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ortskenntnis (−7)', style: texte.etikett),
                  Text(ortQuelle, style: leise),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _zusammenfassung(
    KartoWildnisTaetigkeit taetigkeit,
    KartoWildnisKontext? kontext,
    Attributes eigenschaften,
    int taw,
  ) {
    final texte = Theme.of(context).textTheme;
    final eig = _eigenschaften(taetigkeit);
    final probe = eig.map((e) => '${e.label} ${e.value}').join(' · ');
    if (kontext == null) {
      return Text(
        'TaW $taw · $probe',
        style: texte.fliess.copyWith(color: context.karto.schriftLeise),
      );
    }
    final erschwernis = taetigkeit.erschwernis(kontext);
    final tawBeiDauer = taetigkeit.tawBeiDauer(kontext);
    return KartoFlaeche(
      stufe: KartoFlaechenstufe.senke,
      klein: true,
      innen: const EdgeInsets.all(Abstand.normal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            key: const ValueKey<String>('karto-wildnis-zusammenfassung'),
            'TaW $tawBeiDauer · Erschwernis ${_mitVorzeichen(erschwernis)}',
            style: texte.wert,
          ),
          Text(
            '$probe · ${taetigkeit.regelHinweis}',
            style: texte.etikett.copyWith(color: context.karto.schriftLeise),
          ),
        ],
      ),
    );
  }

  Widget _vorschau(
    KartoWildnisTaetigkeit taetigkeit,
    KartoWildnisKontext kontext,
    bool weit,
  ) {
    final zeilen = taetigkeit.vorschau(kontext);
    if (zeilen.isEmpty) return const SizedBox.shrink();
    final grenze = weit ? kWildnisVorschauWeit : kWildnisVorschauKurz;
    final texte = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: Abstand.weit),
      child: Column(
        key: const ValueKey<String>('karto-wildnis-vorschau'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Mögliche Funde', style: texte.etikett),
          const SizedBox(height: Abstand.eng),
          for (final zeile in zeilen.take(grenze))
            Padding(
              padding: const EdgeInsets.only(bottom: Abstand.eng),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: zeile.titel,
                      style: texte.fliess.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (zeile.detail.isNotEmpty)
                      TextSpan(
                        text: '  ${zeile.detail}',
                        style: texte.fliess.copyWith(
                          color: context.karto.schriftLeise,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (zeilen.length > grenze)
            Text(
              '… und ${zeilen.length - grenze} weitere (Titel antippen für die '
              'große Ansicht)',
              style: texte.etikett.copyWith(color: context.karto.schriftLeise),
            ),
        ],
      ),
    );
  }
}

String _mitVorzeichen(int wert) =>
    wert > 0 ? '+$wert' : (wert < 0 ? '−${-wert}' : '0');

/// Kleine Zeile mit Symbol, etwa für den Standort.
class _Marke extends StatelessWidget {
  const _Marke({required this.symbol, required this.text, this.leise = false});

  final IconData symbol;
  final String text;
  final bool leise;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    return Row(
      children: [
        Icon(symbol, size: 16, color: karto.schriftLeise),
        const SizedBox(width: Abstand.knapp),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.etikett
                .copyWith(color: leise ? karto.schriftLeise : karto.schrift),
          ),
        ),
      ],
    );
  }
}

/// Zahl mit Minus- und Plusknopf.
class _Schritt extends StatelessWidget {
  const _Schritt({
    required this.schluessel,
    required this.bezeichnung,
    required this.wert,
    required this.min,
    required this.max,
    required this.onChanged,
    this.vorzeichen = false,
  });

  final String schluessel;
  final String bezeichnung;
  final int wert;
  final int min;
  final int max;
  final bool vorzeichen;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(bezeichnung, style: texte.etikett)),
        IconButton(
          key: ValueKey<String>('karto-wildnis-$schluessel-minus'),
          tooltip: 'Weniger',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove),
          onPressed: wert > min ? () => onChanged(wert - 1) : null,
        ),
        SizedBox(
          width: 36,
          child: Text(
            key: ValueKey<String>('karto-wildnis-$schluessel-wert'),
            vorzeichen ? _mitVorzeichen(wert) : '$wert',
            textAlign: TextAlign.center,
            style: texte.wert,
          ),
        ),
        IconButton(
          key: ValueKey<String>('karto-wildnis-$schluessel-plus'),
          tooltip: 'Mehr',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add),
          onPressed: wert < max ? () => onChanged(wert + 1) : null,
        ),
      ],
    );
  }
}

/// Ergebnis einer Wildnisprobe: Erfolg, TaP*, Würfe und die Ausbeute.
class _ErgebnisAnzeige extends StatelessWidget {
  const _ErgebnisAnzeige({required this.ergebnis});

  final WildnisErgebnis ergebnis;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final farbe = ergebnis.erfolg ? karto.moos : karto.wachs;
    return KartoFlaeche(
      key: const ValueKey<String>('karto-wildnis-ergebnis'),
      stufe: KartoFlaechenstufe.senke,
      klein: true,
      innen: const EdgeInsets.all(Abstand.weit),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                ergebnis.erfolg
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
                size: 20,
                color: farbe,
              ),
              const SizedBox(width: Abstand.normal),
              Expanded(
                child: Text(
                  ergebnis.erfolg
                      ? 'Gelungen · ${ergebnis.tapStern} TaP*'
                      : 'Misslungen',
                  style: texte.wert.copyWith(color: farbe),
                ),
              ),
            ],
          ),
          Text(
            'Würfe ${ergebnis.probe.diceValues.join(' / ')} · '
            'Erschwernis ${_mitVorzeichen(ergebnis.erschwernis)}',
            style: texte.etikett.copyWith(color: karto.schriftLeise),
          ),
          if (ergebnis.zeilen.isNotEmpty) ...[
            const SizedBox(height: Abstand.normal),
            for (final zeile in ergebnis.zeilen)
              Padding(
                padding: const EdgeInsets.only(bottom: Abstand.eng),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: zeile.titel,
                        style: texte.fliess.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (zeile.detail.isNotEmpty)
                        TextSpan(
                          text: '  ${zeile.detail}',
                          style: texte.fliess,
                        ),
                    ],
                  ),
                ),
              ),
          ],
          if (ergebnis.hinweis.isNotEmpty)
            Text(
              ergebnis.hinweis,
              style: texte.fliess.copyWith(color: karto.schriftLeise),
            ),
        ],
      ),
    );
  }
}
