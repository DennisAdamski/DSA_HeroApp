import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/avesmaps_route.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseweg_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reisezeit_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_providers.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_routen_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_datum_felder.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_ort_feld.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_reiseplan_bausteine.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Ergebnis des Reiseplaners: wohin, nach welchem Plan, mit welcher Ankunft
/// und ob der Held sofort ankommt oder aufbricht.
class KartoReiseplanErgebnis {
  /// Erstellt das Ergebnis.
  const KartoReiseplanErgebnis({
    required this.von,
    required this.nach,
    required this.anreise,
    required this.ankunft,
    required this.adventureId,
    required this.abenteuerDatumSetzen,
    required this.aufbrechen,
  });

  /// Ausgangsort (der Standort).
  final ReiseOrt von;

  /// Ziel.
  final ReiseOrt nach;

  /// Wege, Optimierung, Abreise und Plan.
  final HeroReiseAnreise anreise;

  /// Ankunft (geplant oder geändert).
  final HeroAdventureDateValue ankunft;

  /// Laufendes Abenteuer, leer ohne.
  final String adventureId;

  /// Ob das Datum des Abenteuers auf die Ankunft springt.
  final bool abenteuerDatumSetzen;

  /// `true`: Der Held bricht auf und ist unterwegs; `false`: Er kommt sofort
  /// an.
  final bool aufbrechen;
}

/// Öffnet den Reiseplaner für den Helden [held] am [standort].
///
/// [ziel] belegt „Nach“ vor (etwa der Ort der Karte). Liefert `null` bei
/// Abbruch; der Planer schreibt selbst nichts.
Future<KartoReiseplanErgebnis?> zeigeReiseplaner(
  BuildContext context, {
  required HeroSheet held,
  required String standort,
  String standortOrtId = '',
  ReiseOrt? ziel,
}) {
  return showDialog<KartoReiseplanErgebnis>(
    context: context,
    builder: (_) => KartoReiseplaner(
      held: held,
      standort: standort,
      standortOrtId: standortOrtId,
      ziel: ziel,
    ),
  );
}

/// Reise vom Standort zu einem Ziel planen: Weg von Avesmaps, Dauer nach
/// Regelwerk, änderbare Ankunft.
class KartoReiseplaner extends ConsumerStatefulWidget {
  /// Erstellt den Planer.
  const KartoReiseplaner({
    super.key,
    required this.held,
    required this.standort,
    this.standortOrtId = '',
    this.ziel,
    this.orte,
  });

  /// Der Held beim Öffnen (für Vorschläge).
  final HeroSheet held;

  /// Gespeicherter Standort.
  final String standort;

  /// Verweis des Standorts auf den Avesmaps-Ort; leer ohne Verweis.
  final String standortOrtId;

  /// Vorbelegtes Ziel (etwa der Ort der Karte), oder `null`.
  final ReiseOrt? ziel;

  /// Festes Ortsverzeichnis (Tests); sonst die laufende Auswahlliste.
  final List<OrtEintrag>? orte;

  @override
  ConsumerState<KartoReiseplaner> createState() => _KartoReiseplanerState();
}

class _KartoReiseplanerState extends ConsumerState<KartoReiseplaner> {
  late final TextEditingController _nach = TextEditingController(
    text: widget.ziel?.name ?? '',
  );
  OrtEintrag? _gewaehlt;
  Set<String> _wege = kReiseWegArten.toSet();
  String _optimierung = kReiseOptimierungSchnellste;
  late String _mittel = reisemittelVorschlag(widget.held);
  bool _eil = false;
  String _wetter = '';
  late HeroAdventureDateValue _abreise = reiseAbreiseVorschlag(widget.held);
  late final String _adventureId = laufendesAbenteuerId(widget.held);
  bool _datumSetzen = true;
  bool _laedt = false;
  String? _fehler;

  // Ankunft: folgt dem Plan, bis sie von Hand geändert wird; eine neue
  // Planankunft setzt sie zurück.
  HeroAdventureDateValue? _planAnkunft;
  HeroAdventureDateValue _ankunft = const HeroAdventureDateValue();

  @override
  void initState() {
    super.initState();
    if (widget.orte == null) {
      Future<void>.microtask(() {
        if (!mounted) return;
        ref.read(avesmapsOrteAnforderungProvider.notifier).fordereAn();
      });
    }
  }

  @override
  void dispose() {
    _nach.dispose();
    super.dispose();
  }

  ReiseOrt? _ort(String name, List<OrtEintrag> orte, {OrtEintrag? gewaehlt}) {
    final sauber = bereinigeStandort(name);
    if (sauber.isEmpty) return null;
    final verweis = ortsVerweisFuer(sauber, orte, gewaehlt: gewaehlt);
    return verweis == null
        ? ReiseOrt(name: sauber)
        : ReiseOrt(
            name: sauber,
            ortId: verweis.ortId,
            kartenX: verweis.kartenX,
            kartenY: verweis.kartenY,
          );
  }

