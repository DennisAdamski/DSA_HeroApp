import 'package:flutter/material.dart';

/// Zeigt eine einfache Info-SnackBar.
///
/// No-op, wenn [context] nicht mehr mounted ist (z. B. nach einem
/// async-Gap), damit Aufrufer keinen eigenen Guard brauchen.
void showInfoSnackBar(BuildContext context, String message) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Zeigt eine Fehler-SnackBar im Format `prefix: error`.
void showErrorSnackBar(
  BuildContext context,
  Object error, {
  String prefix = 'Fehler',
}) {
  showInfoSnackBar(context, '$prefix: $error');
}
