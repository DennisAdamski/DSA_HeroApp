import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_wirken.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_magie_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_wirken_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_fremdwirkung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_requirement_context.dart';

/// Bestätigt variable Profile und bindet bekannte Dauer/Kosten an die echte Probe.
class GefechtWirkdialog extends StatefulWidget {
  /// Ein Zauber oder eine tatsächliche Liturgiekenntnis bestimmen den Probenpool.
  const GefechtWirkdialog({
    super.key,
    required this.snapshot,
    required this.zustand,
    this.zauber,
    this.talent,
  });
  final HeroComputedSnapshot snapshot;
  final Gefechtszustand zustand;
  final SpellDef? zauber;
  final TalentDef? talent;
  @override
  State<GefechtWirkdialog> createState() => _WirkdialogState();
}

class _WirkdialogState extends State<GefechtWirkdialog> {
  final _dauer = TextEditingController();
  final _kosten = TextEditingController();
  final _fehlkosten = TextEditingController();
  final _zuschlag = TextEditingController(text: '0');
  final _identitaet = TextEditingController();
  final _eigenschaften = TextEditingController();
  final _aufrecht = TextEditingController();
  Gefechtshandlungsart _art = Gefechtshandlungsart.zauber;
  String? _rep;
  int _grad = 1, _mirakelklasse = 0;
  bool _neueSr = false, _endprobe = false;
  @override
  void initState() {
    super.initState();
    final z = widget.zauber;
    if (z != null) {
      _dauer.text = gefechtsFesteAktionen(z.castingTime)?.toString() ?? '';
      _kosten.text = gefechtsFesteKosten(z.aspCost)?.toString() ?? '';
      if (gefechtsFremdprofilUnterstuetzt(z.id)) _kosten.text = '0';
      _aufrecht.text = widget.zustand.aufrechterhalteneZauber.toString();
      _rep = widget.snapshot.hero.spells[z.id]?.learnedRepresentation;
      if (_rep == null && widget.snapshot.hero.representationen.length == 1) {
        _rep = widget.snapshot.hero.representationen.single;
      }
    } else {
      _art = Gefechtshandlungsart.mirakel;
      _dauer.text = '1';
      _kosten.text = '5';
      _eigenschaften.text =
          gefechtsEigenschaftenFuerKult(widget.talent!.name)?.join('/') ?? '';
    }
    _identitaet.text = z?.id ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      _dauer,
      _kosten,
      _fehlkosten,
      _zuschlag,
      _identitaet,
      _eigenschaften,
      _aufrecht,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // Jede Änderung baut Freigabe und Vorschau neu auf.
  void _aendern(VoidCallback aenderung) => setState(aenderung);
  @override
  Widget build(BuildContext context) {
    final karmal = widget.zauber == null;
    final basis = karmal
        ? gefechtsLiturgieprobe(
            widget.snapshot,
            widget.talent!,
            eigenschaften: _eigenschaften.text
                .split('/')
                .map((e) => e.trim())
                .toList(),
          )
        : gefechtsZauberprobe(widget.snapshot, widget.zauber!);
    final id =
        '${_art.name}:${widget.talent?.id ?? ''}:${_identitaet.text.trim()}';
    final wiederholung = _neueSr
        ? 0
        : widget.zustand.karmaleFehlversuche[id] ?? 0;
    final zuschlag = int.tryParse(_zuschlag.text);
    final aufrecht = int.tryParse(_aufrecht.text);
    final automatisch = karmal || aufrecht == null
        ? 0
        : gefechtsZauberZuschlag(
            widget.snapshot,
            aufrechterhalten: aufrecht,
            simultanzaubern: heroSpecialAbilityNames(widget.snapshot.hero)
                .any((n) => n.toLowerCase().startsWith('simultanzaubern')),
          );
    final probe = basis == null || zuschlag == null
        ? null
        : modifiziereGefechtsWirkprobe(
            basis,
            karmal
                ? gefechtsKarmalzuschlag(
                    grad: _grad,
                    mirakel: _art == Gefechtshandlungsart.mirakel,
                    mirakelklasse: _mirakelklasse,
                    fehlversuche: wiederholung,
                    zusaetzlich: zuschlag + automatisch,
                  )
                : zuschlag + automatisch,
          );
    final dauer = int.tryParse(_dauer.text);
    final kosten = int.tryParse(_kosten.text);
    final fehl = int.tryParse(_fehlkosten.text);
    final standardFehl = kosten == null || kosten < 0
        ? null
        : karmal && _art == Gefechtshandlungsart.liturgie && kosten % 5 != 0
        ? null
        : gefechtsWirkkosten(kosten, _art, erfolg: false);
    final gueltig =
        probe != null &&
        dauer != null &&
        dauer >= 1 &&
        kosten != null &&
        kosten >= 0 &&
        (standardFehl != null || fehl != null) &&
        (fehl == null || fehl >= 0) &&
        (_art != Gefechtshandlungsart.mirakel || dauer == 1 && kosten == 5) &&
        (karmal || aufrecht != null && aufrecht >= 0) &&
        (!karmal ? _rep != null : _identitaet.text.trim().isNotEmpty);
    return AlertDialog(
      title: Text(widget.zauber?.name ?? 'Mirakel / Liturgie'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.zauber != null)
                Text(
                  'Dauer: ${widget.zauber!.castingTime}\n'
                  'Kosten: ${widget.zauber!.aspCost}\n${widget.zauber!.wirkung}',
                ),
              if (!karmal)
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _rep,
                  decoration: const InputDecoration(
                    labelText: 'Tatsächliche Repräsentation',
                  ),
                  items: [
                    for (final r in {
                      ...widget.snapshot.hero.representationen,
                      ?_rep,
                    })
                      DropdownMenuItem(value: r, child: Text(r)),
                  ],
                  onChanged: (v) => _aendern(() {
                    _rep = v;
                  }),
                ),
              if (!karmal && widget.snapshot.hero.representationen.isEmpty)
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Repräsentation bestätigen',
                  ),
                  onChanged: (v) => _aendern(() {
                    _rep = v.trim().isEmpty ? null : v.trim();
                  }),
                ),
              if (karmal) ...[
                DropdownButtonFormField<Gefechtshandlungsart>(
                  initialValue: _art,
                  decoration: const InputDecoration(labelText: 'Handlungsart'),
                  items: const [
                    DropdownMenuItem(
                      value: Gefechtshandlungsart.mirakel,
                      child: Text('Mirakel'),
                    ),
                    DropdownMenuItem(
                      value: Gefechtshandlungsart.liturgie,
                      child: Text('Liturgie'),
                    ),
                  ],
                  onChanged: (v) => _aendern(() {
                    _art = v!;
                    _endprobe = false;
                    _dauer.text = _art == Gefechtshandlungsart.mirakel
                        ? '1'
                        : '';
                    _kosten.text = _art == Gefechtshandlungsart.mirakel
                        ? '5'
                        : '${gefechtsGradkosten(_grad)}';
                  }),
                ),
                _text(
                  _identitaet,
                  'Liturgie / Mirakelziel (gleiche Handlung = gleiche Kennung)',
                ),
                _text(
                  _eigenschaften,
                  'Kulteigenschaften (MU/KL/IN oder bestätigte Kette)',
                ),
                if (_art == Gefechtshandlungsart.mirakel)
                  DropdownButtonFormField<int>(
                    initialValue: _mirakelklasse,
                    decoration: const InputDecoration(
                      labelText: 'Mirakelzuordnung',
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Mirakel+ (+0)')),
                      DropdownMenuItem(value: 6, child: Text('Neutral (+6)')),
                      DropdownMenuItem(
                        value: 18,
                        child: Text('Mirakel− (+18)'),
                      ),
                    ],
                    onChanged: (v) => _aendern(() {
                      _mirakelklasse = v!;
                    }),
                  ),
                if (_art == Gefechtshandlungsart.liturgie) ...[
                  DropdownButtonFormField<int>(
                    initialValue: _grad,
                    decoration: const InputDecoration(
                      labelText: 'Wirksamer Grad einschließlich Aufstufung',
                    ),
                    items: [
                      for (var g = 1; g <= 6; g++)
                        DropdownMenuItem(value: g, child: Text('Grad $g')),
                    ],
                    onChanged: (v) => _aendern(() {
                      _grad = v!;
                      _kosten.text = '${gefechtsGradkosten(_grad)}';
                    }),
                  ),
                  CheckboxListTile(
                    value: _endprobe,
                    title: const Text('Bestätigtes Profil: Probe am Ende'),
                    subtitle: const Text(
                      'Zeitpunkt ist ohne konkreten Regelbeleg manuell zu bestätigen.',
                    ),
                    onChanged: (v) => _aendern(() {
                      _endprobe = v!;
                    }),
                  ),
                  if (_grad >= 5)
                    const Text(
                      'Permanente KaP separat am Spieltisch und im Heldenblatt prüfen.',
                    ),
                ],
                CheckboxListTile(
                  value: _neueSr,
                  title: const Text(
                    'Neue Spielrunde (SR) ausdrücklich bestätigt',
                  ),
                  onChanged: (v) => _aendern(() {
                    _neueSr = v!;
                  }),
                ),
                Text(
                  'Vorherige Fehlversuche derselben Handlung: $wiederholung; +${wiederholung * 3}',
                ),
              ],
              if (!karmal) ...[
                _text(
                  _aufrecht,
                  'Aufrechterhaltene Zauber (bestätigte Anzahl, 0 möglich)',
                ),
                Text(
                  'Automatische LE-/AU-/Aufrechterhalten-Mali: +$automatisch',
                ),
              ],
              _text(
                _dauer,
                'Bestätigte Dauer in Aktionen (lange Rituale nicht umrechnen)',
              ),
              _text(
                _kosten,
                karmal ? 'Geplante KaP-Kosten' : 'Geplante AsP-Kosten',
              ),
              if (gefechtsFremdprofilUnterstuetzt(widget.zauber?.id ?? ''))
                const Text(
                  'Grundform mit Fremdziel: Erfolgskosten werden aus '
                  '2W6 + ZfP* ermittelt. Fehlversuchskosten ausdrücklich eingeben; '
                  'die variable Formel wird dafür nicht geraten.',
                ),
              _text(
                _zuschlag,
                'Zusätzlicher Probenzuschlag (bereits enthaltene Mali auslassen)',
              ),
              _text(
                _fehlkosten,
                'Abweichende Fehlversuchskosten (optional, Regelbeleg prüfen)',
              ),
              Text(
                'Fehlversuch: ${fehl ?? standardFehl ?? 'bestätigen'} ${karmal ? 'KaP' : 'AsP'}',
              ),
              // Der Startknopf ist die Bestätigung; die Sonderfälle bleiben
              // als Hinweis sichtbar statt als Pflichthaken.
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Repräsentationsausnahmen, Störungen, Patzer und permanente '
                  'Kosten gezielt am Tisch prüfen. Angebrochene halbe '
                  'Zauberaktionen: aufrunden (App).',
                ),
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
          onPressed:
              gueltig &&
                  (!gefechtsFremdprofilUnterstuetzt(widget.zauber?.id ?? '') ||
                      fehl != null)
              ? () => Navigator.pop(context, (
                  _art,
                  GefechtsWirkprofil(
                    probe: probe,
                    dauer: dauer,
                    kosten: kosten,
                    karmal: karmal,
                    repraesentation: _rep ?? '',
                    aufrechterhalteneZauber: karmal ? null : aufrecht,
                    misserfolgKosten: fehl,
                    endprobe: _endprobe,
                    identitaet: id,
                    neueSpielrunde: _neueSr,
                    permanentManuell: karmal && _grad >= 5,
                    zauberkontrolle: heroSpecialAbilityNames(
                      widget.snapshot.hero,
                    ).any((n) => n.toLowerCase().startsWith('zauberkontrolle')),
                  ),
                ))
              : null,
          child: const Text('Wirken beginnen'),
        ),
      ],
    );
  }

  // Numeric validity is checked by the rule profile, not guessed on submission.
  Widget _text(TextEditingController c, String label) => TextField(
    controller: c,
    decoration: InputDecoration(labelText: label),
    onChanged: (_) => _aendern(() {}),
  );
}
