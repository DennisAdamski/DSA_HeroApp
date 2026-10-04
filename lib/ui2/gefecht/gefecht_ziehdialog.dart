import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ziehen_rules.dart';

/// Fragt nur fehlende Bereitschaft und Handbelegung ab; SF kommt vom Helden.
Future<GefechtsZiehplan?> zeigeGefechtsZiehkontext(
  BuildContext context, {
  required bool schnellziehen,
  bool schild = false,
}) async {
  Ziehposition? position = schild ? Ziehposition.schildRuecken : null;
  var frei = false;
  return showDialog<GefechtsZiehplan>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, aktualisieren) {
        final plan = position == null
            ? null
            : gefechtsZiehplan(position!, schnellziehen: schnellziehen);
        return AlertDialog(
          title: Text(schild ? 'Schild bereitmachen' : 'Waffe ziehen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  schnellziehen ? 'Schnellziehen aktiv' : 'Ohne Schnellziehen',
                ),
                if (!schild)
                  DropdownButtonFormField<Ziehposition>(
                    isExpanded: true,
                    initialValue: position,
                    decoration: const InputDecoration(
                      labelText: 'Trageposition',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: Ziehposition.guertel,
                        child: Text('Gürtel / Arm / Brust'),
                      ),
                      DropdownMenuItem(
                        value: Ziehposition.ruecken,
                        child: Text('Rücken'),
                      ),
                    ],
                    onChanged: (v) => aktualisieren(() {
                      position = v;
                      frei = false;
                    }),
                  ),
                CheckboxListTile(
                  value: frei,
                  title: const Text(
                    'Griffbereit, geeignete Scheide und Hände frei',
                  ),
                  subtitle: const Text(
                    'Wegstecken, Aufheben und ungewöhnliche Wechsel '
                    'zuerst als manuelle Teilhandlung führen.',
                  ),
                  onChanged: (v) => aktualisieren(() {
                    frei = v!;
                  }),
                ),
                if (plan != null)
                  Text(
                    plan.freieMarke
                        ? 'Kosten: eine freie Marke'
                        : 'Dauer: ${plan.dauer} Aktionen',
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: frei && plan != null
                  ? () => Navigator.pop(context, plan)
                  : null,
              child: const Text('Wechsel beginnen'),
            ),
          ],
        );
      },
    ),
  );
}
