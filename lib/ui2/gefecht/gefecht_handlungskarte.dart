import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';

/// Kompakte Resthandlung mit eingefrorener Probe und offenen Abschlussfolgen.
Widget gefechtsHandlungskarte(
  Gefechtszustand s, {
  required bool gesperrt,
  required VoidCallback onFortsetzen,
  required VoidCallback onAbbruch,
  required VoidCallback onStoerung,
}) {
  final h = s.handlung!;
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${h.titel} · noch ${h.verbleibend} Aktionen'),
          if (h.ergebnis != null)
            Text(
              'Probe eingefroren: ${h.ergebnis!.success ? 'gelungen' : 'misslungen'}',
            ),
          if (h.kostenUebernommen)
            const Text('Kosten übernommen · Folgen offen'),
          FilledButton.tonal(
            onPressed: gesperrt ? null : onFortsetzen,
            child: Text(
              h.verbleibend == 0 ? 'Übernahme erneut versuchen' : 'Fortsetzen',
            ),
          ),
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
