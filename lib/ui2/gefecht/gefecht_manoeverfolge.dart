import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_angriff.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_angriff_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_manoeverfolgen_rules.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_begegnung_provider.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

/// Geführte schadenslose Gegenprobe gegen den ursprünglich gewählten Gegner.
class GefechtManoeverfolge extends ConsumerWidget {
  /// Jeder Folgeschritt bleibt mit dem gebuchten Angriff verbunden.
  const GefechtManoeverfolge({
    super.key,
    required this.heroId,
    required this.e,
    required this.bestand,
    required this.gesperrt,
    required this.onAktion,
  });
  final String heroId;
  final Gefechtsangriffsergebnis e;
  final KartoGefechtsAdapter bestand;
  final bool gesperrt;
  final Future<void> Function(Future<void> Function()) onAktion;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gefechtBegegnungProvider).gegner[e.gegnerId];
    final ctl = ref.read(gefechtProvider(heroId).notifier);
    final umreissen = e.manoeverId == 'man_umreissen';
    void speichern(
      Gefechtsangriffsergebnis Function(Gefechtsangriffsergebnis) aendern,
    ) {
      final s = ref.read(gefechtProvider(heroId));
      if (s == null) return;
      ctl.setzen(
        s.copyWith(
          angriffsergebnisse: List.unmodifiable([
            for (final aktuell in s.angriffsergebnisse)
              if (aktuell.auftragId == e.auftragId)
                aendern(aktuell)
              else
                aktuell,
          ]),
        ),
      );
    }

    void erledigt() {
      final s = ref.read(gefechtProvider(heroId));
      if (s != null) {
        ctl.setzen(entferneGefechtsAngriffsergebnis(s, e.auftragId));
      }
    }

    Future<void> wuerfeln(
      ResolvedProbeRequest request,
      void Function(ProbeResult) buchen,
    ) => bestand
        .gefechtsProbe(
          context: context,
          ref: ref,
          heroId: heroId,
          request: request,
          onResolved: buchen,
        )
        .then((_) {});
    if (g == null) {
      return const Text(
        'Ursprünglicher Gegner fehlt; keine automatische Folge.',
      );
    }
    if (!e.abwehrGeklaert) {
      return Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: gesperrt ? null : erledigt,
            child: const Text('Gegner hat abgewehrt · keine Folge'),
          ),
          FilledButton(
            onPressed: gesperrt
                ? null
                : () => speichern((a) => a.mitFolge(abwehrGeklaert: true)),
            child: const Text('Abwehr misslungen · Gegenprobe'),
          ),
        ],
      );
    }
    if (umreissen && e.folgeTp == null) {
      final dice = e.folgewuerfel;
      if (dice == null) {
        return const Text('TP-Profil für GE-Erschwernis fehlt.');
      }
      return TextButton(
        onPressed: gesperrt
            ? null
            : () => onAktion(
                () => wuerfeln(
                  ResolvedProbeRequest(
                    type: ProbeType.damage,
                    title: 'Umreißen · GE-Erschwernis',
                    subtitle: dice.label,
                    ruleHint: 'Kein Schaden; TP erschweren nur die GE-Probe.',
                    diceSpec: dice,
                    targets: const [],
                  ),
                  (r) => speichern(
                    (a) => a.folgeTp == null
                        ? a.mitFolge(folgeTp: r.total < 0 ? 0 : r.total)
                        : a,
                  ),
                ),
              ),
        child: const Text('GE-Erschwernis würfeln · kein LeP-Schaden'),
      );
    }
    if (e.gegenprobeErfolg == null) {
      return TextButton(
        onPressed: gesperrt
            ? null
            : () => onAktion(() async {
                final profil = await showDialog<({int wert, int bonus})>(
                  context: context,
                  builder: (_) => _Gegenprofil(umreissen: umreissen),
                );
                if (profil == null || !context.mounted) return;
                final request = gefechtsGegenprobe(
                  e.manoeverId!,
                  eigenschaft: profil.wert,
                  meisterlich: e.meisterlichesEntwaffnen,
                  tp: e.folgeTp,
                  standBonus: profil.bonus,
                );
                await wuerfeln(
                  request,
                  (r) => speichern(
                    (a) => a.gegenprobeErfolg == null
                        ? a.mitFolge(gegenprobeErfolg: r.success)
                        : a,
                  ),
                );
              }),
        child: Text('Gegnerische ${umreissen ? "GE" : "KK"}-Probe'),
      );
    }
    if (e.gegenprobeErfolg == true) {
      return TextButton(
        onPressed: gesperrt ? null : erledigt,
        child: const Text('Gegenprobe gelungen · keine Folge'),
      );
    }
    if (umreissen && e.iniVerlust == null) {
      return TextButton(
        onPressed: gesperrt
            ? null
            : () => onAktion(
                () => wuerfeln(
                  const ResolvedProbeRequest(
                    type: ProbeType.genericRoll,
                    title: 'Umreißen · INI-Verlust',
                    subtitle: '2W6',
                    ruleHint: 'Gegner liegt, keine LeP-Kosten.',
                    diceSpec: DiceSpec(count: 2, sides: 6),
                    targets: [],
                  ),
                  (r) => speichern(
                    (a) => a.iniVerlust == null
                        ? a.mitFolge(iniVerlust: r.total)
                        : a,
                  ),
                ),
              ),
        child: const Text('INI-Verlust würfeln · 2W6'),
      );
    }
    return FilledButton(
      onPressed: gesperrt
          ? null
          : () {
              final s = ref.read(gefechtProvider(heroId));
              final frisch = ref
                  .read(gefechtBegegnungProvider)
                  .gegner[e.gegnerId];
              if (frisch == null ||
                  s == null ||
                  !s.angriffsergebnisse.any(
                    (a) => a.auftragId == e.auftragId,
                  )) {
                return;
              }
              ref
                  .read(gefechtBegegnungProvider.notifier)
                  .speichern(
                    gefechtsManoeverfolge(
                      frisch,
                      e.manoeverId!,
                      gegenprobeErfolg: false,
                      iniVerlust: e.iniVerlust,
                    ),
                  );
              erledigt();
            },
      child: Text(
        umreissen
            ? 'Liegend und INI-Verlust übernehmen'
            : 'Entwaffnung übernehmen',
      ),
    );
  }
}

