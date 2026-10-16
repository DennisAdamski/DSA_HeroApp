import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_gegner_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ueberzahl_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_vorgaben_rules.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_begegnung_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_seite_provider.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_seite.dart';

/// Gemeinsam verfügbare Gegner mit konkreter Zielwahl für diese Heldensitzung.
class GefechtGegnerkarte extends ConsumerWidget {
  /// Die Waffendistanz bestimmt nur die sichtbare, änderbare Startvorgabe.
  ///
  /// [onAktion] ist der gemeinsame Guard der Ansicht: Dialoge öffnen sich nur
  /// einmal, Fehler erscheinen im Gefechtshinweis.
  const GefechtGegnerkarte({
    super.key,
    required this.heroId,
    required this.waffenDk,
    required this.fernkampf,
    required this.gesperrt,
    required this.onAktion,
  });
  final String heroId, waffenDk;
  final bool fernkampf, gesperrt;
  final Future<void> Function(Future<void> Function()) onAktion;

  /// IDs statt Namen verbinden Auswahl und spätere Treffer.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final begegnung = ref.watch(gefechtBegegnungProvider);
    final s = ref.watch(gefechtMitInitiativeProvider(heroId));
    final blockiert = gesperrt || s?.auftrag != null || s?.handlung != null;
    final controller = ref.read(gefechtBegegnungProvider.notifier);
    // Nur wer dabei ist, kann gebunden werden; nur Nahkämpfer zählen.
    final seite = ref.watch(gefechtsEigeneSeiteProvider(heroId));
    final dabei = {
      for (final t in seite)
        if (t.beteiligung != GefechtsBeteiligung.nichtDabei) t.id: t.name,
    };
    final teilnehmer = dabei.keys.toList();
    String name(String id) => dabei[id] ?? id;
    final ueberzahl = gefechtsUeberzahl(
      begegnung,
      eigeneNahkaempfer: gefechtsEigeneNahkaempfer(seite),
    );
    final lage = _lagetext(begegnung, heroId, ueberzahl);
    Future<void> bearbeiten([Gefechtsgegner? g]) async {
      final neu = await showDialog<Gefechtsgegner>(
        context: context,
        builder: (_) => GefechtGegnerdialog(gegner: g),
      );
      if (neu != null) controller.profilSpeichern(neu);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Gegner', style: Theme.of(context).textTheme.titleLarge),
                TextButton(
                  onPressed: blockiert ? null : () => onAktion(bearbeiten),
                  child: const Text('+ Gegner'),
                ),
              ],
            ),
            if (lage.isNotEmpty) Text(lage, key: const ValueKey('gegner-lage')),
            if (begegnung.gegner.isEmpty)
              const Text(
                'Name und INI erfassen; LeP, RS und KO dürfen unbekannt '
                'bleiben. Nur für diese Begegnung.',
              ),
            for (final g in begegnung.gegner.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${g.name} · ${_schadenstext(g)} · RS ${g.rs ?? "?"} · '
                      '${_initext(g, ueberzahl)}',
                    ),
                    if (_zusatztext(g).isNotEmpty) Text(_zusatztext(g)),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final st in GefechtsgegnerStatus.values)
                          ChoiceChip(
                            key: ValueKey('gegner-status-${g.id}-${st.name}'),
                            label: Text(gefechtsgegnerStatusLabel[st]!),
                            selected: g.status == st,
                            onSelected: gesperrt
                                ? null
                                : (_) => onAktion(
                                    () async =>
                                        controller.statusSetzen(g.id, st),
                                  ),
                          ),
                      ],
                    ),
                    if (gefechtsGegnerHandelt(g))
                      DropdownButton<String?>(
                        key: ValueKey('gegner-bindet-${g.id}'),
                        isExpanded: true,
                        value: teilnehmer.contains(g.bindet) ? g.bindet : null,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('bindet niemanden'),
                          ),
                          for (final t in teilnehmer)
                            DropdownMenuItem<String?>(
                              value: t,
                              child: Text(
                                'bindet ${name(t)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: gesperrt
                            ? null
                            : (t) => onAktion(
                                () async => controller.bindungSetzen(g.id, t),
                              ),
                      ),
                    if (gefechtsGegnerStatusvorschlag(g) case final v?)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(v.grund),
                          TextButton(
                            key: ValueKey('gegner-vorschlag-${g.id}'),
                            onPressed: gesperrt
                                ? null
                                : () => onAktion(
                                    () async =>
                                        controller.statusSetzen(g.id, v.status),
                                  ),
                            child: Text(
                              'Als ${gefechtsgegnerStatusLabel[v.status]} markieren',
                            ),
                          ),
                        ],
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          key: ValueKey('gegner-ziel-${g.id}'),
                          onPressed:
                              blockiert ||
                                  s == null ||
                                  !gefechtsGegnerAngreifbar(g)
                              ? null
                              : () => onAktion(() async {
                                  ref
                                      .read(gefechtProvider(heroId).notifier)
                                      .setzen(
                                        waehleGefechtsgegner(
                                          s,
                                          g,
                                          heldId: heroId,
                                          startDk: gefechtsStartDk(
                                            waffenDk,
                                            fernkampf: fernkampf,
                                          ),
                                        ),
                                      );
                                }),
                          child: Text(
                            s?.kontext.gegnerId == g.id ? '✓ Ziel' : 'Als Ziel',
                          ),
                        ),
                        TextButton(
                          onPressed: blockiert
                              ? null
                              : () => onAktion(() => bearbeiten(g)),
                          child: const Text('Werte ändern'),
                        ),
                        TextButton(
                          onPressed: blockiert
                              ? null
                              : () => onAktion(() async {
                                  final tp = await showDialog<int>(
                                    context: context,
                                    builder: (_) =>
                                        GefechtGegnerschadendialog(gegner: g),
                                  );
                                  if (tp != null) {
                                    controller.schaden(
                                      gegnerId: g.id,
                                      buchungId: UniqueKey().toString(),
                                      tp: tp,
                                    );
                                  }
                                }),
                          child: const Text('Treffer übernehmen'),
                        ),
                        if (g.treffer.isNotEmpty)
                          TextButton(
                            key: ValueKey('gegner-rueck-${g.id}'),
                            onPressed: blockiert
                                ? null
                                : () => onAktion(() async {
                                    controller.trefferZuruecknehmen(
                                      gegnerId: g.id,
                                      buchungId: g.treffer.last.buchungId,
                                    );
                                  }),
                            child: const Text('Letzten Treffer zurücknehmen'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            const Divider(),
            GefechtEigeneSeite(
              heroId: heroId,
              gesperrt: gesperrt,
              onAktion: onAktion,
            ),
          ],
        ),
      ),
    );
  }
}

