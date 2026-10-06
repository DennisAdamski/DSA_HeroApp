import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_gegner_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_vorgaben_rules.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_begegnung_provider.dart';

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
    Future<void> bearbeiten([Gefechtsgegner? g]) async {
      final neu = await showDialog<Gefechtsgegner>(
        context: context,
        builder: (_) => GefechtGegnerdialog(gegner: g),
      );
      if (neu != null) controller.speichern(neu);
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
            if (begegnung.gegner.isEmpty)
              const Text(
                'Name, LeP, RS und INI erfassen. Nur für diese Begegnung.',
              ),
            for (final g in begegnung.gegner.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${g.name} · LeP ${g.lep} · RS ${g.rs} · INI ${g.ini}',
                    ),
                    if (g.liegend || g.entwaffnet)
                      Text(
                        '${g.liegend ? "Liegend " : ""}${g.entwaffnet ? "Entwaffnet" : ""}',
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          key: ValueKey('gegner-ziel-${g.id}'),
                          onPressed: blockiert || s == null
                              ? null
                              : () => onAktion(() async {
                                  ref
                                      .read(gefechtProvider(heroId).notifier)
                                      .setzen(
                                        waehleGefechtsgegner(
                                          s,
                                          g,
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
                      ],
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

/// Validiert ausdrücklich eingegebene Gegnerwerte ohne verdeckte Standardwerte.
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
  late final _lep = TextEditingController(text: widget.gegner?.lep.toString());
  late final _rs = TextEditingController(text: widget.gegner?.rs.toString());
  late final _ini = TextEditingController(text: widget.gegner?.ini.toString());
  @override
  void dispose() {
    for (final c in [_name, _lep, _rs, _ini]) {
      c.dispose();
    }
    super.dispose();
  }

  // Ganze Zahlen werden hier erfasst; fachliche Prüfung liegt im Regelmodul.
  Widget _zahl(String titel, TextEditingController c, {bool positiv = false}) =>
      TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: titel),
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        validator: (v) {
          final n = int.tryParse(v ?? '');
          return n == null || positiv && n < 0
              ? 'Gültige ganze Zahl eingeben.'
              : null;
        },
      );

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
              _zahl('LeP', _lep),
              _zahl('RS', _rs, positiv: true),
              _zahl('INI', _ini),
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
          final g = Gefechtsgegner(
            id: widget.gegner?.id ?? UniqueKey().toString(),
            name: _name.text.trim(),
            lep: int.parse(_lep.text),
            rs: int.parse(_rs.text),
            ini: int.parse(_ini.text),
            liegend: widget.gegner?.liegend ?? false,
            entwaffnet: widget.gegner?.entwaffnet ?? false,
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
            const Text(
              'Nur einen tatsächlich nicht abgewehrten Treffer übernehmen. '
              'RS wird abgezogen; Wunden und besondere Folgen gesondert abwickeln.',
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
