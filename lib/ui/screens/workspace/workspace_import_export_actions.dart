import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/held_importieren.dart';
import 'package:dsa_heldenverwaltung/data/hero_transfer_file_gateway.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';

/// Kapselt Import-/Export-Aktionen fuer die Workspace-Shell.
class WorkspaceImportExportActions {
  const WorkspaceImportExportActions();

  Future<HeroTransferExportOutcome> exportHeroData({
    required WidgetRef ref,
    required HeroSheet hero,
  }) async {
    final payload = await ref
        .read(heroActionsProvider)
        .buildExportJson(hero.id);
    final gateway = ref.read(heroTransferFileGatewayProvider);
    return gateway.exportJson(fileNameBase: hero.name, jsonPayload: payload);
  }

  /// Importiert eine JSON-Datei als einzelnen Helden.
  ///
  /// Gibt das Importergebnis zurueck oder `null` bei Abbruch.
  Future<HeldImportErgebnis?> importHeroData({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final gateway = ref.read(heroTransferFileGatewayProvider);
    final rawJson = await gateway.pickImportJson();
    if (rawJson == null) return null;

    final actions = ref.read(heroActionsProvider);
    final bundle = await actions.parseImportJson(rawJson);
    if (!context.mounted) return null;

    final resolution = await _resolveConflict(context, ref, bundle);
    if (resolution == null) return null;

    return actions.importiereHeld(bundle, resolution: resolution);
  }

  Future<ImportConflictResolution?> _resolveConflict(
    BuildContext context,
    WidgetRef ref,
    HeroTransferBundle bundle,
  ) async {
    final existing = await ref.read(
      heroByIdFutureProvider(bundle.hero.id).future,
    );
    if (existing == null) {
      return ImportConflictResolution.overwriteExisting;
    }

    if (!context.mounted) {
      return null;
    }
    return showAdaptiveDetailSheet<ImportConflictResolution>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Held bereits vorhanden'),
          content: const Text(
            'Die importierte Held-ID existiert bereits. Soll der vorhandene Held '
            'überschrieben oder als neuer Held importiert werden?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen'),
            ),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(dialogContext)
                      .pop(ImportConflictResolution.createNewHero),
              child: const Text('Als neu erstellen'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext)
                      .pop(ImportConflictResolution.overwriteExisting),
              child: const Text('Überschreiben'),
            ),
          ],
        );
      },
    );
  }
}

/// Rückmeldung nach einem Import; nennt ausgelassene Bilder ausdrücklich,
/// damit ein fehlendes Porträt nie stumm wie „kein Bild“ aussieht.
String importMeldung(HeldImportErgebnis ergebnis) {
  final fehlend = ergebnis.fehlendeBilder;
  if (fehlend <= 0) {
    return 'Held erfolgreich importiert';
  }
  final bilder = fehlend == 1 ? '1 Bild konnte' : '$fehlend Bilder konnten';
  return 'Held importiert – $bilder nicht gespeichert werden.';
}
