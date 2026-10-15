import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/catalog/alchimikum_def.dart';
import 'package:dsa_heldenverwaltung/rules/derived/alchimika_rules.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

/// Gewähltes Katalogmittel mit Qualitätsstufe (`null` bei Mitteln ohne Stufen).
class AlchimikumWahl {
  /// Erstellt die Wahl.
  const AlchimikumWahl(this.mittel, this.stufe);

  /// Das gewählte Mittel.
  final AlchimikumDef mittel;

  /// Qualitätsstufe `A` bis `F` oder `null`.
  final String? stufe;
}

/// Fragt Mittel und Qualitätsstufe aus dem Katalog ab (TRANK).
///
/// Der Dialog rechnet nichts: Er zeigt Beschreibung und Würfelvorschläge aus
/// `alchimika_rules.dart` und liefert die Wahl zurück. Übernommen wird erst
/// im Inventareditor.
Future<AlchimikumWahl?> zeigeAlchimikaAuswahl({
  required BuildContext context,
  required List<AlchimikumDef> mittel,
}) {
  return showAdaptiveDetailSheet<AlchimikumWahl>(
    context: context,
    builder: (sheetContext) => _AlchimikaAuswahl(mittel: mittel),
  );
}

class _AlchimikaAuswahl extends StatefulWidget {
  const _AlchimikaAuswahl({required this.mittel});

  final List<AlchimikumDef> mittel;

  @override
  State<_AlchimikaAuswahl> createState() => _AlchimikaAuswahlState();
}

class _AlchimikaAuswahlState extends State<_AlchimikaAuswahl> {
  // Qualität C ist die Preisangabe der Regelbücher und deshalb die Vorgabe.
  static const String _vorgabeStufe = 'C';

  AlchimikumDef? _gewaehlt;
  String? _stufe;

  void _waehle(AlchimikumDef mittel) {
    // Eine bereits gewählte Stufe bleibt beim Wechsel erhalten, soweit das
    // neue Mittel sie kennt.
    final bisher = _stufe ?? _vorgabeStufe;
    final stufe = !mittel.hatQualitaeten
        ? null
        : alchimikumStufe(mittel, bisher) != null
        ? bisher
        : mittel.qualitaeten.first.stufe;
    setState(() {
      _gewaehlt = mittel;
      _stufe = stufe;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gewaehlt = _gewaehlt;
    return AlertDialog(
      key: const ValueKey<String>('alchimika-auswahl'),
      title: const Text('Trank oder Heilmittel aus dem Katalog'),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final mittel in widget.mittel)
                    ChoiceChip(
                      key: ValueKey<String>('alchimika-mittel-${mittel.id}'),
                      label: Text(mittel.name),
                      selected: gewaehlt?.id == mittel.id,
                      onSelected: (_) => _waehle(mittel),
                    ),
                ],
              ),
              if (gewaehlt != null) ...[
                const SizedBox(height: kDialogFieldSpacing),
                if (gewaehlt.hatQualitaeten) ...[
                  Text('Qualität', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final stufe in gewaehlt.qualitaeten)
                        ChoiceChip(
                          key: ValueKey<String>(
                            'alchimika-stufe-${stufe.stufe}',
                          ),
                          label: Text(stufe.stufe),
                          selected: _stufe == stufe.stufe,
                          onSelected: (_) =>
                              setState(() => _stufe = stufe.stufe),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Qualität C entspricht der Preisangabe der Regelbücher. '
                    'Misslungene Mittel (M) entscheidet der Meister.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: kDialogFieldSpacing),
                Text(
                  alchimikumBeschreibung(gewaehlt, _stufe),
                  key: const ValueKey<String>('alchimika-vorschau'),
                  style: theme.textTheme.bodyMedium,
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Wähle ein Mittel. Name, Beschreibung, Richtpreis und die '
                    'Vorbelegung für „Anwenden“ werden in den Eintrag '
                    'übernommen; alles bleibt danach änderbar.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('alchimika-abbrechen'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('alchimika-uebernehmen'),
          onPressed: gewaehlt == null
              ? null
              : () =>
                    Navigator.of(context).pop(AlchimikumWahl(gewaehlt, _stufe)),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
