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
  });
  final Gefechtszustand zustand;
  final HeroComputedSnapshot werte;
  final RulesCatalog katalog;
  final Gefechtsaktion aktion;
  final String titel;
  final ManeuverDef? manoever;
  final ResolvedProbeRequest? probe;
  final bool manuell;
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
  @override
  void initState() {
    super.initState();
    _dk = widget.zustand.dk;
    _kontext = widget.zustand.kontext;
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

  // Das Formular liefert Daten; Freigaben und Zielwertrechnung bleiben im Modul.
  GefechtAuftrag _auftrag() => GefechtAuftrag(
    aktion: widget.aktion,
    titel: widget.titel,
    zuschlag: int.tryParse(_zuschlag.text) ?? 0,
    zielwert: int.tryParse(_ziel.text),
    dk: _dk,
    dauer: int.tryParse(_dauer.text) ?? 0,
    kosten: int.tryParse(_kosten.text) ?? -1,
    manoever: widget.manoever,
    probe: widget.probe,
    manuell: widget.manuell,
    grosserGegner: _grosserGegner,
    grosserSchild: _grosserSchild,
    zusatzParade: _zusatzParade,
    kontext: _kontext.copyWith(weitereRegelnGeprueft: _bestaetigt),
    distanzSchritte: _distanzSchritte,
  );
  @override
  Widget build(BuildContext context) {
    final auftrag = _auftrag();
    final p = pruefeGefechtAuftrag(
      widget.zustand,
      widget.werte,
      widget.katalog,
      auftrag,
    );
    final sonder =
        widget.manuell ||
        widget.manoever != null ||
        widget.probe != null ||
        widget.aktion == Gefechtsaktion.zusatzaktion;
    final gueltig =
        int.tryParse(_zuschlag.text) != null &&
        auftrag.dauer >= 1 &&
        (!(widget.manuell || widget.aktion == Gefechtsaktion.zusatzaktion) ||
            widget.aktion == Gefechtsaktion.orientieren ||
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
              if (widget.aktion == Gefechtsaktion.orientieren)
                const Text(
                  'Orientieren wird manuell geführt: WdS 56 verlangt zwei Aktionen und '
                  'eine IN-Probe; Aufmerksamkeit verkürzt auf eine Aktion ohne IN-Probe. '
                  'Die Hausregel kann die Dauer ändern. Zielwert nur bei erforderlicher Probe '
                  'eintragen. INI-Maximum und Kriegskunstbonus danach über „Manuelle Korrektur“ übernehmen.',
                ),
              if (widget.aktion == Gefechtsaktion.zusatzaktion)
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
              if (widget.aktion == Gefechtsaktion.angriff &&
                  !widget.werte.combatPreviewStats.isRangedWeapon)
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
              if (widget.aktion == Gefechtsaktion.angriff &&
                  widget.werte.combatPreviewStats.isRangedWeapon)
                GefechtFernkampffelder(
                  kontext: _kontext,
                  onChanged: (k) => setState(() {
                    _kontext = k;
                    _bestaetigt = false;
                  }),
                ),
              GefechtKontextfelder(
                kontext: _kontext,
                aktion: widget.aktion,
                onChanged: (k) => setState(() {
                  _kontext = k;
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
              _zahl(_zuschlag, 'Gesamte Erschwernis (negativ = Erleichterung)'),
              if (sonder) ...[
                if (widget.probe == null)
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
                    widget.aktion,
                    fernkampf: widget.werte.combatPreviewStats.isRangedWeapon,
                  ) &&
                  (!gefechtAuftragBrauchtDk(
                        auftrag,
                        gefechtswerteFuer(widget.werte),
                      ) ||
                      _dk != null)
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