// Kräfteverhältnis und eigene Abwehrlage (WdS S. 81); leer ohne Bindungen.
String _lagetext(Gefechtsbegegnung b, String heroId, GefechtsUeberzahl u) {
  if (u.gegner == 0) return '';
  final l = gefechtsVerteidigerlage(b, heroId);
  return [
    [
      'Nahkampf: ${u.eigene} gegen ${u.gegner}',
      if (u.iniBonusGegner > 0) 'Gegner INI +${u.iniBonusGegner}',
      if (u.iniBonusEigene > 0) 'eure INI +${u.iniBonusEigene}',
      if (u.aufgehoben) 'Überzahl durch Taktik aufgehoben',
    ].join(' · '),
    if (l.gegner > 0)
      [
        'Dich binden ${l.gegner}',
        if (l.paradeErschwernis > 0) 'Parade ${l.paradeErschwernis} schwerer',
        if (l.ausweichenErschwernis > 0)
          'Ausweichen ${l.ausweichenErschwernis} schwerer',
        if (l.gegnerInUeberzahl) 'ihre AT 1 leichter',
        if (l.imRuecken > 0) '${l.imRuecken} im Rücken, nicht parierbar',
      ].join(' · '),
  ].join('\n');
}

// Aktuelle INI mit Überzahl- und Wundanteil, wenn sie vom erfassten Wert abweicht.
String _initext(Gefechtsgegner g, GefechtsUeberzahl u) {
  final ini = gefechtsGegnerIni(g, u);
  final teile = [
    if (ini.ueberzahl != 0) '+${ini.ueberzahl} Überzahl',
    if (ini.wunden != 0) '${ini.wunden} Wunden',
  ];
  return teile.isEmpty
      ? 'INI ${ini.wert}'
      : 'INI ${ini.wert} (${g.ini} ${teile.join(", ")})';
}

