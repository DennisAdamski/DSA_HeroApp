import 'package:flutter/material.dart';

/// Fragt im Kartograph-Stil nach und liefert `true` nur bei Bestätigung.
///
/// Abbrechen, Zurück und Tippen neben den Dialog ergeben `false`. Den Knopf
/// der Bestätigung kennzeichnet [bestaetigenKey] für Tests.
Future<bool> kartoBestaetigen(
  BuildContext context, {
  required String titel,
  required String text,
  required String bestaetigen,
  String abbrechen = 'Abbrechen',
  Key? bestaetigenKey,
}) async {
  final ja = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(titel),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(abbrechen),
        ),
        FilledButton(
          key: bestaetigenKey,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(bestaetigen),
        ),
      ],
    ),
  );
  return ja ?? false;
}