  HeroReiseAnreise _anreise(ReisezeitPlan? plan) {
    final basis =
        anreiseAus(wege: _wege, optimierung: _optimierung) ??
        const HeroReiseAnreise();
    return basis.copyWith(
      abreise: _abreise,
      mittel: _mittel,
      tempo: _eil ? kReiseTempoEil : '',
      wetter: _wetter,
      geplanteTage: plan?.gespeicherteTage,
      meilen: plan == null ? null : (plan.meilen * 10).round() / 10,
    );
  }

  Future<void> _hole(AvesmapsRoutenAnfrage anfrage) async {
    setState(() {
      _laedt = true;
      _fehler = null;
    });
    final ergebnis = await ref.read(avesmapsReisewegeProvider.notifier).hole(
      <AvesmapsRoutenAnfrage>[anfrage],
    );
    if (!mounted) return;
    setState(() {
      _laedt = false;
      _fehler = ergebnis.fehler;
    });
  }

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final karto = context.karto;
    final leise = texte.legende.copyWith(color: karto.schriftLeise);
    final List<OrtEintrag> orte =
        widget.orte ?? ref.watch(ortsverzeichnisProvider);
    final wege =
        ref.watch(avesmapsReisewegeProvider).asData?.value ??
        const <String, AvesmapsRoute>{};

    // Der Verweis des Standorts unterscheidet gleichnamige Ausgangsorte.
    final von = _ort(
      widget.standort,
      orte,
      gewaehlt: eintragZumVerweis(widget.standort, widget.standortOrtId, orte),
    );
    final vorgabe = widget.ziel;
    // Das Ziel der Karte gilt, solange sein Name im Feld steht.
    final nach =
        vorgabe != null &&
            vorgabe.ortId.isNotEmpty &&
            bereinigeStandort(_nach.text) == bereinigeStandort(vorgabe.name)
        ? vorgabe
        : _ort(_nach.text, orte, gewaehlt: _gewaehlt);
    final anfrage = von == null || nach == null
        ? null
        : reisewegAnfrage(
            HeroReiseStation(id: 'von', ort: von.name, ortId: von.ortId),
            HeroReiseStation(id: 'nach', ort: nach.name, ortId: nach.ortId),
            anreise:
                anreiseAus(wege: _wege, optimierung: _optimierung) ??
                const HeroReiseAnreise(),
          );
    final weg = anfrage == null ? null : wege[anfrage.schluessel];
    final plan = weg == null || !weg.gefunden
        ? null
        : reisezeitPlan(
            weg: weg,
            mittel: _mittel,
            tempo: _eil ? kReiseTempoEil : kReiseTempoNormal,
            wetter: _wetter,
          );
    final planAnkunft = plan == null
        ? null
        : reiseDatumPlus(_abreise, plan.ganzeTage);
    if (planAnkunft != null &&
        (_planAnkunft == null || !_planAnkunft!.gleicheAngabe(planAnkunft))) {
      _planAnkunft = planAnkunft;
      _ankunft = planAnkunft;
    }
    final bereit = von != null && nach != null && _ankunft.hasContent;

    void fertig({required bool aufbrechen}) {
      Navigator.of(context).pop(
        KartoReiseplanErgebnis(
          von: von!,
          nach: nach!,
          anreise: _anreise(plan),
          ankunft: _ankunft,
          adventureId: _adventureId,
          abenteuerDatumSetzen:
              !aufbrechen && _datumSetzen && _adventureId.isNotEmpty,
          aufbrechen: aufbrechen,
        ),
      );
    }

