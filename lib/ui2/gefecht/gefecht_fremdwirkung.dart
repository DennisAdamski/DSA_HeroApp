import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_fremdwirkung.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_fremdwirkung_rules.dart';

/// Erfasst konkrete Voraussetzungen und friert das Ziel vor der Startprobe ein.
Future<GefechtsFremdwirkung?> zeigeGefechtsFremdziel({
  required BuildContext context,
  required String zauberId,
  required List<Gefechtsgegner> gegner,
  required int verfuegbareAsp,
  String? gegnerId,
}) async {
  if (!gefechtsFremdprofilUnterstuetzt(zauberId) || gegner.isEmpty) return null;
  String id = gegner.any((g) => g.id == gegnerId) ? gegnerId! : gegner.first.id;
  bool reichweite = false, schutz = false, grundform = false;
  return showDialog<GefechtsFremdwirkung>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (_, setState) => AlertDialog(
        title: const Text('Fulminictus · Fremdziel'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: id,
                  decoration: const InputDecoration(
                    labelText: 'Ursprüngliches Ziel',
                  ),
                  items: [
                    for (final g in gegner)
                      DropdownMenuItem(
                        value: g.id,
                        child: Text('${g.name} · ${g.lep} LeP'),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    id = value!;
                    reichweite = false;
                    schutz = false;
                  }),
                ),
                CheckboxListTile(
                  title: const Text(
                    'Lebendes Einzelwesen in höchstens 7 Schritt',
                  ),
                  value: reichweite,
                  onChanged: (v) => setState(() => reichweite = v!),
                ),
                CheckboxListTile(
                  title: const Text(
                    'Kein magischer Schutz oder besondere Abwehr',
                  ),
                  subtitle: const Text(
                    'Kein Gardianum, Invercano, Aurapanzer oder '
                    'dämonischer MR-Schild; keine besondere Magieresistenz.',
                  ),
                  value: schutz,
                  onChanged: (v) => setState(() => schutz = v!),
                ),
                CheckboxListTile(
                  title: const Text(
                    'Grundform ohne Varianten und Sonderfertigkeiten',
                  ),
                  subtitle: const Text(
                    '2 Aktionen, 2W6 + ZfP* direkte SP. '
                    'Kein Reversalis, keine spontane Modifikation oder '
                    'abweichende Repräsentationsregel.',
                  ),
                  value: grundform,
                  onChanged: (v) => setState(() => grundform = v!),
                ),
                Text(
                  'Startenergie: $verfuegbareAsp AsP. Gewöhnlicher RS und '
                  'Armatrutz mindern die SP nicht; keine Wunden.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: !reichweite || !schutz || !grundform
                ? null
                : () {
                    Navigator.pop(
                      dialogContext,
                      GefechtsFremdwirkung(
                        zauberId: zauberId,
                        gegnerId: id,
                        verfuegbareAsp: verfuegbareAsp,
                      ),
                    );
                  },
            child: const Text('Ziel festhalten'),
          ),
        ],
      ),
    ),
  );
}

/// Sammelt einmal zwei reale W6; Abbruch lässt die ursprüngliche Probe bestehen.
Future<GefechtsFremdwirkungswurf?> zeigeGefechtsFremdwirkungswurf({
  required BuildContext context,
  required GefechtsFremdwirkung ziel,
  required ProbeResult probe,
}) async {
  int? erster, zweiter;
  return showDialog<GefechtsFremdwirkungswurf>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (_, setState) {
        final wurf = erster == null || zweiter == null
            ? null
            : gefechtsFulminictusWurf(
                ziel: ziel,
                probe: probe,
                ersterW6: erster!,
                zweiterW6: zweiter!,
              );
        Widget wuerfel(String label, int? wert, ValueChanged<int> setzen) =>
            DropdownButtonFormField<int>(
              initialValue: wert,
              decoration: InputDecoration(labelText: label),
              items: [
                for (var n = 1; n <= 6; n++)
                  DropdownMenuItem(value: n, child: Text('$n')),
              ],
              onChanged: (v) => setState(() => setzen(v!)),
            );
        return AlertDialog(
          title: const Text('Fulminictus · Schadenswurf'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ursprüngliche Probe: ${probe.remainingPool} ZfP*. '
                  'Zwei W6 am Spieltisch würfeln und eintragen.',
                ),
                wuerfel('Erster W6', erster, (v) => erster = v),
                wuerfel('Zweiter W6', zweiter, (v) => zweiter = v),
                if (wurf != null)
                  Text(
                    '${wurf.schaden} direkte SP · '
                    '${wurf.kosten} AsP. Auf die Startenergie begrenzt.',
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Später eintragen'),
            ),
            FilledButton(
              onPressed: wurf == null
                  ? null
                  : () => Navigator.pop(dialogContext, wurf),
              child: const Text('Schadenswurf festhalten'),
            ),
          ],
        );
      },
    ),
  );
}