// Eigenschaft und belegte Standvorteile werden konkret erfragt, niemals aus LeP geraten.
class _Gegenprofil extends StatefulWidget {
  const _Gegenprofil({required this.umreissen});
  final bool umreissen;
  @override
  State<_Gegenprofil> createState() => _GegenprofilState();
}

class _GegenprofilState extends State<_Gegenprofil> {
  final _wert = TextEditingController();
  final _form = GlobalKey<FormState>();
  int _bonus = 0;
  @override
  void dispose() {
    _wert.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Gegnerische Gegenprobe'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _wert,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: widget.umreissen
                    ? 'Gegnerische GE'
                    : 'Gegnerische KK',
              ),
              validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1
                  ? 'Eigenschaft mindestens 1.'
                  : null,
            ),
            if (widget.umreissen)
              DropdownButtonFormField<int>(
                initialValue: 0,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Standvorteil des Gegners',
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Keiner')),
                  DropdownMenuItem(value: 2, child: Text('Standfest (+2)')),
                  DropdownMenuItem(value: 4, child: Text('Balance (+4)')),
                  DropdownMenuItem(
                    value: 8,
                    child: Text('Herausragende Balance (+8)'),
                  ),
                ],
                onChanged: (v) => _bonus = v ?? 0,
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
            Navigator.pop(context, (
              wert: int.parse(_wert.text),
              bonus: _bonus,
            ));
          }
        },
        child: const Text('Probe'),
      ),
    ],
  );
}
