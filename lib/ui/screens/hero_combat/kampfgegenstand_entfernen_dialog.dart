import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/kampfgegenstand_ablegen_rules.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';

/// Fragt, ob ein im Kampfbereich entfernter Gegenstand nur abgelegt oder
/// ganz entfernt wird (ARCH-03, Entscheidung vom 06.10.2026).
///
/// [art] benennt den Bereich im Satz („den Waffen“, „der Rüstung“ …).
/// Liefert `null` bei Abbruch.
Future<KampfgegenstandEntfernen?> frageKampfgegenstandEntfernen(
  BuildContext context, {
  required String titel,
  required String name,
  required String art,
  bool mitGeschossen = false,
}) async {
  final anzeigeName = name.trim().isEmpty ? 'Dieser Gegenstand' : '„$name“';
  final geschosse = mitGeschossen
      ? ' Die Geschosse der Waffe bleiben in jedem Fall im Inventar.'
      : '';
  final ergebnis = await showAdaptiveConfirmDialog(
    context: context,
    title: titel,
    content:
        '$anzeigeName nur aus $art ablegen? Der Gegenstand bleibt dann im '
        'Inventar und lässt sich von dort zurückholen. „Ganz entfernen“ '
        'löscht ihn auch aus dem Inventar.$geschosse',
    saveLabel: 'Nur ablegen',
    confirmLabel: 'Ganz entfernen',
    isDestructive: true,
  );
  return _alsEntscheidung(ergebnis);
}

/// Fragt beim Speichern einer Waffe, was mit den im Editor entfernten
/// Geschossen [namen] geschieht. Liefert `null` bei Abbruch; dann wird die
/// Waffe nicht gespeichert.
Future<KampfgegenstandEntfernen?> frageGeschosseEntfernen(
  BuildContext context,
  List<String> namen,
) async {
  final liste = namen.map((name) => '„$name“').join(', ');
  final ergebnis = await showAdaptiveConfirmDialog(
    context: context,
    title: namen.length == 1 ? 'Geschoss entfernt' : 'Geschosse entfernt',
    content:
        '$liste nur von der Waffe ablegen? Die Geschosse bleiben dann mit '
        'ihrer Menge im Inventar und lassen sich einer Fernkampfwaffe wieder '
        'zuordnen. „Ganz entfernen“ löscht sie auch aus dem Inventar.',
    saveLabel: 'Nur ablegen',
    confirmLabel: 'Ganz entfernen',
    isDestructive: true,
  );
  return _alsEntscheidung(ergebnis);
}

// „Speichern“-Knopf des Dialogs ist „Nur ablegen“, „Bestätigen“ ist „Ganz
// entfernen“.
KampfgegenstandEntfernen? _alsEntscheidung(AdaptiveConfirmResult ergebnis) {
  return switch (ergebnis) {
    AdaptiveConfirmResult.save => KampfgegenstandEntfernen.ablegen,
    AdaptiveConfirmResult.confirm => KampfgegenstandEntfernen.ganzEntfernen,
    AdaptiveConfirmResult.cancel => null,
  };
}
