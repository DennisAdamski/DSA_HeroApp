import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';

/// Zeigt den Standarddialog zum Verwerfen ungespeicherter Tab-Aenderungen.
Future<bool> showWorkspaceDiscardDialog(BuildContext context) async {
  return showAdaptiveConfirmDialog(
    context: context,
    title: 'Ungespeicherte Änderungen verwerfen?',
    content:
        'Wenn du fortfährst, gehen die ungespeicherten Änderungen '
        'im aktuellen Tab verloren.',
    cancelLabel: 'Nein',
    confirmLabel: 'Ja',
    isDestructive: true,
  );
}
