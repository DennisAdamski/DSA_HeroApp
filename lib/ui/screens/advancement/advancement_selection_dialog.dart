import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';

/// Verlangt eine bewusste Auswahl für Erwerbe mit mehreren Regeloptionen.
Future<T?> showAdvancementSelectionDialog<T>({
  required BuildContext context,
  required String title,
  required String description,
  required List<T> choices,
  required String Function(T) label,
}) {
  return showAdaptiveInputDialog<T>(
    context: context,
    builder: (dialogContext) => AdaptiveInputDialog(
      title: title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(description),
          const SizedBox(height: 12),
          if (choices.isEmpty) const Text('Keine passende Auswahl verfügbar.'),
          for (final choice in choices)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(choice),
                child: Text(label(choice)),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Abbrechen'),
        ),
      ],
    ),
  );
}
