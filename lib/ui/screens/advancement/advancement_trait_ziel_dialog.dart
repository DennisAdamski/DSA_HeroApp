import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/trait_advancement_rules.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';

/// Gewählter Zielstand beim Abbau eines Nachteils.
typedef NachteilZielWahl = ({int ziel, SchlechteEigenschaftLernweg lernweg});

/// Fragt Zielwert und — bei Schlechten Eigenschaften — den Lernweg ab.
///
/// [kosten] liefert die AP für einen Zielstand aus der Regelauflösung; der
/// Dialog rechnet selbst nichts. `0` als Ziel heißt vollständig abgebaut.
Future<NachteilZielWahl?> showNachteilZielDialog({
  required BuildContext context,
  required String titel,
  required int aktuellerWert,
  required int mindestwert,
  required bool stufenweise,
  required bool schlechteEigenschaft,
  required bool episch,
  required int? Function(int ziel, SchlechteEigenschaftLernweg lernweg) kosten,
}) {
  return showAdaptiveInputDialog<NachteilZielWahl>(
    context: context,
    builder: (_) => _NachteilZielDialog(
      titel: titel,
      aktuellerWert: aktuellerWert,
      mindestwert: mindestwert,
      stufenweise: stufenweise,
      schlechteEigenschaft: schlechteEigenschaft,
      episch: episch,
      kosten: kosten,
    ),
  );
}

class _NachteilZielDialog extends StatefulWidget {
  const _NachteilZielDialog({
    required this.titel,
    required this.aktuellerWert,
    required this.mindestwert,
    required this.stufenweise,
    required this.schlechteEigenschaft,
    required this.episch,
    required this.kosten,
  });

  final String titel;
  final int aktuellerWert;
  final int mindestwert;
  final bool stufenweise;
  final bool schlechteEigenschaft;
  final bool episch;
  final int? Function(int ziel, SchlechteEigenschaftLernweg lernweg) kosten;

  @override
  State<_NachteilZielDialog> createState() => _NachteilZielDialogState();
}

class _NachteilZielDialogState extends State<_NachteilZielDialog> {
  late int _ziel = widget.stufenweise ? widget.aktuellerWert - 1 : 0;
  SchlechteEigenschaftLernweg _lernweg =
      SchlechteEigenschaftLernweg.spezielleErfahrung;

  // Unter dem Katalogminimum ist der Nachteil abgebaut; das steht als 0.
  List<int> get _ziele => [
    if (widget.stufenweise)
      for (
        var wert = widget.aktuellerWert - 1;
        wert >= widget.mindestwert;
        wert--
      )
        wert,
    0,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ap = widget.kosten(_ziel, _lernweg);
    return AlertDialog(
      title: Text('${widget.titel} abbauen'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.stufenweise) ...[
                Text('Aktueller Wert: ${widget.aktuellerWert}'),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  key: const ValueKey('advancement-nachteil-ziel'),
                  initialValue: _ziel,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Neuer Wert'),
                  items: [
                    for (final wert in _ziele)
                      DropdownMenuItem(
                        value: wert,
                        child: Text(
                          wert == 0 ? 'Vollständig abbauen' : '$wert',
                        ),
                      ),
                  ],
                  onChanged: (wert) => setState(() => _ziel = wert ?? _ziel),
                ),
                const SizedBox(height: 12),
              ],
              if (widget.schlechteEigenschaft) ...[
                Text('Lernweg', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                RadioGroup<SchlechteEigenschaftLernweg>(
                  groupValue: _lernweg,
                  onChanged: (weg) => setState(() => _lernweg = weg!),
                  child: Column(
                    children: [
                      for (final weg in SchlechteEigenschaftLernweg.values)
                        RadioListTile<SchlechteEigenschaftLernweg>(
                          key: ValueKey('advancement-nachteil-${weg.name}'),
                          value: weg,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          enabled:
                              !widget.episch ||
                              weg ==
                                  SchlechteEigenschaftLernweg
                                      .spezielleErfahrung,
                          title: Text(
                            '${weg.label} (${weg.faktor} × GP je Punkt)',
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.episch)
                  Text(
                    'Epische Helden bauen Nachteile nur über Spezielle '
                    'Erfahrungen ab (Epische Stufen S. 5).',
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
              ],
              Text(
                ap == null ? 'Kosten nicht bestimmbar' : 'Kosten: $ap AP',
                key: const ValueKey('advancement-nachteil-kosten'),
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey('advancement-nachteil-weiter'),
          onPressed: () =>
              Navigator.of(context).pop((ziel: _ziel, lernweg: _lernweg)),
          child: const Text('Weiter'),
        ),
      ],
    );
  }
}