// Kurzer Schadensstand: LeP nur, wenn Start-LeP und alle RS bekannt sind.
String _schadenstext(Gefechtsgegner g) {
  final st = gefechtsGegnerstand(g);
  final lep = g.lep;
  if (st.lep != null && lep != null) return 'LeP ${st.lep}/$lep';
  if (st.tpOhneRs > 0) {
    return '${st.sp > 0 ? "${st.sp} SP + " : ""}${st.tpOhneRs} TP (RS ?)';
  }
  return lep == null ? '${st.sp} SP' : 'LeP $lep';
}

// Größe, Wunden und Manöverfolgen erscheinen nur, wenn sie etwas besagen;
// der Status steht in den Auswahlchips.
String _zusatztext(Gefechtsgegner g) {
  final wunden = gefechtsGegnerstand(g).wunden;
  return [
    if (g.groesse != GefechtsGroesse.mittel) gefechtsGroesseLabel[g.groesse]!,
    if (g.koerperbau == GefechtsKoerperbau.tier) 'Tier',
    if (wunden > 0) wunden == 1 ? '1 Wunde' : '$wunden Wunden',
    if (g.liegend) 'Liegend',
    if (g.entwaffnet) 'Entwaffnet',
  ].join(' · ');
}

/// Validiert ausdrücklich eingegebene Gegnerwerte ohne verdeckte Standardwerte.
///
/// LeP, RS und KO dürfen leer bleiben und gelten dann als unbekannt.
class GefechtGegnerdialog extends StatefulWidget {
  /// Ohne Gegner wird eine neue stabile Identität vergeben.
  const GefechtGegnerdialog({super.key, this.gegner});
  final Gefechtsgegner? gegner;
  @override
  State<GefechtGegnerdialog> createState() => _GefechtGegnerdialogState();
}

