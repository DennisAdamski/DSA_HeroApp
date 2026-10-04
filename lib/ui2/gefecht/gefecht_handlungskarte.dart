import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_laden_rules.dart';

/// Kompakte Resthandlung mit eingefrorener Probe und offenen Abschlussfolgen.
Widget gefechtsHandlungskarte(
  Gefechtszustand s, {
  required bool gesperrt,
  required VoidCallback onFortsetzen,
  required VoidCallback onAbbruch,
  required VoidCallback onStoerung,
  Gefechtsvorbereitungspruefung? vorbereitung,
  List<String> schussgruende = const [],
}) {
  final h = s.handlung!;
  final rest = vorbereitung?.rest ?? h.verbleibend;
  final schuss = h.art == Gefechtshandlungsart.zielen && rest == 0;
  final gruende = [...?vorbereitung?.gruende, ...schussgruende];
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${h.titel} · noch $rest Aktionen'),
          if (vorbereitung != null)
            Text(
              '${vorbereitung.bezahlt} bezahlt · aktuell ${vorbereitung.dauer} Aktionen',
            ),
          for (final hinweis in vorbereitung?.hinweise ?? <String>[])
            Text(hinweis),
          for (final grund in gruende) Text(grund),
          if (h.ergebnis != null)
            Text(
              'Probe eingefroren: ${h.ergebnis!.success ? 'gelungen' : 'misslungen'}',
            ),
          if (h.kostenUebernommen)
            const Text('Kosten übernommen · Folgen offen'),
          FilledButton.tonal(
            onPressed: gesperrt || gruende.isNotEmpty ? null : onFortsetzen,
            child: Text(
              schuss
                  ? 'Schuss ausführen'
                  : rest == 0
                  ? h.art == Gefechtshandlungsart.laden
                        ? 'Laden abschließen'
                        : 'Übernahme erneut versuchen'
                  : 'Fortsetzen',
            ),
          ),
          if (h.art != Gefechtshandlungsart.fernkampf)
            TextButton(
              onPressed: gesperrt ? null : onAbbruch,
              child: const Text('Handlung abbrechen'),
            ),
          if (h.wirken != null)
            TextButton(
              onPressed: gesperrt ? null : onStoerung,
              child: const Text('Störung'),
            ),
        ],
      ),
    ),
  );
}
