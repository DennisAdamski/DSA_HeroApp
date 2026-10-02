import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ablauf_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';

import 'gefecht_kontextfelder.dart';
import 'gefecht_fernkampffelder.dart';

import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kontext_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kampfmittel_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_zusatz_rules.dart';

/// Fragt fehlenden Kontext ab, ohne erkannte Sperren übergehen zu können.
class GefechtAktionsdialog extends StatefulWidget {
  /// Baut einen Dialog aus denselben Regeln wie die Aktionskarte.
  const GefechtAktionsdialog({
    super.key,
    required this.zustand,
    required this.werte,
    required this.katalog,
    required this.aktion,
    required this.titel,
    this.manoever,
    this.probe,
    this.manuell = false,
    this.kampfmittel,
    this.zusatzParade = false,
  });
  final Gefechtszustand zustand;
  final HeroComputedSnapshot werte;
  final RulesCatalog katalog;
  final Gefechtsaktion aktion;
  final String titel;
  final ManeuverDef? manoever;
  final ResolvedProbeRequest? probe;
  final bool manuell;
  final GefechtsKampfmittelwahl? kampfmittel;
  final bool zusatzParade;
  @override
  State<GefechtAktionsdialog> createState() => _GefechtAktionsdialogState();
}

class _GefechtAktionsdialogState extends State<GefechtAktionsdialog> {
  final _zuschlag = TextEditingController(text: '0');
  final _ziel = TextEditingController();
  final _dauer = TextEditingController(text: '1');
  final _kosten = TextEditingController(text: '1');
  String? _dk;
  bool _bestaetigt = false, _grosserGegner = false, _grosserSchild = false;
  bool _zusatzParade = false;
  late Gefechtskontext _kontext;
  int _distanzSchritte = 0;
  GefechtsKampfmittelwahl? _mittel;
  @override
  void initState() {
    super.initState();
    _dk = widget.zustand.dk;
    _zusatzParade = widget.zusatzParade;
    _kontext = widget.zustand.kontext;
    _mittel =
        widget.kampfmittel ??
        gefechtsStandardKampfmittel(
          widget.werte,
          widget.manoever == null
              ? widget.aktion
              : gefechtsManoeveraktion(widget.manoever!),
        );
    if (widget.aktion == Gefechtsaktion.zusatzaktion &&
        widget.kampfmittel == null) {
      _mittel = gefechtsZusatzoptionen(widget.werte)
          .where((o) => o.parade == _zusatzParade)
          .firstOrNull
          ?.kampfmittel;
    }
    if (widget.manoever != null) {
      _zuschlag.text = '${gefechtsManoeverZuschlag(widget.manoever!)}';
    }
  }

  @override
  void dispose() {
    for (final c in [_zuschlag, _ziel, _dauer, _kosten]) {
      c.dispose();
    }
    super.dispose();
  }

  // Auch alte Aufrufer erhalten den fachlich richtigen Abwehrkontext.
  Gefechtsaktion get _aktion => gefechtsAktionMitKampfmittel(
    widget.manoever == null
        ? widget.aktion
        : gefechtsManoeveraktion(widget.manoever!),
    _mittel,
  );