    return AlertDialog(
      title: const Text('Reise planen'),
      content: SizedBox(
        width: Breite.klein,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Von', style: leise),
              Text(
                von?.name ?? 'Kein Standort erfasst',
                key: const ValueKey<String>('karto-reiseplan-von'),
                style: texte.abschnitt,
              ),
              if (von != null && von.ortId.isEmpty)
                Text(
                  'Der Standort ist kein Ort der Karte; ein Weg lässt sich '
                  'nicht berechnen.',
                  style: leise,
                ),
              const SizedBox(height: Abstand.weit),
              KartoOrtFeld(
                feldSchluessel: const ValueKey<String>('karto-reiseplan-nach'),
                controller: _nach,
                orte: orte,
                autofocus: widget.ziel == null,
                onChanged: (_) => setState(() {}),
                onOrtGewaehlt: (ort) => setState(() => _gewaehlt = ort),
                onlineSuche: widget.orte == null
                    ? ref.watch(avesmapsOnlineSucheProvider)
                    : null,
              ),
              const SizedBox(height: Abstand.weit),
              Text('Erlaubte Wege', style: leise),
              const SizedBox(height: Abstand.knapp),
              Wrap(
                spacing: Abstand.knapp,
                runSpacing: Abstand.knapp,
                children: [
                  for (final art in kReiseWegArten)
                    FilterChip(
                      key: ValueKey<String>('karto-reiseplan-weg-$art'),
                      label: Text(reiseWegArtName(art)),
                      selected: _wege.contains(art),
                      onSelected: _laedt
                          ? null
                          : (an) => setState(() {
                              if (an) {
                                _wege = {..._wege, art};
                              } else if (_wege.length > 1) {
                                _wege = {..._wege}..remove(art);
                              }
                            }),
                    ),
                ],
              ),
              const SizedBox(height: Abstand.normal),
              SegmentedButton<String>(
                key: const ValueKey<String>('karto-reiseplan-optimierung'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: kReiseOptimierungSchnellste,
                    label: Text('Schnellster'),
                  ),
                  ButtonSegment(
                    value: kReiseOptimierungKuerzeste,
                    label: Text('Kürzester'),
                  ),
                ],
                selected: {_optimierung},
                onSelectionChanged: _laedt
                    ? null
                    : (a) => setState(() => _optimierung = a.first),
              ),
              const SizedBox(height: Abstand.weit),
              KartoReiseplanWahl(
                mittel: _mittel,
                eil: _eil,
                wetter: _wetter,
                gesperrt: _laedt,
                onMittel: (m) => setState(() => _mittel = m),
                onEil: (e) => setState(() => _eil = e),
                onWetter: (w) => setState(() => _wetter = w),
              ),
              const SizedBox(height: Abstand.weit),
              Text('Abreise', style: leise),
              KartoDatumFelder(
                kennung: 'karto-reiseplan-abreise',
                initial: _abreise,
                onChanged: (d) => setState(() => _abreise = d),
              ),
              const SizedBox(height: Abstand.weit),
              if (plan != null)
                KartoReiseplanHerleitung(
                  plan: plan,
                  avesmapsTage: weg!.reisetage,
                )
              else if (weg != null)
                Text(
                  reisewegText(weg),
                  key: const ValueKey<String>('karto-reiseplan-ohne-weg'),
                  style: texte.fliess,
                )
              else
                Text(
                  anfrage == null
                      ? 'Ohne Kartenverweis an beiden Enden gibt es keinen '
                            'Plan; die Ankunft lässt sich von Hand eintragen.'
                      : 'Noch nicht berechnet.',
                  style: leise,
                ),
              if (_laedt) ...[
                const SizedBox(height: Abstand.normal),
                const LinearProgressIndicator(),
              ],
              if (_fehler != null) ...[
                const SizedBox(height: Abstand.normal),
                Text(
                  _fehler!,
                  key: const ValueKey<String>('karto-reiseplan-fehler'),
                  style: texte.legende.copyWith(color: karto.siegel),
                ),
              ],
              const SizedBox(height: Abstand.weit),
              Text('Ankunft', style: leise),
              KartoDatumFelder(
                // Neu aufgebaut, sobald der Plan eine andere Ankunft ergibt.
                key: ValueKey<String>(
                  'karto-reiseplan-ankunft-${_planAnkunft?.anzeigeText}',
                ),
                kennung: 'karto-reiseplan-ankunft',
                initial: _ankunft,
                onChanged: (d) => setState(() => _ankunft = d),
              ),
              if (_adventureId.isNotEmpty)
                CheckboxListTile(
                  key: const ValueKey<String>('karto-reiseplan-datum-setzen'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _datumSetzen,
                  onChanged: (v) => setState(() => _datumSetzen = v ?? false),
                  title: Text(
                    'Abenteuerdatum beim Ankommen auf die Ankunft setzen',
                    style: texte.fliess,
                  ),
                ),
              const SizedBox(height: Abstand.normal),
              Text('Wege: Avesmaps (avesmaps.de)', style: leise),
            ],
          ),
        ),
      ),
      actions: [
        if (anfrage != null && weg == null)
          TextButton(
            key: const ValueKey<String>('karto-reiseplan-berechnen'),
            onPressed: _laedt ? null : () => _hole(anfrage),
            child: const Text('Weg berechnen'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        OutlinedButton(
          key: const ValueKey<String>('karto-reiseplan-aufbrechen'),
          onPressed: bereit && _abreise.hasContent
              ? () => fertig(aufbrechen: true)
              : null,
          child: const Text('Aufbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('karto-reiseplan-ankommen'),
          onPressed: bereit ? () => fertig(aufbrechen: false) : null,
          child: const Text('Ankommen'),
        ),
      ],
    );
  }
}
