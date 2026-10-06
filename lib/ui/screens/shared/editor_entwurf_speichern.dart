import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/editor_entwurf_rules.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/sync_conflict_field_labels.dart';

/// Gleicht einen Editorentwurf mit dem gespeicherten Helden [aktuell] ab.
///
/// [erzwungen] sind die Schlüssel, für die der Nutzer seinen Entwurf
/// ausdrücklich behalten will. Wirft [EditorEntwurfKonflikt], solange sich
/// Änderungen überschneiden; darf selbst nicht speichern.
typedef EditorEntwurfAbgleich = HeroSheet Function(
  HeroSheet aktuell,
  Set<String> erzwungen,
);

/// Titel der Rückfrage bei überschneidenden Änderungen.
const String kEditorEntwurfKonfliktTitel = 'Inzwischen anderswo geändert';

/// Knopf, mit dem der Nutzer seinen Entwurf trotz Überschneidung speichert.
const String kEditorEntwurfErzwingen = 'Meine Fassung speichern';

/// Knopf, mit dem der Nutzer ohne Speichern zum Entwurf zurückkehrt.
const String kEditorEntwurfWeiter = 'Weiter bearbeiten';

/// Speichert einen Editorentwurf auf dem gespeicherten Helden (ARCH-05).
///
/// [abgleich] bekommt den **frisch geladenen** Helden, nie einen beim
/// Rendern erfassten; das Speichern reiht sich hinter andere Änderungen
/// desselben Helden ein und ruht während einer Planung
/// ([aendereHeldImEditor]).
///
/// Überschneidet sich der Entwurf mit einer inzwischen gespeicherten
/// Änderung, fragt ein Dialog nach: „Weiter bearbeiten“ speichert nichts,
/// „Meine Fassung speichern“ gleicht erneut frisch ab und lässt den Entwurf
/// nur in den bestätigten Bereichen gewinnen. Nähme der Entwurf eine Buchung
/// zurück, bleibt nur der Hinweis. Liefert, ob gespeichert wurde. Andere
/// Fehler erreichen den Aufrufer.
Future<bool> speichereEditorEntwurf({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required EditorEntwurfAbgleich abgleich,
}) async {
  var erzwungen = const <String>{};
  while (true) {
    final bestaetigt = erzwungen;
    try {
      await aendereHeldImEditor(
        ref: ref,
        heroId: heroId,
        aenderung: (aktuell) => abgleich(aktuell, bestaetigt),
      );
      return true;
    } on EditorEntwurfKonflikt catch (konflikt) {
      if (!context.mounted ||
          !await _frageNachKonflikt(context: context, konflikt: konflikt)) {
        return false;
      }
      erzwungen = <String>{...bestaetigt, ...konflikt.schluessel};
    }
  }
}

/// Zufällige ID für Kampf-Slots, die ein Editorentwurf neu angelegt hat
/// (wie beim Speichern in `HeroActions`).
String neueEditorSlotId() => const Uuid().v4();

// Fragt, ob der Entwurf die betroffenen Bereiche überschreiben soll.
Future<bool> _frageNachKonflikt({
  required BuildContext context,
  required EditorEntwurfKonflikt konflikt,
}) async {
  final bereiche = konflikt.schluessel
      .map((schluessel) => labelForSyncDiffPath(<String>[schluessel]))
      .join(', ');
  if (!konflikt.erzwingbar) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        title: const Text(kEditorEntwurfKonfliktTitel),
        content: Text(
          'Seit Beginn der Bearbeitung wurde anderswo gespeichert: '
          '$bereiche. Dabei wurde gebucht (Abenteuer abgeschlossen oder '
          'Belohnungen angewendet); dein Entwurf nähme das zurück und wird '
          'deshalb nicht gespeichert. Verwirf ihn und bearbeite neu.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(kEditorEntwurfWeiter),
          ),
        ],
      ),
    );
    return false;
  }
  final ergebnis = await showAdaptiveConfirmDialog(
    context: context,
    title: kEditorEntwurfKonfliktTitel,
    content:
        'Seit Beginn der Bearbeitung wurde anderswo gespeichert: $bereiche.\n\n'
        '„$kEditorEntwurfErzwingen“ ersetzt diese Bereiche durch deinen '
        'Entwurf. Alles andere bleibt, wie es gespeichert ist.',
    cancelLabel: kEditorEntwurfWeiter,
    confirmLabel: kEditorEntwurfErzwingen,
    isDestructive: true,
  );
  return ergebnis == AdaptiveConfirmResult.confirm;
}