  // Das Formular liefert Daten; Freigaben und Zielwertrechnung bleiben im Modul.
  GefechtAuftrag _auftrag() => GefechtAuftrag(
    aktion: _aktion,
    titel: _mittel == null || widget.manuell
        ? widget.titel
        : '${widget.titel} · ${gefechtsKampfmittelFuer(widget.werte, _mittel)?.name}',
    zuschlag: int.tryParse(_zuschlag.text) ?? 0,
    zielwert: int.tryParse(_ziel.text),
    dk: _dk,
    dauer: _aktion == Gefechtsaktion.zusatzaktion
        ? 1
        : int.tryParse(_dauer.text) ?? 0,
    kosten: int.tryParse(_kosten.text) ?? -1,
    manoever: widget.manoever,
    probe: widget.probe,
    manuell: widget.manuell,
    grosserGegner: _grosserGegner,
    grosserSchild: _grosserSchild,
    zusatzParade: _zusatzParade,
    kontext: _kontext.copyWith(weitereRegelnGeprueft: _bestaetigt),
    distanzSchritte: _distanzSchritte,
    kampfmittel: _mittel,
  );
  @override
  Widget build(BuildContext context) {
    final auftrag = _auftrag();
    final mittel = gefechtsKampfmittelFuer(widget.werte, _mittel);
    final werte = gefechtswerteFuer(widget.werte, kampfmittel: _mittel);
    final kontextAktion = _aktion == Gefechtsaktion.zusatzaktion
        ? _zusatzParade
              ? _mittel?.art == GefechtsKampfmittelArt.schild
                    ? Gefechtsaktion.schildparade
                    : Gefechtsaktion.parade
              : Gefechtsaktion.angriff
        : _aktion;
    final abwehr =
        kontextAktion == Gefechtsaktion.parade ||
        kontextAktion == Gefechtsaktion.schildparade;
    final waehlen = abwehr || kontextAktion == Gefechtsaktion.angriff;
    final profile = gefechtsKampfmittelprofile(widget.werte)
        .where((p) => abwehr ? p.pa != null : p.at != null)
        .toList();
    final p = pruefeGefechtAuftrag(
      widget.zustand,
      widget.werte,
      widget.katalog,
      auftrag,
    );
    final sonder =
        widget.manuell || widget.manoever != null || widget.probe != null;
    final gueltig =
        int.tryParse(_zuschlag.text) != null &&
        auftrag.dauer >= 1 &&
        (!widget.manuell ||
            _aktion == Gefechtsaktion.orientieren ||
            auftrag.zielwert != null ||
            widget.probe != null);
    return AlertDialog(
      title: Text(widget.titel),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (waehlen && profile.isNotEmpty)
                DropdownButtonFormField<GefechtsKampfmittelArt>(
                  key: const ValueKey('gefecht-kampfmittel'),
                  isExpanded: true,
                  initialValue: _mittel?.art,
                  decoration: const InputDecoration(
                    labelText: 'Verwendetes Kampfmittel',
                  ),
                  items: [
                    for (final profil in profile)
                      DropdownMenuItem(
                        value: profil.wahl.art,
                        enabled: profil.sperren.isEmpty,
                        child: Text(
                          '${profil.name} · ${abwehr ? 'PA ${profil.pa}' : 'AT ${profil.at}'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (art) => setState(() {
                    _mittel = profile.firstWhere((p) => p.wahl.art == art).wahl;
                    _bestaetigt = false;
                  }),
                ),
              if (mittel != null && waehlen) ...[
                for (final anteil in mittel.anteile) Text(anteil),
              ],
              if (_aktion == Gefechtsaktion.orientieren)
                const Text(
                  'Orientieren wird manuell geführt: WdS 56 verlangt zwei Aktionen und '
                  'eine IN-Probe; Aufmerksamkeit verkürzt auf eine Aktion ohne IN-Probe. '
                  'Die Hausregel kann die Dauer ändern. Zielwert nur bei erforderlicher Probe '
                  'eintragen. INI-Maximum und Kriegskunstbonus danach über „Manuelle Korrektur“ übernehmen.',
                ),
              if (_aktion == Gefechtsaktion.zusatzaktion)
                DropdownButtonFormField<bool>(
                  initialValue: _zusatzParade,
                  decoration: const InputDecoration(
                    labelText: 'Art der Zusatzaktion',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: false,
                      child: Text('Zusatzattacke'),
                    ),
                    DropdownMenuItem(value: true, child: Text('Zusatzparade')),
                  ],
                  onChanged: (v) => setState(() {
                    _zusatzParade = v!;
                    _mittel = gefechtsZusatzoptionen(widget.werte)
                        .where((o) => o.parade == v)
                        .firstOrNull
                        ?.kampfmittel;
                    _bestaetigt = false;
                  }),
                ),
              if (widget.manoever != null) ...[
                Text(widget.manoever!.erklarung),
                Text('Katalogzuschlag: ${widget.manoever!.erschwernis}'),
                Text(widget.manoever!.quelle),
              ],
              Text(
                '${freigabeText(p.status)}${p.zielwert == null ? '' : ' · Zielwert ${p.zielwert}'}',
              ),
              for (final grund in p.gruende)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('• $grund'),
                ),
              const SizedBox(height: 16),
              if (_aktion == Gefechtsaktion.angriff && !werte.fernkampf)
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: _distanzSchritte,
                  decoration: const InputDecoration(
                    labelText: 'Angriffsabsicht',
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Treffer')),
                    DropdownMenuItem(
                      value: -1,
                      child: Text('Eine DK annähern (kein Schaden)'),
                    ),
                    DropdownMenuItem(
                      value: -2,
                      child: Text('Zwei DK annähern (+8)'),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text('Eine DK entfernen (+4)'),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text('Zwei DK entfernen (+8)'),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    _distanzSchritte = v!;
                    _bestaetigt = false;
                  }),
                ),
              if (_aktion == Gefechtsaktion.angriff && werte.fernkampf)
                GefechtFernkampffelder(
                  kontext: _kontext,
                  onChanged: (k) => setState(() {
                    _kontext = k;
                    _bestaetigt = false;
                  }),
                ),
              GefechtKontextfelder(
                kontext: _kontext,
                aktion: kontextAktion,
                onChanged: (k) => setState(() {
                  _kontext = k;
                  _bestaetigt = false;
                }),
              ),
              if (werte.halbschwert)
                CheckboxListTile(
                  value: _kontext.halbschwert,
                  title: const Text('Aktuell in Halbschwertführung'),
                  subtitle: const Text(
                    'Führung und geeignete Waffe bestätigen',
                  ),
                  onChanged: (v) => setState(() {
                    _kontext = _kontext.copyWith(halbschwert: v);
                    _bestaetigt = false;
                  }),
                ),
              for (final m in p.modifikatoren)
                Text('${m.name}: ${m.wert >= 0 ? '+' : ''}${m.wert}'),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _dk,
                decoration: const InputDecoration(
                  labelText: 'Aktuelle Distanzklasse',
                ),
                items: [
                  for (final dk in ['H', 'N', 'S', 'P'])
                    DropdownMenuItem(value: dk, child: Text(dk)),
                ],
                onChanged: (v) => setState(() {
                  _dk = v;
                  _bestaetigt = false;
                }),
              ),
              _zahl(
                _zuschlag,
                'Weitere Erschwernis / Manöveransage (ohne automatische Anteile)',
              ),
              if (sonder) ...[
                if (widget.probe == null && widget.manuell)
                  _zahl(_ziel, 'Manuell bestätigter Grundzielwert (optional)'),
                _zahl(_dauer, 'Gesamtdauer in Aktionen'),
                if (widget.manuell || widget.manoever != null)
                  _zahl(_kosten, 'Reguläre Aktionen jetzt (0–2)'),
                const Text(
                  'Mehrteilige Handlungen binden weitere reguläre Aktionen. '
                  'Kosten, Wirkungen und Ressourcen werden nach Regelbeschreibung manuell geführt.',
                ),
              ],
              if (widget.manoever?.name.toLowerCase().contains(
                    'hammerschlag',
                  ) ??
                  false) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sehr großer Gegner'),
                  value: _grosserGegner,
                  onChanged: (v) => setState(() {
                    _grosserGegner = v!;
                  }),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Großer oder sehr großer Schild'),
                  value: _grosserSchild,
                  onChanged: (v) => setState(() {
                    _grosserSchild = v!;
                  }),
                ),
              ],
              CheckboxListTile(
                key: const ValueKey('gefecht-kontext-bestaetigen'),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Voraussetzungen, Zeitpunkt und Folgen geprüft',
                ),
                value: _bestaetigt,
                onChanged: (v) => setState(() {
                  _bestaetigt = v!;
                }),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey('gefecht-auftrag-starten'),
          onPressed:
              gueltig &&
                  p.status != Gefechtsfreigabe.gesperrt &&
                  _bestaetigt &&
                  gefechtsPflichtkontextErfasst(
                    _kontext,
                    kontextAktion,
                    fernkampf: werte.fernkampf,
                  ) &&
                  (!gefechtAuftragBrauchtDk(auftrag, werte) || _dk != null)
              ? () => Navigator.pop(context, auftrag)
              : null,
          child: Text(
            p.zielwert != null || widget.probe != null
                ? 'Probe ausführen'
                : 'Aktion ausführen',
          ),
        ),
      ],
    );
  }

  // Änderungen machen die Bestätigung ungültig und zeigen die neue Freigabe.
  Widget _zahl(TextEditingController c, String label) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() {
        _bestaetigt = false;
      }),
    ),
  );
}

/// Deutsche Statusbezeichnung ohne eine sichere Regelfreigabe vorzutäuschen.
String freigabeText(Gefechtsfreigabe status) => switch (status) {
  Gefechtsfreigabe.bereit => 'Bereit',
  Gefechtsfreigabe.pruefen => 'Prüfen',
  Gefechtsfreigabe.gesperrt => 'Gesperrt',
};
