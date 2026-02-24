import 'package:flutter/material.dart';

/// Zeigt den Standarddialog zum Verwerfen ungespeicherter Tab-Aenderungen.
Future<bool> showWorkspaceDiscardDialog(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Ungespeicherte Änderungen verwerfen?'),
        content: const Text(
          'Wenn du fortfährst, gehen die ungespeicherten Änderungen '
          'im aktuellen Tab verloren.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Nein'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Ja'),
          ),
        ],
      );
    },
  );
  return discard == true;
}
