import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/abmeldung_pruefen.dart';
import 'package:dsa_heldenverwaltung/data/auth_service.dart';
import 'package:dsa_heldenverwaltung/domain/sync_controller.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';

/// Meldet nach Sicherung und Bestätigung ab.
///
/// Gleicht zuerst ein letztes Mal mit der Cloud ab. Danach entfernt die App
/// die Online-Helden von diesem Gerät (Offline-Helden bleiben). Liegt noch
/// etwas nicht in der Cloud, warnt der Dialog, bevor es verworfen wird.
Future<void> bestaetigeUndMeldeAb({
  required BuildContext context,
  required AuthService authService,
  required AppSyncController? syncController,
}) async {
  final befund = await _pruefeMitFortschritt(context, syncController);
  if (befund == null || !context.mounted) {
    return;
  }
  final gesichert = befund.istGesichert;
  final result = await showAdaptiveConfirmDialog(
    context: context,
    title: gesichert ? 'Abmelden?' : 'Ungesicherte Änderungen',
    content: abmeldeText(befund),
    confirmLabel: gesichert ? 'Abmelden' : 'Trotzdem abmelden',
    isDestructive: !gesichert,
  );
  if (result != AdaptiveConfirmResult.confirm) {
    return;
  }
  await authService.signOut();
}

/// Dialogtext für den [befund].
String abmeldeText(AbmeldeBefund befund) {
  const entfernt =
      'Die lokal gespeicherten Online-Helden werden von diesem Gerät entfernt. '
      'Sie bleiben in der Cloud und kommen beim nächsten Anmelden zurück. '
      'Offline-Helden bleiben erhalten.';
  if (befund.istGesichert) {
    return entfernt;
  }
  final offen = <String>[
    if (befund.offeneKonflikte > 0)
      '${befund.offeneKonflikte} ungelöste Konflikte',
    if (befund.ausstehendeVorgaenge > 0)
      '${befund.ausstehendeVorgaenge} nicht abgeschlossene Entscheidungen',
    if (befund.syncFehler != null)
      'der Abgleich ist fehlgeschlagen (${befund.syncFehler})',
  ];
  return 'Nicht alles ist in der Cloud gesichert: ${offen.join(', ')}. '
      'Beim Abmelden gehen die betroffenen lokalen Änderungen verloren.\n\n'
      '$entfernt';
}

// Zeigt während des Abgleichs einen Fortschrittsdialog. `null`, wenn der
// Kontext inzwischen weg ist.
Future<AbmeldeBefund?> _pruefeMitFortschritt(
  BuildContext context,
  AppSyncController? syncController,
) async {
  if (syncController == null) {
    return AbmeldeBefund.gesichert;
  }
  final navigator = Navigator.of(context, rootNavigator: true);
  var dialogOffen = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Daten werden gesichert …')),
          ],
        ),
      ),
    ),
  ).whenComplete(() => dialogOffen = false);
  try {
    return await pruefeVorAbmeldung(syncController);
  } finally {
    if (dialogOffen) {
      navigator.pop();
    }
  }
}
