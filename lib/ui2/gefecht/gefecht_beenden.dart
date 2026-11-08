import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_patzer_provider.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_patzer_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_bestaetigen.dart';

/// Beendet die Sitzung nach frischer Prüfung und löst ihre Gruppenmitgliedschaft.
Future<void> beendeGefechtsansicht({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
}) async {
  if (gefechtFolgewuerfeOffen(ref.read(gefechtPatzerProvider(heroId)))) {
    throw StateError('Offene Patzer-/Bruchfolgen zuerst abschließen.');
  }
  if (ref.read(gefechtMitInitiativeProvider(heroId))?.handlung != null) {
    throw StateError(
      'Laufende Handlung zuerst abschließen oder Abbruch bestätigen.',
    );
  }
  if (!context.mounted) return;
  final ok = await kartoBestaetigen(
    context,
    titel: 'Gefecht beenden?',
    text:
        'Runde, INI und Aktionsmarken werden verworfen. '
        'Gespeicherte Ressourcen, Ausrüstung und Protokolle bleiben erhalten.',
    abbrechen: 'Weiterkämpfen',
    bestaetigen: 'Beenden',
  );
  if (ok && context.mounted) {
    final aktuell = ref.read(gefechtMitInitiativeProvider(heroId));
    if (gefechtFolgewuerfeOffen(ref.read(gefechtPatzerProvider(heroId))) ||
        aktuell?.handlung != null ||
        aktuell?.auftrag != null) {
      throw StateError('Laufende Handlung oder Übernahme zuerst abschließen.');
    }
    ref.read(gefechtInitiativeProvider.notifier).entfernen(heroId);
    ref.read(gefechtProvider(heroId).notifier).beenden();
    Navigator.pop(context);
  }
}