class _GefechtGegnerdialogState extends State<GefechtGegnerdialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.gegner?.name);
  late final _lep = TextEditingController(text: widget.gegner?.lep?.toString());
  late final _rs = TextEditingController(text: widget.gegner?.rs?.toString());
  late final _ko = TextEditingController(text: widget.gegner?.ko?.toString());
  late final _ini = TextEditingController(text: widget.gegner?.ini.toString());
  late var _groesse = widget.gegner?.groesse ?? GefechtsGroesse.mittel;
  late var _koerperbau =
      widget.gegner?.koerperbau ?? GefechtsKoerperbau.zweibeiner;
  @override
  void dispose() {
    for (final c in [_name, _lep, _rs, _ko, _ini]) {
      c.dispose();
    }
    super.dispose();
  }

  // Ganze Zahlen werden hier erfasst; fachliche Prüfung liegt im Regelmodul.
  Widget _zahl(
    String titel,
    TextEditingController c, {
    int? minimum,
    bool optional = false,
  }) => TextFormField(
    controller: c,
    decoration: InputDecoration(
      labelText: titel,
      hintText: optional ? 'unbekannt' : null,
    ),
    keyboardType: const TextInputType.numberWithOptions(signed: true),
    validator: (v) {
      final text = (v ?? '').trim();
      if (optional && text.isEmpty) return null;
      final n = int.tryParse(text);
      if (n == null) return 'Gültige ganze Zahl eingeben.';
      if (minimum != null && n < minimum) return 'Mindestens $minimum.';
      return null;
    },
  );

  int? _optional(TextEditingController c) => int.tryParse(c.text.trim());

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.gegner == null ? 'Gegner hinzufügen' : 'Gegner ändern'),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Name eingeben.' : null,
              ),
              _zahl('INI', _ini),
              _zahl('LeP zu Beginn', _lep, minimum: 1, optional: true),
              _zahl('RS', _rs, minimum: 0, optional: true),
              _zahl('KO', _ko, minimum: 1, optional: true),
              DropdownButtonFormField<GefechtsGroesse>(
                key: const ValueKey('gegner-groesse'),
                initialValue: _groesse,
                decoration: const InputDecoration(labelText: 'Größenklasse'),
                items: [
                  for (final g in GefechtsGroesse.values)
                    DropdownMenuItem(
                      value: g,
                      child: Text(gefechtsGroesseLabel[g]!),
                    ),
                ],
                onChanged: (v) => setState(() => _groesse = v ?? _groesse),
              ),
              DropdownButtonFormField<GefechtsKoerperbau>(
                key: const ValueKey('gegner-koerperbau'),
                initialValue: _koerperbau,
                decoration: const InputDecoration(labelText: 'Körperbau'),
                items: const [
                  DropdownMenuItem(
                    value: GefechtsKoerperbau.zweibeiner,
                    child: Text('Zweibeiner'),
                  ),
                  DropdownMenuItem(
                    value: GefechtsKoerperbau.tier,
                    child: Text('Tier'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _koerperbau = v ?? _koerperbau),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          // Nur die Grundwerte; der Controller legt sie auf den frischen Gegner.
          final g = Gefechtsgegner(
            id: widget.gegner?.id ?? UniqueKey().toString(),
            name: _name.text.trim(),
            lep: _optional(_lep),
            rs: _optional(_rs),
            ko: _optional(_ko),
            ini: int.parse(_ini.text.trim()),
            groesse: _groesse,
            koerperbau: _koerperbau,
          );
          Navigator.pop(context, g);
        },
        child: const Text('Übernehmen'),
      ),
    ],
  );
}

/// Bestätigt einen tatsächlichen gewöhnlichen Treffer vor dem LeP-Abzug.
class GefechtGegnerschadendialog extends StatefulWidget {
  /// RS wird bei der Buchung frisch aus der Begegnung verwendet.
  const GefechtGegnerschadendialog({super.key, required this.gegner});
  final Gefechtsgegner gegner;
  @override
  State<GefechtGegnerschadendialog> createState() =>
      _GefechtGegnerschadendialogState();
}

class _GefechtGegnerschadendialogState
    extends State<GefechtGegnerschadendialog> {
  final _tp = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _tp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Treffer gegen ${widget.gegner.name}'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.gegner.rs == null
                  ? 'Nur einen tatsächlich nicht abgewehrten Treffer übernehmen. '
                        'RS unbekannt: Die TP werden verrechnet, sobald er '
                        'eingetragen ist. Besondere Folgen gesondert abwickeln.'
                  : 'Nur einen tatsächlich nicht abgewehrten Treffer übernehmen. '
                        'RS wird abgezogen; Wunden zählen nach KO, besondere '
                        'Folgen gesondert abwickeln.',
            ),
            TextFormField(
              controller: _tp,
              decoration: const InputDecoration(labelText: 'Trefferpunkte'),
              keyboardType: TextInputType.number,
              validator: (v) {
                final tp = int.tryParse(v ?? '');
                return tp == null || tp < 0
                    ? 'TP mindestens 0 eingeben.'
                    : null;
              },
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
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, int.parse(_tp.text));
          }
        },
        child: const Text('Treffer bestätigt'),
      ),
    ],
  );
}
