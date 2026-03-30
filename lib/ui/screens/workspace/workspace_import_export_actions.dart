import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/gruppen_snapshot_codec.dart';
import 'package:dsa_heldenverwaltung/data/hero_transfer_file_gateway.dart';
import 'package:dsa_heldenverwaltung/domain/gruppen_snapshot.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';
import 'package:dsa_heldenverwaltung/state/gruppen_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';

/// Ergebnis der Smart-Import-Erkennung.
enum ImportResult {
  /// Ein einzelner Held wurde importiert.
  hero,

  /// Ein Gruppen-Snapshot wurde importiert.
  gruppe,
}

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

  /// Exportiert einen Gruppen-Snapshot fuer die ausgewaehlten Helden.
  Future<HeroTransferExportOutcome> exportGruppenSnapshot({
    required WidgetRef ref,
    required String gruppenName,
    required List<String> heroIds,
  }) async {
    final payload = await ref
        .read(heroActionsProvider)
        .buildGruppenExportJson(
          gruppenName: gruppenName,
          heroIds: heroIds,
        );
    final gateway = ref.read(heroTransferFileGatewayProvider);
    return gateway.exportJson(
      fileNameBase: gruppenName.trim().isEmpty ? 'Gruppe' : gruppenName.trim(),
      jsonPayload: payload,
    );
  }

  /// Importiert eine JSON-Datei und erkennt automatisch ob es sich um
  /// einen einzelnen Helden oder einen Gruppen-Snapshot handelt.
  Future<({ImportResult type, String? heroId})?> importSmartData({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final gateway = ref.read(heroTransferFileGatewayProvider);
    final rawJson = await gateway.pickImportJson();
    if (rawJson == null) return null;

    // Smart Detection: kind-Feld pruefen
    final kind = _detectJsonKind(rawJson);

    if (kind == GruppenSnapshot.kind) {
      final snapshot = const GruppenSnapshotCodec().decode(rawJson);
      final repo = ref.read(gruppenRepositoryProvider);
      await repo.saveGruppe(snapshot);
      return (type: ImportResult.gruppe, heroId: null);
    }

    // Standard-Held-Import (bestehender Flow)
    final actions = ref.read(heroActionsProvider);
    final bundle = await actions.parseImportJson(rawJson);
    if (!context.mounted) return null;

    final resolution = await _resolveConflict(context, ref, bundle);
    if (resolution == null) return null;

    final heroId = await actions.importHeroBundle(
      bundle,
      resolution: resolution,
    );
    return (type: ImportResult.hero, heroId: heroId);
  }

  /// Legacy-Methode fuer bestehende Aufrufer.
  Future<String?> importHeroData({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final result = await importSmartData(context: context, ref: ref);
    if (result == null) return null;
    return result.heroId;
  }

  /// Erkennt den `kind`-Wert aus dem JSON ohne vollstaendiges Parsen.
  String? _detectJsonKind(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) {
        return decoded['kind'] as String?;
      }
    } on FormatException {
      // Wird spaeter vom Codec behandelt.
    }
    return null;
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
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(ImportConflictResolution.createNewHero),
              child: const Text('Als neu erstellen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(ImportConflictResolution.overwriteExisting),
              child: const Text('Überschreiben'),
            ),
          ],
        );
      },
    );
  }
}
